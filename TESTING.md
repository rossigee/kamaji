# Testing Guide for Kamaji Resource Validation

This document explains how to run the new resource validation tests and what they check for.

## Quick Summary

The tests address the issue where freshly deployed Kamaji clusters were missing:
- `cluster-admin` RBAC bindings
- `kube-dns` service
- Other standard Kubernetes resources

## Test Types

### 1. Unit Tests (No Kamaji Installation Required)
These validate configuration logic without needing a running Kamaji installation:

```bash
# Run configuration validation unit tests
ginkgo -r -v -focus="Validation Unit Tests" ./e2e/
```

**What these tests do:**
- ✅ Validate TenantControlPlane configuration patterns
- ✅ Document expected resources in tenant clusters  
- ✅ Explain why resources might be missing
- ✅ Provide configuration recommendations

### 2. Full E2E Tests (Requires Complete Environment)
These validate actual tenant cluster resources and require full Kamaji setup:

```bash
# Full E2E test suite (sets up everything)
make e2e

# Or run specific resource validation tests
ginkgo -r -v -focus="Resource Validation|Missing Resources" ./e2e/
```

**What these tests do:**
- ✅ Connect to actual tenant clusters via kubeconfig
- ✅ Validate cluster-admin RBAC bindings exist
- ✅ Verify kube-dns service when CoreDNS enabled
- ✅ Check kube-proxy resources when addon enabled
- ✅ Validate standard Kubernetes bootstrap resources

## Test Environment Setup

### For Unit Tests
No special setup required - just run them directly.

### For Full E2E Tests
The full E2E tests require:
1. **KinD cluster** with Kamaji installed
2. **Datastores** configured (etcd, MySQL, PostgreSQL, NATS)
3. **Kamaji controller** running

Use `make e2e` which automatically:
```bash
make env          # Creates KinD cluster
make build        # Builds Kamaji image
make load         # Loads image into KinD
make cert-manager # Installs cert-manager
# Installs Kamaji via Helm
# Sets up datastores
ginkgo -v ./e2e   # Runs tests
```

## Common Issues and Solutions

### Issue: Tests Hang Waiting for TenantControlPlane Ready
**Symptoms:** Test gets stuck at "StatusMustEqualTo(tcp, VersionReady)"

**Root Cause:** Missing infrastructure components

**Solutions:**
1. **Check Kamaji Controller:**
   ```bash
   kubectl get pods -n kamaji-system
   ```

2. **Check Datastores:**
   ```bash
   kubectl get datastores -A
   ```

3. **Use Full Setup:**
   ```bash
   make e2e  # Instead of running ginkgo directly
   ```

### Issue: Missing cluster-admin RBAC
**Root Cause:** RBAC bootstrap not configured

**Solution:** Ensure Bootstrap.RBAC configuration:
```yaml
spec:
  bootstrap:
    rbac:
      enabled: true
      adminUsers: ["kubernetes-admin"]
```

### Issue: Missing kube-dns Service
**Root Cause:** CoreDNS addon not configured

**Solution:** Add CoreDNS addon:
```yaml
spec:
  addons:
    coreDNS:
      imageRepository: "registry.k8s.io/coredns"
      imageTag: "v1.10.1"
```

## Test File Overview

### New Test Files
- `tenant_validation_utils_test.go` - Validation framework and utilities
- `tcp_resource_validation_test.go` - Comprehensive addon and RBAC tests  
- `tcp_missing_resources_regression_test.go` - Regression tests for reported issues
- `tcp_validation_unit_test.go` - Unit tests for configuration validation

### Enhanced Files
- `tcp_ready_test.go` - Added tenant resource validation to existing test

## What Resources Are Validated

### RBAC Resources (when `Bootstrap.RBAC.Enabled: true`)
- ✅ ClusterRole: `cluster-admin`, `admin`, `edit`, `view`, `system:node`
- ✅ ClusterRoleBinding: `kamaji-bootstrap-admin-users`
- ✅ ClusterRoleBinding: `kamaji-bootstrap-admin-groups` (if groups specified)

### CoreDNS Resources (when `Addons.CoreDNS` configured)
- ✅ Service: `kube-dns` (in kube-system namespace)
- ✅ Deployment: `coredns` (in kube-system namespace)
- ✅ ConfigMap: `coredns` (in kube-system namespace)
- ✅ ServiceAccount: `coredns` (in kube-system namespace)
- ✅ ClusterRole: `system:coredns`
- ✅ ClusterRoleBinding: `system:coredns`

### kube-proxy Resources (when `Addons.KubeProxy` configured)
- ✅ DaemonSet: `kube-proxy` (in kube-system namespace)
- ✅ ConfigMap: `kube-proxy` (in kube-system namespace)
- ✅ ServiceAccount: `kube-proxy` (in kube-system namespace)
- ✅ ClusterRoleBinding: `kubeadm:node-proxier`

### Standard Kubernetes Resources
- ✅ Namespace: `default`, `kube-system`
- ✅ Service: `kubernetes` (in default namespace)
- ✅ API server responsiveness
- ✅ Cluster version information

## Configuration Templates

### Complete TenantControlPlane Configuration
```yaml
apiVersion: kamaji.clastix.io/v1alpha1
kind: TenantControlPlane
metadata:
  name: my-tenant-cluster
  namespace: default
spec:
  controlPlane:
    deployment:
      replicas: 1
    service:
      serviceType: ClusterIP
  networkProfile:
    address: "172.18.0.10"
  kubernetes:
    version: "v1.29.0"
    kubelet:
      cgroupfs: "cgroupfs"
    admissionControllers:
      - "LimitRanger"
      - "ResourceQuota"
  bootstrap:
    rbac:
      enabled: true
      adminUsers: ["kubernetes-admin"]
      adminGroups: ["system:masters"]
  addons:
    coreDNS:
      imageRepository: "registry.k8s.io/coredns"
      imageTag: "v1.10.1"
    kubeProxy:
      imageRepository: "registry.k8s.io/kube-proxy"
      imageTag: "v1.29.0"
```

## Running Tests in CI/CD

For continuous integration, use the full E2E setup:

```bash
# In your CI pipeline
make e2e
```

This ensures all infrastructure is properly configured and tests run against real tenant clusters.