# WProofreader GitOps examples

This repository contains example configurations that deploy the WProofreader stack on Kubernetes
with a GitOps controller.
The stack has WProofreader Server, Admin-panel, and a MySQL database.
You keep the configuration in Git, and the controller installs the stack and keeps
the cluster equal to Git.

## Why this repository exists

The Helm charts install the components of the stack.
A complete deployment also needs settings that connect the components and start them
in the correct order.
For example, MySQL must be ready before the database Jobs run,
all components must use the same Secret names and passwords,
and the public route must send WProofreader requests to WProofreader Server.

This repository provides that integration as a version-pinned reference configuration.
It also shows how Argo CD and Flux can keep the installed resources equal to
the configuration in Git.
Copy the example and change it for your cluster.
If your team does not use a GitOps controller, use the Kubernetes installation guide and install
the same charts with Helm commands.

## When to use this repository

WProofreader supports three ways to deploy the stack:

| Option | Use it for | Where |
| --- | --- | --- |
| Docker Compose on one host | Evaluation, demonstrations, and small installations | [wproofreader-docker](https://github.com/WebSpellChecker/wproofreader-docker/tree/master/examples/admin-panel) |
| Kubernetes with Helm commands | One installation that an operator manages with `helm` | [Kubernetes installation guide](https://docs.wproofreader.com/deployment/installation/kubernetes) |
| Kubernetes with GitOps | Repeatable installations, one or more environments | This repository |

Use this repository if your team operates Kubernetes with Argo CD or Flux,
or if you want these results:

- All settings (chart versions, values, host names) are in Git.
  Each change is a commit that people can review, and you can revert it.
- The controller installs the components in the correct order: the cluster components, then MySQL,
  WProofreader Server, and Admin-panel.
- The controller corrects manual changes in the cluster.
- You add an environment, for example `staging` or `production`,
  with one new directory of values files.

The configurations use the same charts, namespace (`wsc`), release names, Secret names,
and Secret keys as the Kubernetes installation guide.
Read that guide to learn what each component does and how the components connect.

## Install the stack without GitOps

The [Kubernetes installation guide](https://docs.wproofreader.com/deployment/installation/kubernetes) installs the same stack with Helm commands,
step by step.
Do the steps in this order:

1. [Prerequisites](https://docs.wproofreader.com/deployment/installation/kubernetes/prerequisites)
2. [Prepare MySQL](https://docs.wproofreader.com/deployment/installation/kubernetes/prepare-mysql)
3. [Install WProofreader Server](https://docs.wproofreader.com/deployment/installation/kubernetes/install-wproofreader-server)
4. [Install Admin-panel](https://docs.wproofreader.com/deployment/installation/kubernetes/install-admin-panel)
5. [Create the first administrator](https://docs.wproofreader.com/deployment/installation/kubernetes/create-the-first-administrator)
6. [Set up external access](https://docs.wproofreader.com/deployment/installation/kubernetes/set-up-external-access)

To upgrade or remove the stack, see [Upgrade and uninstall](https://docs.wproofreader.com/deployment/installation/kubernetes/upgrade-and-uninstall).

The guide and this repository use the same namespace (`wsc`), release names, Secrets,
and chart versions.
You can use the values files of an environment in this repository with the Helm commands,
for example:

```bash
helm upgrade --install mysql ./mysql-server-helm/mysql --namespace wsc \
  --values argocd/environments/demo/mysql.yaml
```

## Select a controller

The repository has one complete configuration for each controller.
Use the controller that your team already operates:

| Directory | Controller | Start here |
| --- | --- | --- |
| [`argocd/`](argocd/) | Argo CD 3.5 (App-of-Apps and an ApplicationSet) | [`argocd/README.md`](argocd/README.md) |
| [`flux/`](flux/) | Flux 2.9 (Kustomizations and HelmReleases) | [`flux/README.md`](flux/README.md) |

Use only one directory.
Each directory deploys the full stack from one root file and does not refer to the other directory.

## How to use this repository

1. Try the example on a local test cluster.
   Follow the "Step by step" section in the README of your controller.
   This deploys the `demo` environment from this repository without changes.
2. Make your own copy of the repository, and change the settings for your installation.
   See [Make your own copy](#make-your-own-copy).
3. Create the Secrets in your cluster.
   See [Secrets](#secrets).
4. Apply the root file from your copy.
   The controller then deploys the stack.
5. Make all later changes in Git: values, chart versions, and environments.
   Do not use `helm upgrade` or `kubectl edit` on the components.
   The controller replaces such changes.

## Contents

Each controller directory contains:

- A root file that you apply one time.
  The controller then deploys all other parts from Git.
- The shared cluster components: Gateway API CRDs, cert-manager, a self-signed ClusterIssuer,
  and Traefik as the Gateway API controller.
- One directory for each environment, with plain Helm values files for MySQL,
  WProofreader Server, and Admin-panel.
  You can also use these files with `helm install --values`.
- Pinned revisions of the product charts.
- Instructions to add an environment, change a chart version, and remove the stack.

The product charts are in their own repositories:
[wproofreader-helm](https://github.com/WebSpellChecker/wproofreader-helm),
[admin-panel-helm](https://github.com/WebSpellChecker/admin-panel-helm),
and [mysql-server-helm](https://github.com/WebSpellChecker/mysql-server-helm).
This repository refers to them by URL and pinned revision.

## Requirements

- Argo CD 3.5 or Flux 2.9.
- Kubernetes 1.31 or later with Argo CD, and 1.33 or later with Flux 2.9.
  The Gateway API v1.6.1 CRDs do not install on versions before 1.31,
  and Flux 2.9 does not support versions before 1.33.
- A LoadBalancer implementation for the Traefik Service.
  Without an external address, you cannot reach the stack from outside the cluster,
  and Argo CD does not report Traefik as healthy.
- A WProofreader license ticket ID.

## What the configurations deploy

| Component | Version | Namespace | Release |
| --- | --- | --- | --- |
| Gateway API CRDs | v1.6.1, standard channel | cluster scope | none |
| cert-manager | v1.21.1, with a self-signed ClusterIssuer | `cert-manager` | `cert-manager` |
| Traefik | chart 41.5.0 (Traefik 3.7), Gateway API provider only | `traefik` | `traefik` |
| MySQL | 8.4 (mysql-server-helm chart 1.0.0, tag `v1.0.0`) | `wsc` | `mysql` |
| WProofreader Server and db-manager | 6.18.1.0 (wproofreader-helm chart 1.4.0, tag `v1.4.0`) | `wsc` | `wproofreader-app` |
| Admin-panel | 3.0.0 (admin-panel-helm chart 1.0.0, tag `v1.0.0`) | `wsc` | `admin-panel` |

Both controllers install the shared components first.
Then, for each environment, they install MySQL, WProofreader Server, and Admin-panel in this order.
Before WProofreader Server starts, a db-manager hook Job creates
the `cloud_service` database and its users.
Before Admin-panel starts, a migration hook Job creates the tables in `admin_panel_db`.

The `demo` environment uses the `wsc` namespace and the host name `wproofreader.example.com`.
Admin-panel and the WProofreader Server API use the same host name:

- `https://wproofreader.example.com/` opens Admin-panel.
- `https://wproofreader.example.com/wscservice/api` goes to WProofreader Server.

## Secrets

The repository does not contain secret values.
Each chart reads its credentials from an existing Secret.
Create these Secrets in the namespace of the environment before the first sync.
For production, create them with your secret-management system, for example Sealed Secrets, SOPS,
or External Secrets.

| Secret | Used by | Keys |
| --- | --- | --- |
| `mysql-credentials` | `mysql` | `mysql-root-password`, `mysql-password` |
| `wproofreader-db` | `wproofreader-app` and its db-manager Job | `root-password`, `appserver-password`, `admin-panel-password` |
| `wproofreader-license` | `wproofreader-app` | `license` |
| `admin-panel-secrets` | `admin-panel` | `APP_KEY`, `DB_PASSWORD`, `SERVICE_DB_PASSWORD` |

Three passwords occur in two Secrets each.
Use the same value in both:

| Password | Secret and key | Secret and key |
| --- | --- | --- |
| MySQL `root` | `mysql-credentials` / `mysql-root-password` | `wproofreader-db` / `root-password` |
| MySQL `admin_panel` | `mysql-credentials` / `mysql-password` | `admin-panel-secrets` / `DB_PASSWORD` |
| MySQL `app_service` | `wproofreader-db` / `admin-panel-password` | `admin-panel-secrets` / `SERVICE_DB_PASSWORD` |

For a test cluster, you can create the Secrets with `kubectl`:

```bash
export WPR_LICENSE_TICKET_ID='<license_ticket_id>'
export MYSQL_ADMIN_PASSWORD="$(openssl rand -hex 16)"
export ADMIN_PANEL_DB_PASSWORD="$(openssl rand -hex 16)"
export APPSERVER_DB_PASSWORD="$(openssl rand -hex 16)"
export SERVICE_DB_PASSWORD="$(openssl rand -hex 16)"
export APP_KEY="base64:$(openssl rand -base64 32)"

kubectl create namespace wsc
kubectl -n wsc create secret generic mysql-credentials \
  --from-literal=mysql-root-password="${MYSQL_ADMIN_PASSWORD}" \
  --from-literal=mysql-password="${ADMIN_PANEL_DB_PASSWORD}"
kubectl -n wsc create secret generic wproofreader-db \
  --from-literal=root-password="${MYSQL_ADMIN_PASSWORD}" \
  --from-literal=appserver-password="${APPSERVER_DB_PASSWORD}" \
  --from-literal=admin-panel-password="${SERVICE_DB_PASSWORD}"
kubectl -n wsc create secret generic wproofreader-license \
  --from-literal=license="${WPR_LICENSE_TICKET_ID}"
kubectl -n wsc create secret generic admin-panel-secrets \
  --from-literal=APP_KEY="${APP_KEY}" \
  --from-literal=DB_PASSWORD="${ADMIN_PANEL_DB_PASSWORD}" \
  --from-literal=SERVICE_DB_PASSWORD="${SERVICE_DB_PASSWORD}"
```

Keep the values in your password manager.
Do not change `APP_KEY` after the first install: Admin-panel cannot read its encrypted data
with a different key.

## Make your own copy

The controller reads the configuration from a Git repository.
To change any setting, you need a copy of this repository on a Git server
that your cluster can read, for example a fork or a new private repository.

1. Copy the repository to your Git server.
2. Change the repository URL `https://github.com/WebSpellChecker/wproofreader-gitops` to
   the URL of your copy.
   To find all files that contain it, run:

   ```bash
   grep -rl 'WebSpellChecker/wproofreader-gitops' argocd flux
   ```

   In `argocd/`, the URL is in the root files, `bootstrap/`, `shared/apps/`,
   and `wproofreader-stack/values.yaml`.
   In `flux/`, it is in `root.yaml` only.
3. If your copy uses a branch other than `main`, change the branch in
   the same files (`targetRevision` and `revision` for Argo CD, `branch` for Flux).
4. Change the values files of your environment.
   At a minimum, change the host name and the certificate issuer.
   See [Production notes](#production-notes).
5. If your copy is private, give the controller read access.
   See step 3 in the README of your controller.

## Pinned versions

The product charts are pinned to release tags.
The tags are in `argocd/wproofreader-stack/values.yaml` and `flux/sources/charts.yaml`.
The Argo CD and Flux pins must stay equal.
`scripts/check-parity.sh` compares the tags and the chart directories of the two directories.

The cert-manager and Traefik chart versions and the Gateway API version are in
the shared configuration of each directory.
Change a version deliberately, and test the change before you use it in production.
Change the Gateway API version and the Traefik chart version together.

## Use a different Gateway API controller

Traefik is the default Gateway API controller.
To use another controller, for example Envoy Gateway:

1. Replace the Traefik Application (`argocd/shared/apps/02-traefik.yaml`) or
   the Traefik HelmRelease (`flux/shared/traefik/`) with the other controller.
2. In the `admin-panel.yaml` values file of each environment,
   set `gateway.gatewayClassName` to the GatewayClass of that controller.
   Set `gateway.listenerPort` and `gateway.tls.listenerPort` to the ports that
   the controller listens on, for example `80` and `443`.

To use an Ingress instead, set `gateway.enabled: false` and configure the `ingress` values
in `admin-panel.yaml`.
See the [Admin-panel routing guide](https://github.com/WebSpellChecker/admin-panel-helm/blob/main/docs/ROUTING.md).

## Production notes

- Replace the self-signed ClusterIssuer with a production issuer, for example Let's Encrypt (ACME).
  Set `gateway.tls.certManager.issuerRef` in `admin-panel.yaml` to that issuer.
- Replace `wproofreader.example.com` with your DNS name in `admin-panel.yaml` (`config.appUrl`,
  `config.appServerUrl`, and `gateway.hostnames`).
- The demo keeps Admin-panel uploads in the Pod.
  They are lost when the Pod restarts.
  For production, enable the `persistence` PVC (ReadWriteMany) or use S3-compatible object storage.
  See the [Admin-panel chart values](https://github.com/WebSpellChecker/admin-panel-helm/blob/main/admin-panel/values.yaml).
- The demo sets `config.mail.mailer: log`.
  Admin-panel does not send email, and invitation links go to the log of the web Pod.
  To send email, set the SMTP values.
- MySQL runs as one Pod with an 8 GiB volume and no backups.
  For production, use a MySQL server that your team operates,
  for example a managed database service.
  Then remove the MySQL Application or HelmRelease and set the MySQL host in `wproofreader-app.yaml`
  and `admin-panel.yaml`.
  Create `admin_panel_db` and the `admin_panel` user as the
  [Kubernetes installation guide](https://docs.wproofreader.com/deployment/installation/kubernetes)
  describes.
- The images come from Docker Hub (`webspellchecker/*` and `mysql`).
  To use a private registry, set `image.repository` and `imagePullSecrets` in the values files.
- Push or merge access to this repository (or to your copy) gives administrator
  access to the cluster.
  Protect the branch and require reviews.

## Related repositories

| Repository | Content |
| --- | --- |
| [wproofreader-helm](https://github.com/WebSpellChecker/wproofreader-helm) | Helm chart for WProofreader Server and db-manager |
| [admin-panel-helm](https://github.com/WebSpellChecker/admin-panel-helm) | Helm chart for Admin-panel, with a [quick start](https://github.com/WebSpellChecker/admin-panel-helm/blob/main/docs/QUICKSTART.md) |
| [mysql-server-helm](https://github.com/WebSpellChecker/mysql-server-helm) | Helm chart for MySQL |
| [wproofreader-docker](https://github.com/WebSpellChecker/wproofreader-docker) | Docker images and a Docker Compose example |
