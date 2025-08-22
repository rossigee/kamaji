# Cluster-Info Hostname Support Feature

## Overview

This feature adds support for specifying a preferred hostname in the cluster-info ConfigMap instead of always using the LoadBalancer IP address. This solves the issue where kubeadm join commands fail when DNS names are used instead of IP addresses.

## Changes Made

### 1. API Changes (`api/v1alpha1/tenantcontrolplane_types.go`)

Added new field to `ServiceSpec`:

```go
type ServiceSpec struct {
    AdditionalMetadata AdditionalMetadata `json:"additionalMetadata,omitempty"`
    ServiceType ServiceType `json:"serviceType"`
    // PublicAPIServerAddress allows specifying the hostname used in the cluster-info ConfigMap
    // instead of the LoadBalancer IP. This enables proper DNS-based access to the API server.
    // When specified, this address will be used in kubeadm join commands and cluster-info ConfigMap.
    PublicAPIServerAddress string `json:"publicAPIServerAddress,omitempty"`
}
```

### 2. New Method (`api/v1alpha1/tenantcontrolplane_public_address.go`)

Added `PublicControlPlaneAddress()` method that:
- Returns the `PublicAPIServerAddress` if specified
- Falls back to `AssignedControlPlaneAddress()` if not specified
- Used specifically for cluster-info ConfigMap generation

### 3. Kubeadm Parameters (`internal/kubeadm/types.go`)

Added new parameter:

```go
type Parameters struct {
    // ... existing fields ...
    TenantControlPlanePublicAddress string // Public address for cluster-info ConfigMap
    // ... rest of fields ...
}
```

### 4. Bootstrap Token Logic (`internal/kubeadm/bootstraptoken.go`)

Modified cluster-info ConfigMap generation to use public address when available:

```go
// Use public address for cluster-info if specified, otherwise fall back to kubeconfig server
serverAddress := config.Kubeconfig.Clusters[0].Cluster.Server
if len(config.Parameters.TenantControlPlanePublicAddress) > 0 {
    // Construct the public server URL using the public address and port
    port := config.Parameters.TenantControlPlanePort
    if port == 0 {
        port = 6443 // Default Kubernetes API port
    }
    serverAddress = fmt.Sprintf("https://%s:%d", config.Parameters.TenantControlPlanePublicAddress, port)
}
```

### 5. Resource Configuration (`internal/resources/kubeadm_utils.go`)

Updated both `GetKubeadmManifestDeps` and `KubeadmPhaseCreate` functions to populate the new `TenantControlPlanePublicAddress` parameter using the `PublicControlPlaneAddress()` method.

## Usage

To use this feature, specify the `publicAPIServerAddress` in your TenantControlPlane spec:

```yaml
apiVersion: kamaji.clastix.io/v1alpha1
kind: TenantControlPlane
metadata:
  name: golder-secops
  namespace: kamaji-system
spec:
  controlPlane:
    service:
      serviceType: LoadBalancer
      publicAPIServerAddress: "k8s-api.secops.golder.lan"
  # ... rest of spec ...
```

## Benefits

1. **DNS-based Access**: Enables using DNS names in kubeadm join commands instead of IP addresses
2. **Flexibility**: Maintains backward compatibility - if not specified, behavior is unchanged
3. **Proper Certificate Validation**: Works with existing certificate SANs configuration
4. **Bootstrap Token Compatibility**: kubeadm bootstrap tokens will work correctly with DNS names

## Testing

The feature can be tested by:

1. Applying a TenantControlPlane with `publicAPIServerAddress` specified
2. Verifying the cluster-info ConfigMap contains the specified hostname
3. Testing kubeadm join commands work with the generated bootstrap tokens
4. Confirming proper DNS resolution and certificate validation

## Backward Compatibility

This feature is fully backward compatible:
- Existing TenantControlPlanes without `publicAPIServerAddress` work unchanged
- LoadBalancer IP addresses are still used when `publicAPIServerAddress` is not specified
- No existing functionality is modified or removed