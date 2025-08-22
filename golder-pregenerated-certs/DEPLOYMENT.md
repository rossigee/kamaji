# Golder ECDSA PKI Deployment Guide for Kamaji

This guide explains how to deploy the pregenerated ECDSA certificates for Kamaji Tenant Control Planes.

## Prerequisites 

1. Kamaji operator installed in `kamaji-system` namespace
2. kubectl access to the management cluster
3. Appropriate RBAC permissions to create Secrets and TenantControlPlanes

## Deployment Steps

### 1. Deploy Certificate Secrets

For each cluster environment, apply the certificate secrets:

```bash
# Production environment
kubectl apply -f golder-production/secrets/

# SecOps environment  
kubectl apply -f golder-secops/secrets/

# Staging environment
kubectl apply -f golder-staging/secrets/
```

### 2. Verify Secret Creation

Check that all secrets were created successfully:

```bash
kubectl get secrets -n kamaji-system -l kamaji.clastix.io/cluster=golder-production
kubectl get secrets -n kamaji-system -l kamaji.clastix.io/cluster=golder-secops
kubectl get secrets -n kamaji-system -l kamaji.clastix.io/cluster=golder-staging
```

Expected output for each cluster (6 secrets total):
```
NAME                                           TYPE     DATA   AGE
golder-production-apiserver-certificate        Opaque   2      1m
golder-production-ca-certificate               Opaque   2      1m
golder-production-front-proxy-ca-certificate   Opaque   2      1m
golder-production-front-proxy-client-certificate Opaque 2      1m
golder-production-kubelet-client-certificate   Opaque   2      1m
golder-production-service-account-keys         Opaque   2      1m
```

### 3. Deploy TenantControlPlane

Choose the appropriate cluster and customize the TenantControlPlane manifest:

```bash
# Edit the example to match your requirements
vi golder-production/tenantcontrolplane/example-tenant-controlplane.yaml

# Apply the TenantControlPlane
kubectl apply -f golder-production/tenantcontrolplane/example-tenant-controlplane.yaml
```

### 4. Verify Deployment

Check the TenantControlPlane status:

```bash
kubectl get tenantcontrolplane -n kamaji-system
kubectl describe tenantcontrolplane golder-production-tenant-example -n kamaji-system
```

Monitor the control plane pods:

```bash
kubectl get pods -n kamaji-system -l kamaji.clastix.io/cluster=golder-production
```

## Certificate Details

### ECDSA Benefits

- **Performance**: 3x faster cryptographic operations than RSA
- **Size**: ~50% smaller certificates reducing network overhead
- **TLS**: Reduced handshake time and better etcd performance
- **Security**: Equivalent security to RSA-2048 with P-256 curves

### Certificate Hierarchy

```
Golder Root X2 (ECDSA P-384)
├── golder-production-E1 (ECDSA P-256)
│   ├── kube-apiserver certificate
│   └── kube-apiserver-kubelet-client certificate  
├── golder-production-etcd-E1 (ECDSA P-256)
│   └── etcd client/server certificates
└── golder-production-front-proxy-E1 (ECDSA P-256)
    └── front-proxy-client certificate
```

### Certificate Expiration

All end-entity certificates expire in July 2026 (2-year validity).
CA certificates expire in 2030-2035 (5-10 year validity).

Monitor expiration with:
```bash
# Check certificate expiration
for secret in $(kubectl get secrets -n kamaji-system -l kamaji.clastix.io/cluster=golder-production -o name); do
  echo "=== $secret ==="
  kubectl get $secret -n kamaji-system -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate
done
```

## Customization

### TenantControlPlane Configuration

Key areas to customize in the TenantControlPlane manifest:

1. **Networking**:
   - `networkProfile.address`: External API server address
   - `networkProfile.certSANs`: Additional hostnames/IPs
   - `networkProfile.serviceCidr`: Service network CIDR
   - `networkProfile.podCidr`: Pod network CIDR

2. **Resources**:
   - `controlPlane.deployment.replicas`: Number of API server replicas
   - `controlPlane.deployment.resources`: CPU/memory limits

3. **DataStore**:
   - `dataStore`: Reference to Kamaji DataStore resource

### Environment-Specific Settings

Each cluster has preconfigured settings:

- **golder-production**: `k8s-api.production.golder.lan:6443`
- **golder-secops**: `k8s-api.secops.golder.lan:6443`  
- **golder-staging**: `k8s-api.staging.golder.lan:6443`

## Troubleshooting

### Common Issues

1. **Secret Not Found**:
   ```bash
   # Check secret exists in correct namespace
   kubectl get secret <secret-name> -n kamaji-system
   ```

2. **Certificate Validation Errors**:
   ```bash
   # Verify certificate contents
   kubectl get secret <secret-name> -n kamaji-system -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
   ```

3. **TenantControlPlane Not Ready**:
   ```bash
   # Check controller logs
   kubectl logs -n kamaji-system -l app.kubernetes.io/name=kamaji
   ```

### Certificate Verification

Verify ECDSA algorithm is used:
```bash
kubectl get secret golder-production-ca-certificate -n kamaji-system -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text | grep "Public Key Algorithm"
```

Expected output: `Public Key Algorithm: id-ecPublicKey`

## Security Notes

- Secrets contain sensitive private keys
- Use RBAC to restrict access to certificate secrets
- Consider using sealed-secrets or external secret management
- Rotate certificates before expiration
- Monitor certificate usage with Prometheus alerts

## Maintenance

### Certificate Rotation

1. Generate new certificates using the PKI scripts
2. Update the secrets with new certificate data
3. Restart TenantControlPlane pods to pick up new certificates

### Monitoring

Set up Prometheus alerts for certificate expiration:
```yaml
- alert: KamajiCertificateExpiring
  expr: (cert_exporter_not_after - time()) / 86400 < 30
  labels:
    severity: warning
  annotations:
    summary: "Kamaji certificate expiring in {{ $value }} days"
```