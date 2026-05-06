# MergeLoom Worker Helm Chart

Official Helm chart for installing the customer-side [MergeLoom](https://mergeloom.ai) worker on Kubernetes.

MergeLoom gives engineering teams lower-cost, always-on agentic coding without losing control of how work is executed. It standardises prompts, models, validation commands, repository access, and pull request workflows across Jira, GitHub, GitLab, and Azure DevOps. Every worker run is auditable, repeatable, and connected back to the issue and PR/MR that triggered it.

This chart deploys the self-hosted worker gateway and executor components that connect your Kubernetes cluster to the MergeLoom control plane, so teams can run 24/7 coding automation inside their own infrastructure.

For the full customer installation guide, see [Install a MergeLoom worker](https://mergeloom.ai/docs/getting-started/install-worker/).

The worker image is published separately on Docker Hub:

```bash
docker pull mergeloom/mergeloom:1.0
```

## Install

Set the customer-specific values from the controller before installing:

```bash
helm install mergeloom-worker oci://registry-1.docker.io/mergeloom/mergeloom-worker \
  --version 1.0.3 \
  --set worker.controlPlaneUrl="https://controller.mergeloom.ai" \
  --set worker.tenantSlug="customer-slug" \
  --set worker.enrollmentToken="worker-enrollment-token"
```

Open the MergeLoom web app at [mergeloom.ai](https://mergeloom.ai) to create a workspace and generate the worker enrollment token.

When the chart creates its own Secret, it generates `JCA_WORKER_CLUSTER_TOKEN` automatically if `worker.clusterToken` is blank. The token is reused on upgrades and is only used for internal gateway/executor authentication inside the worker install. You do not need to copy it from the controller.

For production installs, manage sensitive values with a Kubernetes Secret instead of putting them in Helm values:

```bash
kubectl create secret generic mergeloom-worker-env \
  --from-literal=JCA_WORKER_ENROLLMENT_TOKEN="worker-enrollment-token" \
  --from-literal=JCA_WORKER_CLUSTER_TOKEN="$(openssl rand -hex 48)" \
  --from-literal=JCA_OPENAI_API_KEY="openai-api-key"

helm install mergeloom-worker oci://registry-1.docker.io/mergeloom/mergeloom-worker \
  --version 1.0.3 \
  --set worker.controlPlaneUrl="https://controller.mergeloom.ai" \
  --set worker.tenantSlug="customer-slug" \
  --set secret.existingSecretName="mergeloom-worker-env"
```

The chart consumes the existing Secret with `envFrom`. Add only the keys your worker needs:

- `JCA_WORKER_ENROLLMENT_TOKEN`
- `JCA_WORKER_CLUSTER_TOKEN`
- `JCA_OPENAI_API_KEY`
- `JCA_ANTHROPIC_API_KEY`
- `JCA_VERTEX_SERVICE_ACCOUNT_JSON`
- `JCA_VERTEX_ACCESS_TOKEN`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`
- `JCA_AZURE_FOUNDRY_API_KEY`
- `AZURE_CLIENT_SECRET`
- `JCA_AZURE_FOUNDRY_BEARER_TOKEN`

For Kubernetes cloud identity, prefer keyless identity where your platform supports it:

- Vertex AI on GKE: set `providerEnv.vertexAuthMethod=adc`, set the Vertex project/location/model values, and run the pods with the Kubernetes service account your GKE Workload Identity Federation setup allows to call Vertex AI.
- AWS Bedrock on EKS: set `providerEnv.bedrockAuthMethod=default_chain` and annotate the worker service account for IRSA.
- Azure Foundry on AKS: set `providerEnv.azureFoundryAuthMethod=workload_identity`, set tenant/client IDs, add the AKS workload identity pod label, and use the injected federated token file.

Example GKE Workload Identity-style install:

```bash
helm upgrade --install mergeloom-worker oci://registry-1.docker.io/mergeloom/mergeloom-worker \
  --version 1.0.3 \
  --set worker.controlPlaneUrl="https://controller.mergeloom.ai" \
  --set worker.tenantSlug="customer-slug" \
  --set secret.existingSecretName="mergeloom-worker-env" \
  --set serviceAccount.create=true \
  --set-string 'serviceAccount.annotations.iam\.gke\.io/gcp-service-account=worker-sa@project.iam.gserviceaccount.com' \
  --set providerEnv.vertexAuthMethod="adc" \
  --set providerEnv.vertexEndpointMode="structured" \
  --set providerEnv.vertexProjectId="gcp-project-id" \
  --set providerEnv.vertexLocation="global" \
  --set providerEnv.vertexModel="gemini-2.5-pro"
```

For local testing from this repository:

```bash
helm lint .
helm template mergeloom-worker . \
  --set worker.controlPlaneUrl="https://controller.mergeloom.ai" \
  --set worker.tenantSlug="customer-slug" \
  --set worker.enrollmentToken="worker-enrollment-token"
```

## Values

### Core Configuration

- `image.repository`: worker image repository. Default: `mergeloom/mergeloom`
- `image.tag`: worker image tag. Default: `1.0`
- `image.pullPolicy`: Kubernetes image pull policy. Default: `Always`
- `worker.controlPlaneUrl`: MergeLoom controller URL. Default: `https://controller.mergeloom.ai`
- `worker.tenantSlug`: customer workspace slug (required)
- `worker.enrollmentToken`: worker enrollment token from the MergeLoom controller (required unless `secret.existingSecretName` is set)
- `worker.clusterToken`: optional internal gateway/executor token. Auto-generated when blank unless `secret.existingSecretName` is used

### Worker Runtime Controls

- `worker.allowedCommands`: comma-separated allowlist of shell commands the worker may execute. Default: `git,rg,pytest,python,python3`
- `worker.maxRepairAttempts`: number of executor repair attempts before a job is marked failed. Default: `2`
- `worker.commandTimeoutSeconds`: per-command timeout in seconds. Default: `300`
- `worker.controlPlaneRequestTimeoutSeconds`: timeout in seconds for control-plane HTTP requests. Default: `60`
- `worker.activeJobHeartbeatIntervalSeconds`: heartbeat interval in seconds while a job is actively running. Default: `15`

### Deployment Configuration

- `gateway.replicaCount`: gateway replica count. Keep at `1`
- `executors.replicaCount`: executor pod count for job claim and execution. Scales job capacity
- `service.type`: internal gateway service type. Default: `ClusterIP` (recommended)
- `service.port`: internal gateway service port. Default: `8010`

### Cloud Identity and Service Accounts

- `serviceAccount.create`: create a service account for gateway and executor pods. Default: `false`
- `serviceAccount.name`: existing service account name or the created service account name
- `serviceAccount.annotations`: service account annotations for cloud identity integrations (GKE Workload Identity, EKS IRSA, AKS Workload Identity, etc.)
- `serviceAccount.automountServiceAccountToken`: enable pod service account token projection. Default: `true`
- `podLabels`: extra labels on gateway and executor pod templates. AKS Workload Identity requires `azure.workload.identity/use: "true"`
- `podAnnotations`: extra annotations on gateway and executor pod templates

### Secrets Management

- `secret.existingSecretName`: name of existing Kubernetes Secret to consume with `envFrom`. Recommended for production to avoid storing sensitive values in `values.yaml`
- `providerEnv.*`: AI provider credentials and model defaults. For production, prefer `secret.existingSecretName`

### Persistence

- `persistence.gateway.enabled`: enable persistent storage for gateway state (worker UI state, provider config, runtime config). Default: `true`. Recommended for production
- `persistence.gateway.accessMode`: PVC access mode. Default: `ReadWriteOnce`
- `persistence.gateway.size`: requested gateway PVC storage. Default: `5Gi`
- `persistence.gateway.storageClassName`: StorageClass name. Leave blank for cluster default
- `persistence.workspaces.enabled`: enable persistent storage for job workspaces (cloned repositories). Default: `true`. Recommended for production
- `persistence.workspaces.accessMode`: PVC access mode. Default: `ReadWriteOnce`
- `persistence.workspaces.size`: requested storage per executor replica. Default: `10Gi`
- `persistence.workspaces.storageClassName`: StorageClass name. Leave blank for cluster default
- `persistence.cliConfig.enabled`: enable persistent storage for CLI auth/config state. Default: `true`. Recommended when using CLI auth
- `persistence.cliConfig.accessMode`: PVC access mode. Default: `ReadWriteOnce`
- `persistence.cliConfig.size`: requested CLI config PVC storage. Default: `1Gi`
- `persistence.cliConfig.storageClassName`: StorageClass name. Leave blank for cluster default

### Pod Resource and Scheduling

- `resources`: optional Kubernetes resource requests/limits applied to gateway and executor containers. Default: `{}`
- `nodeSelector`: optional node selector applied to gateway and executor pods. Default: `{}`
- `tolerations`: optional tolerations applied to gateway and executor pods. Default: `[]`
- `affinity`: optional affinity rules applied to gateway and executor pods. Default: `{}`

### Miscellaneous

- `nameOverride`: override the short chart name used in Kubernetes object labels/names
- `fullnameOverride`: override the full Kubernetes object name

## Related Links

- [MergeLoom website](https://mergeloom.ai)
- [Install a MergeLoom worker](https://mergeloom.ai/docs/getting-started/install-worker/)
- Worker image: `mergeloom/mergeloom:1.0`
