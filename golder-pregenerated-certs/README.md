# Golder ECDSA PKI for Kamaji Tenant Control Planes

This directory contains pregenerated ECDSA certificate manifests for Kamaji Tenant Control Planes.

## Overview

The certificates are generated using the existing ECDSA PKI infrastructure from `/home/rossg/clients/golder/infrastructure/sysadmin/pki/k8s-pki/`. All certificates use ECDSA P-256 with P-384 root CA, providing:

- 3x faster cryptographic operations
- ~50% smaller certificate sizes  
- Reduced TLS handshake overhead
- Better etcd performance

## Certificate Hierarchy

```
Golder Root X2 (ECDSA P-384)
├── {cluster-name}-E1 (ECDSA P-256) → API Server certificates
├── {cluster-name}-etcd-E1 (ECDSA P-256) → etcd certificates  
└── {cluster-name}-front-proxy-E1 (ECDSA P-256) → front-proxy certificates
```

## Directory Structure

```
golder-pregenerated-certs/
├── golder-production/
│   ├── secrets/              # Kubernetes Secret manifests
│   ├── tenantcontrolplane/   # TenantControlPlane examples
│   └── certificates/         # Certificate files for reference
├── golder-secops/
├── golder-staging/
└── common/
    └── scripts/              # Helper scripts
```

## Usage

1. Apply the Secret manifests to create certificate storage:
```bash
kubectl apply -f golder-production/secrets/
```

2. Create TenantControlPlane with pregenerated certificates:
```bash
kubectl apply -f golder-production/tenantcontrolplane/example-tcp.yaml
```

## Certificate Types

For each cluster, the following certificates are available:

- **CA Certificate**: Cluster root CA (signed by Golder Root X2)
- **API Server**: TLS certificate for kube-apiserver  
- **Kubelet Client**: Client certificate for kubelet communication
- **Front Proxy CA**: Front proxy root CA
- **Front Proxy Client**: Client certificate for front proxy
- **Service Account**: ECDSA key pair for JWT token signing

## Security Notes

- All private keys are stored in Kubernetes Secrets
- Certificates follow Let's Encrypt E-series naming convention
- Root CA private key is encrypted with GPG
- Certificate validity periods follow Kubernetes best practices

## Maintenance

- Certificates should be rotated annually
- Monitor certificate expiration using Prometheus alerts
- Use `openssl x509 -enddate -noout -in <cert>` to check expiry