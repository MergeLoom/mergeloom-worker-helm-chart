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

## Upgrade

Use `helm upgrade` to update an existing installation. Pass `--version` to pin a specific chart release, or omit it to pull the latest published version.

### Upgrade the chart version

```bash
helm upgrade mergeloom-worker oci://registry-1.docker.io/mergeloom/mergeloom-worker \
  --version 1.0.3 \
  --reuse-values
```

`--reuse-values` carries forward all previously set values. Override individual values by adding extra `--set` flags alongside it.

### Upgrade the worker image tag

```bash
helm upgrade mergeloom-worker oci://registry-1.docker.io/mergeloom/mergeloom-worker \
  --version 1.0.3 \
  --reuse-values \
  --set image.tag="1.1"
```

### Scale executor replicas

```bash
helm upgrade mergeloom-worker oci://registry-1.docker.io/mergeloom/mergeloom-worker \
  --version 1.0.3 \
  --reuse-values \
  --set executors.replicaCount=3
```

### clusterToken on upgrade

When the chart manages its own Secret (i.e. `secret.existingSecretName` is not set), it uses a Helm lookup to read the previously generated `JCA_WORKER_CLUSTER_TOKEN` from the existing Secret and reuses it automatically. You do not need to pass the token manually on upgrade.

If you supply `secret.existingSecretName`, the token lives in your own Secret and is never touched by the chart.

### Persistence on upgrade

PVCs created by the chart (`persistence.gateway`, `persistence.workspaces`, `persistence.cliConfig`) are **not** deleted or recreated on upgrade. Their data persists across chart upgrades. To resize a PVC, edit it directly with `kubectl` after upgrading the chart — Helm does not manage PVC resizing.

## Post-install

### Access the gateway UI

The gateway service is only reachable inside the cluster by default. Port-forward it locally:

```bash
kubectl port-forward svc/mergeloom-worker 8010:8010
```

Then open [http://127.0.0.1:8010/](http://127.0.0.1:8010/) in your browser.

### CLI authentication

If your jobs use the Codex or Claude Code CLIs, authenticate through the gateway pod after install:

```bash
# Codex CLI
kubectl exec -it deploy/mergeloom-worker-gateway -- codex login

# Claude Code CLI
kubectl exec -it deploy/mergeloom-worker-gateway -- claude auth login
```

The gateway and executor pods share the `persistence.cliConfig` PVC so CLI auth state is available to all executors. When scaling executors across multiple nodes, ensure the `cliConfig` StorageClass supports the access mode you configure (e.g. `ReadWriteMany` for multi-node).

## Values

Every value is optional unless marked **Required**.

### Image

| Value | Default | Description |
|---|---|---|
| `image.repository` | `mergeloom/mergeloom` | Docker image repository for the MergeLoom worker. |
| `image.tag` | `"1.0"` | Image tag to deploy. `1.0` tracks the supported 1.0 release line. |
| `image.pullPolicy` | `Always` | Kubernetes image pull policy. `Always` keeps mutable tags such as `1.0` current. |

### Gateway

| Value | Default | Description |
|---|---|---|
| `gateway.replicaCount` | `1` | Number of gateway pods. Keep this at `1`; executors scale job capacity separately. |

### Executors

| Value | Default | Description |
|---|---|---|
| `executors.replicaCount` | `1` | Number of executor pods that can claim and run jobs. |

### Service

| Value | Default | Description |
|---|---|---|
| `service.type` | `ClusterIP` | Service type for the worker gateway. `ClusterIP` is recommended. |
| `service.port` | `8010` | Internal service port for the worker gateway UI/API. |

### Service Account

Required only when your cluster uses GKE Workload Identity Federation, EKS IRSA, AKS Workload Identity, or another pod-identity integration.

| Value | Default | Description |
|---|---|---|
| `serviceAccount.create` | `false` | Create a Kubernetes service account for the gateway and executor pods. |
| `serviceAccount.name` | `""` | Existing service account name to use, or the name of the created service account. |
| `serviceAccount.annotations` | `{}` | Service account annotations for your cloud identity integration. Examples: `iam.gke.io/gcp-service-account` (GKE), `eks.amazonaws.com/role-arn` (EKS), `azure.workload.identity/client-id` (AKS). |
| `serviceAccount.automountServiceAccountToken` | `true` | Keep enabled for cloud workload identity token projection. |

### Pod Metadata

| Value | Default | Description |
|---|---|---|
| `podLabels` | `{}` | Extra labels added to gateway and executor pod templates. AKS Workload Identity usually requires `azure.workload.identity/use: "true"`. |
| `podAnnotations` | `{}` | Extra annotations added to gateway and executor pod templates. |

### Worker

| Value | Default | Description |
|---|---|---|
| `worker.controlPlaneUrl` | `"https://controller.mergeloom.ai"` | **Required.** MergeLoom controller URL. Override only if MergeLoom support gives you a different URL. |
| `worker.tenantSlug` | `"demo"` | **Required.** Customer workspace slug from the MergeLoom controller. |
| `worker.enrollmentToken` | `""` | **Required** unless supplied by `secret.existingSecretName`. Enrollment token generated in the MergeLoom controller. |
| `worker.clusterToken` | `""` | Shared token for gateway/executor coordination. If blank, the chart generates one and reuses it on upgrade. |
| `worker.allowedCommands` | `"git,rg,pytest,python,python3"` | Comma-separated allowlist of shell commands the worker may execute during jobs. |
| `worker.maxRepairAttempts` | `2` | Number of executor repair attempts before a job is marked failed. |
| `worker.commandTimeoutSeconds` | `300` | Per-command timeout in seconds. |
| `worker.controlPlaneRequestTimeoutSeconds` | `60` | Timeout in seconds for control-plane HTTP requests. |
| `worker.activeJobHeartbeatIntervalSeconds` | `15` | Heartbeat interval in seconds while a job is actively running. |

### Secret

| Value | Default | Description |
|---|---|---|
| `secret.existingSecretName` | `""` | Name of an existing Kubernetes Secret to consume with `envFrom`. Recommended for production so sensitive values do not live in `values.yaml` or Helm release metadata. When set, the chart does not create its own Secret. Include `JCA_WORKER_CLUSTER_TOKEN` in the Secret, or generate it before install. |

### Provider Environment (AI credentials and model defaults)

Leave unused providers blank. Sensitive values in `values.yaml` are a quick-start fallback only — for production, prefer `secret.existingSecretName`.

#### OpenAI

| Value | Default | Description |
|---|---|---|
| `providerEnv.openaiApiKey` | `""` | *(Sensitive)* OpenAI API key for OpenAI-backed execution. |
| `providerEnv.openaiModel` | `""` | Default OpenAI model or profile. |

#### Anthropic

| Value | Default | Description |
|---|---|---|
| `providerEnv.anthropicApiKey` | `""` | *(Sensitive)* Anthropic API key for Anthropic-backed execution. |
| `providerEnv.anthropicModel` | `""` | Default Anthropic model or profile. |
| `providerEnv.claudeCodeModel` | `""` | Default Claude Code model. |

#### Vertex AI (GCP)

| Value | Default | Description |
|---|---|---|
| `providerEnv.vertexAuthMethod` | `""` | Vertex AI auth method: `service_account_json`, `adc`, or `access_token`. |
| `providerEnv.vertexEndpointMode` | `""` | Vertex AI endpoint mode: `structured` or `raw-endpoint`. |
| `providerEnv.vertexEndpointUrl` | `""` | Vertex AI raw endpoint URL. Used only when `vertexEndpointMode` is `raw-endpoint`. |
| `providerEnv.vertexProjectId` | `""` | Vertex AI project ID for structured publisher model paths. |
| `providerEnv.vertexLocation` | `""` | Vertex AI location for structured publisher model paths. |
| `providerEnv.vertexPublisher` | `""` | Vertex AI publisher for structured publisher model paths. Defaults to `google` in the worker. |
| `providerEnv.vertexModel` | `""` | Default Vertex AI model for structured publisher model paths. |
| `providerEnv.vertexCredentialsPath` | `""` | ADC credential file path. Leave blank for GKE Workload Identity or metadata credentials. |
| `providerEnv.vertexServiceAccountJson` | `""` | *(Sensitive)* Vertex AI service account JSON. Prefer `secret.existingSecretName` for production. |
| `providerEnv.vertexAccessToken` | `""` | *(Sensitive)* Vertex AI access token. Advanced/testing only — tokens expire. |

#### AWS Bedrock

| Value | Default | Description |
|---|---|---|
| `providerEnv.bedrockAuthMethod` | `""` | AWS Bedrock auth method: `default_chain`, `static_keys`, or `profile`. |
| `providerEnv.bedrockRegion` | `""` | AWS Bedrock region. |
| `providerEnv.bedrockModelId` | `""` | AWS Bedrock model ID. |
| `providerEnv.bedrockEndpointUrl` | `""` | Bedrock endpoint override for local sandboxes such as LocalStack. |
| `providerEnv.awsAccessKeyId` | `""` | *(Sensitive)* AWS access key ID for Bedrock. |
| `providerEnv.awsSecretAccessKey` | `""` | *(Sensitive)* AWS secret access key for Bedrock. |
| `providerEnv.awsSessionToken` | `""` | *(Sensitive)* AWS session token for temporary credentials. |
| `providerEnv.awsProfile` | `""` | AWS profile from mounted `~/.aws/config` or `~/.aws/credentials`. |

#### Azure AI Foundry

| Value | Default | Description |
|---|---|---|
| `providerEnv.azureFoundryAuthMethod` | `""` | Azure AI Foundry auth method: `api_key`, `client_secret`, `managed_identity`, `workload_identity`, or `bearer_token`. |
| `providerEnv.azureFoundryEndpoint` | `""` | Azure AI Foundry endpoint URL. |
| `providerEnv.azureFoundryApiKey` | `""` | *(Sensitive)* Azure AI Foundry API key. |
| `providerEnv.azureFoundryTenantId` | `""` | Azure tenant ID for Entra service principal or workload identity auth. |
| `providerEnv.azureFoundryClientId` | `""` | Azure client ID for service principal, managed identity, or workload identity auth. |
| `providerEnv.azureFoundryClientSecret` | `""` | *(Sensitive)* Azure client secret for Entra service-principal auth. |
| `providerEnv.azureFoundryFederatedTokenFile` | `""` | Azure federated token file path. Usually injected by AKS Workload Identity. |
| `providerEnv.azureFoundryBearerToken` | `""` | *(Sensitive)* Azure bearer token. Advanced/testing only — tokens expire. |
| `providerEnv.azureFoundryModel` | `""` | Azure AI Foundry model/deployment name. |

### Persistence

PVCs are **not** deleted on chart upgrade. Resize PVCs directly with `kubectl` — Helm does not manage PVC resizing.

#### Gateway state (`persistence.gateway`)

Stores worker UI state, provider config, runtime config, and local state.

| Value | Default | Description |
|---|---|---|
| `persistence.gateway.enabled` | `true` | Enable persistent storage for gateway state. Recommended for production. |
| `persistence.gateway.accessMode` | `ReadWriteOnce` | Kubernetes PVC access mode when gateway persistence is enabled. |
| `persistence.gateway.size` | `5Gi` | Requested gateway PVC storage size. |
| `persistence.gateway.storageClassName` | `""` | StorageClass name. Leave blank to use the cluster default. |

#### Executor workspaces (`persistence.workspaces`)

Stores cloned repositories and job workspaces.

| Value | Default | Description |
|---|---|---|
| `persistence.workspaces.enabled` | `true` | Enable persistent storage for job workspaces. Recommended for production. |
| `persistence.workspaces.accessMode` | `ReadWriteOnce` | Kubernetes PVC access mode when workspace persistence is enabled. |
| `persistence.workspaces.size` | `10Gi` | Requested storage size per executor replica. |
| `persistence.workspaces.storageClassName` | `""` | StorageClass name. Leave blank to use the cluster default. |

#### CLI auth config (`persistence.cliConfig`)

Stores Codex/Claude CLI auth state when used. The gateway and executor pods share this PVC.

| Value | Default | Description |
|---|---|---|
| `persistence.cliConfig.enabled` | `true` | Enable persistent storage for CLI authentication/configuration. Recommended when using CLI auth. |
| `persistence.cliConfig.accessMode` | `ReadWriteOnce` | Kubernetes PVC access mode when CLI config persistence is enabled. |
| `persistence.cliConfig.size` | `1Gi` | Requested CLI config PVC storage size. |
| `persistence.cliConfig.storageClassName` | `""` | StorageClass name. Leave blank to use the cluster default. |

### Scheduling

| Value | Default | Description |
|---|---|---|
| `resources` | `{}` | Kubernetes resource requests/limits applied to both gateway and executor containers. |
| `nodeSelector` | `{}` | Node selector applied to gateway and executor pods. |
| `tolerations` | `[]` | Tolerations applied to gateway and executor pods. |
| `affinity` | `{}` | Affinity rules applied to gateway and executor pods. |

### Name overrides

| Value | Default | Description |
|---|---|---|
| `nameOverride` | `""` | Override the short chart name used in Kubernetes object labels/names. |
| `fullnameOverride` | `""` | Override the full Kubernetes object name. Leave blank for the Helm release name plus chart name. |

### Reserved values

The following values are kept for forward compatibility. They are **not required** for current installs — the gateway runs in UI-managed mode and executors read provider and runtime config from the gateway. Do not rely on these values for current deployments.

| Value | Default | Description |
|---|---|---|
| `providerConfig.mode` | `"provisioned"` | Reserved. Future provider configuration mode. |
| `providerConfig.provenance` | `"helm"` | Reserved. Future provenance label for provider settings. |
| `providerConfig.dbPath` | `"/data/worker/provider_config.db"` | Reserved. Future SQLite path for provider configuration state. |
| `providerConfig.secretKeyPath` | `"/data/worker/provider_secret.key"` | Reserved. Future local encryption key path for provider secrets. |
| `runtimeConfig.mode` | `"provisioned"` | Reserved. Future runtime configuration mode. |
| `runtimeConfig.provenance` | `"helm"` | Reserved. Future provenance label for runtime settings. |
| `runtimeConfig.dbPath` | `"/data/worker/runtime_config.db"` | Reserved. Future SQLite path for runtime configuration state. |

## Related Links

- [MergeLoom website](https://mergeloom.ai)
- [Install a MergeLoom worker](https://mergeloom.ai/docs/getting-started/install-worker/)
- Worker image: `mergeloom/mergeloom:1.0`
