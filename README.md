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
  --version 1.0.2 \
  --set worker.controlPlaneUrl="https://controller.mergeloom.ai" \
  --set worker.tenantSlug="customer-slug" \
  --set worker.enrollmentToken="worker-enrollment-token"
```

Open the MergeLoom web app at [mergeloom.ai](https://mergeloom.ai) to create a workspace and generate the worker enrollment token.

For production installs, manage sensitive values with a Kubernetes Secret instead of putting them in Helm values:

```bash
kubectl create secret generic mergeloom-worker-env \
  --from-literal=JCA_WORKER_ENROLLMENT_TOKEN="worker-enrollment-token" \
  --from-literal=JCA_OPENAI_API_KEY="openai-api-key"

helm install mergeloom-worker oci://registry-1.docker.io/mergeloom/mergeloom-worker \
  --version 1.0.2 \
  --set worker.controlPlaneUrl="https://controller.mergeloom.ai" \
  --set worker.tenantSlug="customer-slug" \
  --set secret.existingSecretName="mergeloom-worker-env"
```

The chart consumes the existing Secret with `envFrom`. Add only the keys your worker needs:

- `JCA_WORKER_ENROLLMENT_TOKEN`
- `JCA_WORKER_CLUSTER_TOKEN`
- `JCA_OPENAI_API_KEY`
- `JCA_ANTHROPIC_API_KEY`
- `JCA_VERTEX_ACCESS_TOKEN`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`
- `JCA_AZURE_FOUNDRY_API_KEY`

For local testing from this repository:

```bash
helm lint .
helm template mergeloom-worker . \
  --set worker.controlPlaneUrl="https://controller.mergeloom.ai" \
  --set worker.tenantSlug="customer-slug" \
  --set worker.enrollmentToken="worker-enrollment-token"
```

## Values

Important values:

- `image.repository`: worker image repository. Default: `mergeloom/mergeloom`
- `image.tag`: worker image tag. Default: `1.0`
- `worker.controlPlaneUrl`: MergeLoom controller URL. Default: `https://controller.mergeloom.ai`.
- `worker.tenantSlug`: customer workspace slug.
- `worker.enrollmentToken`: worker enrollment token from the controller. For production, prefer `secret.existingSecretName`.
- `secret.existingSecretName`: existing Kubernetes Secret consumed by the worker pods for sensitive env vars.
- `gateway.replicaCount`: gateway replica count. Keep at `1`.
- `executors.replicaCount`: executor count.
- `persistence.*`: PVC settings for worker state, workspaces, and CLI auth config.

## Related Links

- [MergeLoom website](https://mergeloom.ai)
- [Install a MergeLoom worker](https://mergeloom.ai/docs/getting-started/install-worker/)
- Worker image: `mergeloom/mergeloom:1.0`
