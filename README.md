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
  --version 1.0.0 \
  --set worker.controlPlaneUrl="https://controller.example.com" \
  --set worker.tenantSlug="customer-slug" \
  --set worker.enrollmentToken="worker-enrollment-token"
```

Open the MergeLoom web app at [mergeloom.ai](https://mergeloom.ai) to create a workspace and generate the worker enrollment token.

For local testing from this repository:

```bash
helm lint .
helm template mergeloom-worker . \
  --set worker.controlPlaneUrl="https://controller.example.com" \
  --set worker.tenantSlug="customer-slug" \
  --set worker.enrollmentToken="worker-enrollment-token"
```

## Values

Important values:

- `image.repository`: worker image repository. Default: `mergeloom/mergeloom`
- `image.tag`: worker image tag. Default: `1.0`
- `worker.controlPlaneUrl`: controller URL supplied by MergeLoom.
- `worker.tenantSlug`: customer workspace slug.
- `worker.enrollmentToken`: worker enrollment token from the controller.
- `gateway.replicaCount`: gateway replica count. Keep at `1`.
- `executors.replicaCount`: executor count.
- `persistence.*`: PVC settings for worker state, workspaces, and CLI auth config.

## Related Links

- [MergeLoom website](https://mergeloom.ai)
- [Install a MergeLoom worker](https://mergeloom.ai/docs/getting-started/install-worker/)
- Worker image: `mergeloom/mergeloom:1.0`


