#!/bin/bash
set -euo pipefail

# Generate Kamaji Pregenerated Certificate Resources
# Usage: ./generate-kamaji-resources.sh <cluster-name>

CLUSTER_NAME="${1:-}"
if [ -z "$CLUSTER_NAME" ]; then
    echo "❌ Usage: $0 <cluster-name>"
    echo ""
    echo "Examples:"
    echo "  $0 golder-production"
    echo "  $0 golder-secops" 
    echo "  $0 golder-staging"
    exit 1
fi

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKI_SOURCE_DIR="/home/rossg/clients/golder/infrastructure/sysadmin/pki/k8s-pki/$CLUSTER_NAME"
OUTPUT_DIR="$SCRIPT_DIR/../$CLUSTER_NAME"
SECRETS_DIR="$OUTPUT_DIR/secrets"
TCP_DIR="$OUTPUT_DIR/tenantcontrolplane"
CERTS_DIR="$OUTPUT_DIR/certificates"

echo "🏗️  Generating Kamaji resources for: $CLUSTER_NAME"
echo "📂 Source PKI: $PKI_SOURCE_DIR"
echo "📂 Output Directory: $OUTPUT_DIR"

# Verify source PKI exists
if [ ! -d "$PKI_SOURCE_DIR" ]; then
    echo "❌ PKI source directory not found: $PKI_SOURCE_DIR"
    exit 1
fi

# Create output directories
mkdir -p "$SECRETS_DIR" "$TCP_DIR" "$CERTS_DIR"

echo ""
echo "📋 Step 1: Copying certificate files for reference..."

# Copy certificate files for reference
cp "$PKI_SOURCE_DIR/ca.crt" "$CERTS_DIR/"
cp "$PKI_SOURCE_DIR/apiserver.crt" "$CERTS_DIR/"
cp "$PKI_SOURCE_DIR/apiserver-kubelet-client.crt" "$CERTS_DIR/"
cp "$PKI_SOURCE_DIR/front-proxy-ca.crt" "$CERTS_DIR/"
cp "$PKI_SOURCE_DIR/front-proxy-client.crt" "$CERTS_DIR/"
cp "$PKI_SOURCE_DIR/sa.pub" "$CERTS_DIR/"

echo "  ✅ Certificate files copied to $CERTS_DIR"

echo ""
echo "🔐 Step 2: Generating Kubernetes Secret manifests..."

# Generate Secret for CA certificate (using intermediate CA key)
cat > "$SECRETS_DIR/ca-certificate-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-ca-certificate
  namespace: kamaji-system
  labels:
    app.kubernetes.io/name: kamaji
    app.kubernetes.io/component: pregenerated-certificates
    kamaji.clastix.io/cluster: ${CLUSTER_NAME}
    kamaji.clastix.io/certificate-type: ca
type: Opaque
data:
  tls.crt: $(base64 -w 0 "$PKI_SOURCE_DIR/${CLUSTER_NAME}-E1.crt")
  tls.key: $(base64 -w 0 "$PKI_SOURCE_DIR/${CLUSTER_NAME}-E1.key")
EOF

# Generate Secret for API Server certificate  
cat > "$SECRETS_DIR/apiserver-certificate-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-apiserver-certificate
  namespace: kamaji-system
  labels:
    app.kubernetes.io/name: kamaji
    app.kubernetes.io/component: pregenerated-certificates
    kamaji.clastix.io/cluster: ${CLUSTER_NAME}
    kamaji.clastix.io/certificate-type: apiserver
type: Opaque
data:
  tls.crt: $(base64 -w 0 "$PKI_SOURCE_DIR/apiserver.crt")
  tls.key: $(base64 -w 0 "$PKI_SOURCE_DIR/apiserver.key")
EOF

# Generate Secret for Kubelet Client certificate
cat > "$SECRETS_DIR/kubelet-client-certificate-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-kubelet-client-certificate
  namespace: kamaji-system
  labels:
    app.kubernetes.io/name: kamaji
    app.kubernetes.io/component: pregenerated-certificates
    kamaji.clastix.io/cluster: ${CLUSTER_NAME}
    kamaji.clastix.io/certificate-type: kubelet-client
type: Opaque
data:
  tls.crt: $(base64 -w 0 "$PKI_SOURCE_DIR/apiserver-kubelet-client.crt")
  tls.key: $(base64 -w 0 "$PKI_SOURCE_DIR/apiserver-kubelet-client.key")
EOF

# Generate Secret for Front Proxy CA certificate
cat > "$SECRETS_DIR/front-proxy-ca-certificate-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-front-proxy-ca-certificate
  namespace: kamaji-system
  labels:
    app.kubernetes.io/name: kamaji
    app.kubernetes.io/component: pregenerated-certificates
    kamaji.clastix.io/cluster: ${CLUSTER_NAME}
    kamaji.clastix.io/certificate-type: front-proxy-ca
type: Opaque
data:
  tls.crt: $(base64 -w 0 "$PKI_SOURCE_DIR/front-proxy-ca.crt")
  tls.key: $(base64 -w 0 "$PKI_SOURCE_DIR/front-proxy-ca.key")
EOF

# Generate Secret for Front Proxy Client certificate
cat > "$SECRETS_DIR/front-proxy-client-certificate-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-front-proxy-client-certificate
  namespace: kamaji-system
  labels:
    app.kubernetes.io/name: kamaji
    app.kubernetes.io/component: pregenerated-certificates
    kamaji.clastix.io/cluster: ${CLUSTER_NAME}
    kamaji.clastix.io/certificate-type: front-proxy-client
type: Opaque
data:
  tls.crt: $(base64 -w 0 "$PKI_SOURCE_DIR/front-proxy-client.crt")
  tls.key: $(base64 -w 0 "$PKI_SOURCE_DIR/front-proxy-client.key")
EOF

# Generate Secret for Service Account keys
cat > "$SECRETS_DIR/service-account-keys-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-service-account-keys
  namespace: kamaji-system
  labels:
    app.kubernetes.io/name: kamaji
    app.kubernetes.io/component: pregenerated-certificates
    kamaji.clastix.io/cluster: ${CLUSTER_NAME}
    kamaji.clastix.io/certificate-type: service-account
type: Opaque
data:
  sa.pub: $(base64 -w 0 "$PKI_SOURCE_DIR/sa.pub")
  sa.key: $(base64 -w 0 "$PKI_SOURCE_DIR/sa.key")
EOF

echo "  ✅ Kubernetes Secret manifests generated"

echo ""
echo "🚀 Step 3: Generating TenantControlPlane example..."

# Extract environment-specific configuration
case "$CLUSTER_NAME" in
    "golder-production")
        API_SERVER_ADDRESS="k8s-api.production.golder.lan"
        ENVIRONMENT="production"
        ;;
    "golder-secops")
        API_SERVER_ADDRESS="k8s-api.secops.golder.lan"
        ENVIRONMENT="secops"
        ;;
    "golder-staging")
        API_SERVER_ADDRESS="k8s-api.staging.golder.lan"
        ENVIRONMENT="staging"
        ;;
    *)
        API_SERVER_ADDRESS="k8s-api.${CLUSTER_NAME#golder-}.golder.lan"
        ENVIRONMENT="${CLUSTER_NAME#golder-}"
        ;;
esac

# Generate TenantControlPlane example
cat > "$TCP_DIR/example-tenant-controlplane.yaml" << EOF
apiVersion: kamaji.clastix.io/v1alpha1
kind: TenantControlPlane
metadata:
  name: ${CLUSTER_NAME}-tenant-example
  namespace: kamaji-system
  labels:
    app.kubernetes.io/name: kamaji
    app.kubernetes.io/component: tenant-control-plane
    kamaji.clastix.io/cluster: ${CLUSTER_NAME}
    kamaji.clastix.io/environment: ${ENVIRONMENT}
spec:
  # Kubernetes configuration
  kubernetes:
    version: "v1.30.0"
    kubelet:
      cgroupfs: systemd
      preferredAddressTypes:
        - InternalIP
        - ExternalIP
        - Hostname
    admissionControllers:
      - CertificateApproval
      - CertificateSigning
      - CertificateSubjectRestriction
      - DefaultIngressClass
      - DefaultStorageClass
      - DefaultTolerationSeconds
      - LimitRanger
      - MutatingAdmissionWebhook
      - NamespaceLifecycle
      - PersistentVolumeClaimResize
      - Priority
      - ResourceQuota
      - RuntimeClass
      - ServiceAccount
      - StorageObjectInUseProtection
      - TaintNodesByCondition
      - ValidatingAdmissionWebhook

  # Network configuration
  networkProfile:
    address: "${API_SERVER_ADDRESS}"
    port: 6443
    certSANs:
      - "${API_SERVER_ADDRESS}"
      - "kubernetes"
      - "kubernetes.default.svc"
      - "kubernetes.default.svc.cluster.local"
    serviceCidr: "10.96.0.0/16"
    podCidr: "10.244.0.0/16"
    dnsServiceIPs:
      - "10.96.0.10"

  # Control plane configuration
  controlPlane:
    deployment:
      replicas: 2
      strategy:
        type: RollingUpdate
        rollingUpdate:
          maxSurge: 1
          maxUnavailable: 0
      resources:
        requests:
          memory: "512Mi"
          cpu: "250m"
        limits:
          memory: "1Gi"
          cpu: "500m"
    service:
      serviceType: "ClusterIP"

  # DataStore configuration (customize as needed)
  dataStore: "default"

  # ECDSA Pregenerated Certificates
  preGeneratedCertificates:
    ca:
      secretName: ${CLUSTER_NAME}-ca-certificate
      secretNamespace: kamaji-system
      certificateKey: tls.crt
      privateKeyKey: tls.key
    
    apiServer:
      secretName: ${CLUSTER_NAME}-apiserver-certificate
      secretNamespace: kamaji-system
      certificateKey: tls.crt
      privateKeyKey: tls.key
    
    kubeletClient:
      secretName: ${CLUSTER_NAME}-kubelet-client-certificate
      secretNamespace: kamaji-system
      certificateKey: tls.crt
      privateKeyKey: tls.key
    
    frontProxyCA:
      secretName: ${CLUSTER_NAME}-front-proxy-ca-certificate
      secretNamespace: kamaji-system
      certificateKey: tls.crt
      privateKeyKey: tls.key
    
    frontProxyClient:
      secretName: ${CLUSTER_NAME}-front-proxy-client-certificate
      secretNamespace: kamaji-system
      certificateKey: tls.crt
      privateKeyKey: tls.key
    
    serviceAccount:
      secretName: ${CLUSTER_NAME}-service-account-keys
      secretNamespace: kamaji-system
      publicKeyKey: sa.pub
      privateKeyKey: sa.key

---
# Kustomization for easy deployment
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
metadata:
  name: ${CLUSTER_NAME}-pregenerated-certs
resources:
  - ../secrets/ca-certificate-secret.yaml
  - ../secrets/apiserver-certificate-secret.yaml
  - ../secrets/kubelet-client-certificate-secret.yaml
  - ../secrets/front-proxy-ca-certificate-secret.yaml
  - ../secrets/front-proxy-client-certificate-secret.yaml
  - ../secrets/service-account-keys-secret.yaml
  - example-tenant-controlplane.yaml
commonLabels:
  kamaji.clastix.io/cluster: ${CLUSTER_NAME}
  kamaji.clastix.io/environment: ${ENVIRONMENT}
EOF

echo "  ✅ TenantControlPlane example generated"

echo ""
echo "📊 Step 4: Certificate information..."

echo "  📏 Certificate details (ECDSA optimization):"
echo "    CA Certificate:         $(openssl x509 -in "$PKI_SOURCE_DIR/ca.crt" -noout -text | grep "Public Key Algorithm" | head -1 | sed 's/^[[:space:]]*//')"
echo "    API Server:             $(openssl x509 -in "$PKI_SOURCE_DIR/apiserver.crt" -noout -text | grep "Public Key Algorithm" | head -1 | sed 's/^[[:space:]]*//')"
echo "    Kubelet Client:         $(openssl x509 -in "$PKI_SOURCE_DIR/apiserver-kubelet-client.crt" -noout -text | grep "Public Key Algorithm" | head -1 | sed 's/^[[:space:]]*//')"
echo "    Front Proxy CA:         $(openssl x509 -in "$PKI_SOURCE_DIR/front-proxy-ca.crt" -noout -text | grep "Public Key Algorithm" | head -1 | sed 's/^[[:space:]]*//')"
echo "    Front Proxy Client:     $(openssl x509 -in "$PKI_SOURCE_DIR/front-proxy-client.crt" -noout -text | grep "Public Key Algorithm" | head -1 | sed 's/^[[:space:]]*//')"

echo ""
echo "  📋 Certificate expiration dates:"
echo "    CA Certificate:         $(openssl x509 -in "$PKI_SOURCE_DIR/ca.crt" -noout -enddate | cut -d= -f2)"
echo "    API Server:             $(openssl x509 -in "$PKI_SOURCE_DIR/apiserver.crt" -noout -enddate | cut -d= -f2)"
echo "    Kubelet Client:         $(openssl x509 -in "$PKI_SOURCE_DIR/apiserver-kubelet-client.crt" -noout -enddate | cut -d= -f2)"
echo "    Front Proxy CA:         $(openssl x509 -in "$PKI_SOURCE_DIR/front-proxy-ca.crt" -noout -enddate | cut -d= -f2)"
echo "    Front Proxy Client:     $(openssl x509 -in "$PKI_SOURCE_DIR/front-proxy-client.crt" -noout -enddate | cut -d= -f2)"

echo ""
echo "✅ Kamaji pregenerated certificate resources generated successfully!"
echo ""
echo "📁 Generated files in: $OUTPUT_DIR"
echo ""
echo "🚀 Next steps:"
echo "  1. Review the generated Secret manifests in: $SECRETS_DIR"
echo "  2. Customize the TenantControlPlane example in: $TCP_DIR"  
echo "  3. Apply to your cluster:"
echo "     kubectl apply -f $SECRETS_DIR/"
echo "     kubectl apply -f $TCP_DIR/example-tenant-controlplane.yaml"
echo ""
echo "📊 ECDSA Benefits:"
echo "  • 3x faster cryptographic operations"
echo "  • ~50% smaller certificate sizes"
echo "  • Reduced TLS handshake overhead"
echo "  • Better etcd performance with smaller certificates"