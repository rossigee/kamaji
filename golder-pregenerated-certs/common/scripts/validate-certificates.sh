#!/bin/bash
set -euo pipefail

# Validate Kamaji Pregenerated Certificates
# Usage: ./validate-certificates.sh [cluster-name]

CLUSTER_NAME="${1:-}"
if [ -z "$CLUSTER_NAME" ]; then
    echo "🔍 Validating all Golder ECDSA certificates for Kamaji..."
    echo ""
    CLUSTERS=("golder-production" "golder-secops" "golder-staging")
else
    echo "🔍 Validating ECDSA certificates for: $CLUSTER_NAME"
    echo ""
    CLUSTERS=("$CLUSTER_NAME")
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."

validate_cluster() {
    local cluster="$1"
    local certs_dir="$BASE_DIR/$cluster/certificates"
    local secrets_dir="$BASE_DIR/$cluster/secrets"
    
    echo "🏗️  Validating cluster: $cluster"
    echo "📂 Certificates: $certs_dir"
    
    if [ ! -d "$certs_dir" ]; then
        echo "  ❌ Certificate directory not found: $certs_dir"
        return 1
    fi
    
    echo ""
    echo "  📋 Certificate Algorithm Verification:"
    
    # Check each certificate type
    local cert_files=(
        "ca.crt:CA Certificate"
        "apiserver.crt:API Server"
        "apiserver-kubelet-client.crt:Kubelet Client" 
        "front-proxy-ca.crt:Front Proxy CA"
        "front-proxy-client.crt:Front Proxy Client"
    )
    
    local all_valid=true
    
    for cert_info in "${cert_files[@]}"; do
        IFS=':' read -r cert_file cert_name <<< "$cert_info"
        local cert_path="$certs_dir/$cert_file"
        
        if [ -f "$cert_path" ]; then
            local algorithm=$(openssl x509 -in "$cert_path" -noout -text | grep "Public Key Algorithm" | head -1 | sed 's/^[[:space:]]*//' | sed 's/Public Key Algorithm: //')
            local key_size=$(openssl x509 -in "$cert_path" -noout -text | grep "Public-Key:" | head -1 | sed 's/^[[:space:]]*//' | sed 's/Public-Key: //' | sed 's/ bit//')
            
            if [[ "$algorithm" == "id-ecPublicKey" ]]; then
                echo "    ✅ $cert_name: $algorithm ($key_size)"
            else
                echo "    ❌ $cert_name: $algorithm (Expected: id-ecPublicKey)"
                all_valid=false
            fi
        else
            echo "    ❌ $cert_name: File not found ($cert_path)"
            all_valid=false
        fi
    done
    
    echo ""
    echo "  📅 Certificate Expiration Dates:"
    
    for cert_info in "${cert_files[@]}"; do
        IFS=':' read -r cert_file cert_name <<< "$cert_info"
        local cert_path="$certs_dir/$cert_file"
        
        if [ -f "$cert_path" ]; then
            local expiry=$(openssl x509 -in "$cert_path" -noout -enddate | cut -d= -f2)
            local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
            local current_epoch=$(date +%s)
            local days_remaining=$(( (expiry_epoch - current_epoch) / 86400 ))
            
            if [ "$days_remaining" -gt 30 ]; then
                echo "    ✅ $cert_name: $expiry ($days_remaining days)"
            elif [ "$days_remaining" -gt 0 ]; then
                echo "    ⚠️  $cert_name: $expiry ($days_remaining days - EXPIRING SOON)"
            else
                echo "    ❌ $cert_name: $expiry (EXPIRED)"
                all_valid=false
            fi
        fi
    done
    
    echo ""
    echo "  🔐 Secret Manifest Validation:"
    
    if [ -d "$secrets_dir" ]; then
        local secret_count=$(find "$secrets_dir" -name "*.yaml" | wc -l)
        echo "    ✅ Secret manifests found: $secret_count"
        
        # Validate YAML syntax
        for yaml_file in "$secrets_dir"/*.yaml; do
            if command -v yq >/dev/null 2>&1; then
                if yq eval 'true' "$yaml_file" >/dev/null 2>&1; then
                    echo "    ✅ $(basename "$yaml_file"): Valid YAML"
                else
                    echo "    ❌ $(basename "$yaml_file"): Invalid YAML"
                    all_valid=false
                fi
            fi
        done
    else
        echo "    ❌ Secret directory not found: $secrets_dir"
        all_valid=false
    fi
    
    echo ""
    if [ "$all_valid" = true ]; then
        echo "  ✅ All validations passed for $cluster"
    else
        echo "  ❌ Some validations failed for $cluster"
    fi
    
    return $([ "$all_valid" = true ] && echo 0 || echo 1)
}

# Validate each cluster
all_clusters_valid=true

for cluster in "${CLUSTERS[@]}"; do
    if ! validate_cluster "$cluster"; then
        all_clusters_valid=false
    fi
    echo ""
done

echo "🎯 Summary:"
echo ""

if [ "$all_clusters_valid" = true ]; then
    echo "✅ All certificate validations passed!"
    echo ""
    echo "🚀 Next steps:"
    echo "  1. Deploy secrets: kubectl apply -f <cluster>/secrets/"
    echo "  2. Deploy TenantControlPlane: kubectl apply -f <cluster>/tenantcontrolplane/"
    echo "  3. Monitor deployment: kubectl get tcp -n kamaji-system"
else
    echo "❌ Some validations failed. Please review the errors above."
    exit 1
fi

echo ""
echo "📊 ECDSA Certificate Benefits:"
echo "  • 3x faster cryptographic operations than RSA"
echo "  • ~50% smaller certificate sizes"
echo "  • Reduced TLS handshake overhead"
echo "  • Better etcd performance with smaller certificates"
echo "  • Equivalent security to RSA-2048 with P-256 curves"