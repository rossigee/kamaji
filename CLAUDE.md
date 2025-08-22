# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kamaji is a Kubernetes Control Plane Manager that implements the Hosted Control Plane pattern. It runs Kubernetes Control Plane components in Pods instead of dedicated machines, enabling multi-tenant Kubernetes clusters with reduced operational overhead.

## Core Architecture

### Key Components

**API Resources:**
- `TenantControlPlane` (TCP): Namespace-scoped resource defining a Kubernetes Control Plane instance
- `Datastore`: Cluster-scoped resource managing the backing store for one or more Control Planes

**Controller Architecture:**
- `TenantControlPlaneReconciler`: Main controller managing TCP lifecycle
- `DatastoreController`: Manages datastore connections and configurations
- `CertificateLifecycleController`: Handles automatic certificate rotation
- `TelemetryController`: Manages telemetry data collection

**Resource Management System (`internal/resources/`):**
- Certificate management (CA, API server, kubelet client, service account, front-proxy)
- Kubeadm configuration and phases
- Konnectivity components for secure node-to-control-plane communication
- Core add-ons (CoreDNS, kube-proxy)
- Kubernetes deployments, services, and ingress resources

**Datastore Support (`internal/datastore/`):**
- `etcd`: Traditional Kubernetes datastore
- `MySQL`: Relational database via kine
- `PostgreSQL`: Relational database via kine  
- `NATS`: Message streaming system via kine
- Connection pooling and multi-tenancy support

**Webhook System (`internal/webhook/`):**
- Validation webhooks for TCP and Datastore resources
- Mutating webhooks for defaults and field population
- Security controls and field immutability enforcement

## Development Commands

### Build and Run
```bash
# Run controller locally (requires manifests generation)
make run

# Build container image
make build

# Generate manifests (CRDs, RBAC, webhooks)
make manifests

# Generate Go code (DeepCopy methods)
make generate
```

### Testing
```bash
# Run unit tests
make test

# Run single test file
ginkgo -r -v -focus="<test-pattern>" ./path/to/test/

# Run end-to-end tests (creates KinD cluster)
make e2e

# Run specific e2e test
ginkgo -r -v -focus="<test-pattern>" ./e2e/
```

### Code Quality
```bash
# Run linting
make golint

# Generate API documentation
make apidoc
```

### Development Environment
```bash
# Create KinD cluster for testing
make env

# Install datastores for testing
make datastores                    # All datastores
make datastore-etcd               # etcd only
make datastore-mysql              # MySQL only  
make datastore-postgres           # PostgreSQL only
make datastore-nats               # NATS only

# Install cert-manager (required for webhooks)
make cert-manager

# Install MetalLB for LoadBalancer services
make metallb

# Load container image into KinD
make load
```

## Project Structure

### Core Directories
- `api/v1alpha1/`: Custom Resource Definitions and Go types
- `controllers/`: Main reconciliation logic and controller implementations
- `internal/`: Private packages not exposed as APIs
  - `datastore/`: Database connection and management logic
  - `resources/`: Kubernetes resource generation and management
  - `kubeadm/`: Kubeadm integration for cluster bootstrapping
  - `utilities/`: Common helper functions and utilities
  - `webhook/`: Admission webhook handlers and validation
- `cmd/`: CLI commands (manager, migrate)
- `charts/kamaji/`: Helm chart for deployment
- `config/samples/`: Example resource manifests
- `e2e/`: End-to-end test suites
- `deploy/`: Deployment configurations and examples

### Key Files
- `main.go`: Application entry point with CLI setup
- `Makefile`: Build, test, and development automation
- `.golangci.yml`: Go linting configuration with project-specific rules
- `go.mod`: Go module with Kubernetes 1.33.x dependencies

## Testing Architecture

**Unit Tests:** Use Ginkgo/Gomega, run with `make test`
**E2E Tests:** Full integration tests with real Kubernetes clusters
**Test Environment:** Uses controller-runtime's envtest for API server simulation

**Key Test Patterns:**
- Resource creation and validation
- Controller reconciliation loops
- Certificate lifecycle management
- Multi-datastore scenarios
- Migration between datastores
- Worker node joining scenarios

## Configuration and Deployment

**Helm Chart:** `charts/kamaji/` contains the official Helm chart
**Sample Configurations:** `config/samples/` has examples for all resource types
**Development Environments:** Ready-made configurations for AWS, Azure, and local development

**Required Dependencies:**
- cert-manager for certificate management
- Datastore (etcd, MySQL, PostgreSQL, or NATS)
- LoadBalancer implementation (MetalLB for local development)

## Key Development Patterns

**Resource Generation:** Resources implement the `resources.Resource` interface with `ShouldStatusBeUpdated()`, `ShouldCleanup()`, and `Define()` methods

**Controller Pattern:** Controllers use controller-runtime with:
- Structured logging via logr
- Event recording for user feedback
- Status condition management
- Finalizer-based cleanup

**Certificate Management:** Automated certificate generation and rotation using kubeadm patterns with custom CA hierarchies

**Multi-tenancy:** Datastore isolation through namespacing and user separation, configurable per-datastore

**Validation:** Comprehensive webhook validation for resource immutability, version constraints, and security policies

## Go Module Structure

Uses Go 1.24.1 with:
- Kubernetes 1.33.x API libraries
- controller-runtime for operator patterns
- Ginkgo/Gomega for testing
- Multiple datastore drivers (etcd, MySQL, PostgreSQL, NATS clients)
- Certificate management and cryptographic libraries