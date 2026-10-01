# Repository Guidelines

## Project structure and organization

This repository contains GitOps configuration rather than application source code.
`argocd/` is a self-contained Argo CD App-of-Apps tree, including its
`wproofreader-stack/` Helm chart and per-environment values. `flux/` contains
the equivalent Flux Kustomizations, HelmReleases, sources, and environment
values. Keep the two trees independent: manifests and documentation inside one
tree must not reference the other. Shared comparisons belong in `README.md`.
`scripts/check-parity.sh` checks the configuration duplicated between them.

## Build, test, and development commands

```bash
./scripts/check-parity.sh
helm lint ./argocd/wproofreader-stack
helm template demo ./argocd/wproofreader-stack \
  --set environment=demo --set namespace=wsc
kubectl kustomize argocd/shared/gateway-api-crds
flux build kustomization demo-wproofreader-stack \
  --kustomization-file flux/clusters/local/demo-wproofreader-stack.yaml \
  --path ./flux/environments/demo --dry-run
```

Run the parity check after any values or version change. The Helm commands
validate the generated Argo CD Applications. The Kustomize command needs
network access because it fetches Gateway API CRDs. The Flux command renders
the demo layer as kustomize-controller would.

## Style and naming conventions

Use two-space YAML indentation and preserve the existing field order and
comments. Kubernetes resource and file names use lowercase kebab case. Keep
release names fixed: `mysql`, `wproofreader-app`, and `admin-panel`. Store environment settings in plain values files, never as
inline Application or HelmRelease values. Update both controller trees when
changing chart pins, shared values, or component versions.

## Testing guidelines

There is no unit-test framework or coverage target. Static validation consists
of parity checks and rendering the affected Helm or Kustomize resources. For
ordering, hooks, upgrades, or deletion behavior, follow the kind runbook in
`argocd/README.md` or `flux/README.md` and report the observed result.

## Commits and pull requests

History uses Conventional Commit prefixes such as `feat:`, `fix:`,
`docs:`, and `chore:`, with optional scopes such as `fix(flux):`. Keep
commits focused and omit generated-by or co-author trailers. Pull requests
should identify the affected controller tree, explain any version or lifecycle
change, list validation commands and results, and link the relevant issue.

## Security and configuration

Never commit credentials, license values, or rendered Secrets. Use the ignored
`secrets/` directory or `*.local.yaml` for local files. Changes under
`argocd/` or `flux/` can grant cluster-admin capabilities and require
DevOps review through `.github/CODEOWNERS`.
