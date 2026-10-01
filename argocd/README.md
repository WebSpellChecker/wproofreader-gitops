# Deploy the WProofreader stack with Argo CD

This directory contains the complete Argo CD configuration for the
WProofreader stack. Apply `root-app.yaml` one time. Argo CD then installs the
Gateway API CRDs, cert-manager, Traefik, MySQL, WProofreader Server, and
Admin-panel in sync-wave order. It reads the product charts from
`wproofreader-helm`, `admin-panel-helm`, and `mysql-server-helm`, and the
values files from this repository.

The [Kubernetes installation guide](https://docs.wproofreader.com/deployment/installation/kubernetes)
installs the same charts with Helm commands. It uses the same namespace
(`wsc`), release names, and Secrets.

| Component | Version |
| --- | --- |
| Kubernetes | 1.31 or later |
| Argo CD | 3.5 |
| Gateway API CRDs | v1.6.1, standard channel |
| cert-manager | v1.21.1 |
| Traefik chart | 41.5.0 (Traefik 3.7) |
| mysql-server-helm | commit `399ecb2` on `main` (chart 1.0.0), MySQL 8.4 |
| wproofreader-helm | commit `0c95786` on `main` (chart 1.4.0), WProofreader Server 6.18.1.0 |
| admin-panel-helm | commit `defea36` on `development` (chart 1.0.0), Admin-panel 3.0.0 |

## Layout

```
argocd/
├── root-app.yaml                 # the ONE file you apply: `root` AppProject + root Application `wproofreader-root`
├── root-app-no-shared.yaml       # the same, for clusters that already have a GatewayClass and a ClusterIssuer
├── argocd-cm-health-patch.yaml   # one-time argocd-cm patch (health check for Applications)
├── bootstrap/                    # what the root syncs (recursively), in sync-wave order
│   ├── projects/                     wave -1  AppProjects: bootstrap, shared, wproofreader
│   ├── shared.yaml                   wave  0  App-of-Apps -> shared/apps
│   └── wproofreader-stacks.yaml      wave  1  ApplicationSet: one stack for each environments/<name>/
├── shared/                       # cluster components (project `shared`, the only project with cluster-scoped rights)
│   ├── apps/
│   │   ├── 00-gateway-api-crds.yaml   wave -3  Gateway API CRDs v1.6.1
│   │   ├── 01-cert-manager.yaml       wave -2  cert-manager v1.21.1 and its CRDs
│   │   ├── 02-traefik.yaml            wave -1  Traefik chart 41.5.0 (Gateway API provider only)
│   │   └── 03-cluster-resources.yaml  wave  0  self-signed ClusterIssuer
│   ├── cert-manager/values.yaml   # plain Helm values files, loaded through multiple sources ($values/...)
│   ├── traefik/values.yaml
│   ├── gateway-api-crds/          # kustomize wrapper for the Gateway API release manifest
│   └── cluster-resources/         # self-signed ClusterIssuer
├── wproofreader-stack/           # Helm chart that renders the 3 product Applications of ONE environment
│   ├── values.yaml                # chart repositories and pinned revisions
│   └── templates/                 # mysql (wave 1), wproofreader-app (wave 2), admin-panel (wave 3)
└── environments/                 # one directory for each environment = one complete stack
    └── demo/
        ├── stack.yaml             # namespace of the environment
        ├── mysql.yaml             # plain Helm values files (also for `helm install --values`)
        ├── wproofreader-app.yaml
        └── admin-panel.yaml       # host name, Gateway, TLS, and /wscservice routing
```

All Application paths start at the repository root (`argocd/...`).

The `shared` Application installs the cluster components in sync-wave order.
If the cluster already has a GatewayClass and a ClusterIssuer, apply
`root-app-no-shared.yaml` instead of `root-app.yaml`. Then set
`gateway.gatewayClassName` and `gateway.tls.certManager.issuerRef` in
`admin-panel.yaml` to the existing objects.

The `wproofreader-stacks` ApplicationSet has a Git files generator for
`argocd/environments/*/stack.yaml`. For each directory, it creates an
`<environment>-wproofreader-stack` Application from the `wproofreader-stack/`
chart. That Application creates the three product Applications of the
environment.

Each product Application has two sources: the chart repository, and this
repository with `ref: values`. The chart reads its values file from
`$values/argocd/environments/<environment>/`. The Applications contain no
inline values.

## Projects

| Project | Used by | Destinations | Cluster-scoped resources |
| --- | --- | --- | --- |
| `root` | the root Application | `argocd` (AppProject, Application, ApplicationSet) | none. `root-app.yaml` defines it; apply that file again to change it |
| `bootstrap` | `shared` and each `<environment>-wproofreader-stack` | `argocd` (Applications only) | none |
| `shared` | Gateway API CRDs, cert-manager, Traefik, ClusterIssuer | `cert-manager`, `traefik`, `kube-system` | the kinds listed in `bootstrap/projects/shared.yaml` |
| `wproofreader` | the product Applications of all environments | the namespaces listed in `bootstrap/projects/wproofreader.yaml` | none |

The root syncs the projects in `bootstrap/projects/` from Git. Add the
namespace of each environment to `bootstrap/projects/wproofreader.yaml`.
Argo CD rejects destinations that are not in that list.

## Order of deployment

Argo CD applies lower `argocd.argoproj.io/sync-wave` values first:

```
shared:                            -3 Gateway API CRDs -> -2 cert-manager -> -1 Traefik -> 0 ClusterIssuer
<environment>-wproofreader-stack:   1 MySQL -> 2 WProofreader Server (db-manager hook) -> 3 Admin-panel (migration hook)
```

Two Argo CD behaviors are important:

- Argo CD has no built-in health check for the `Application` kind. Without
  it, a parent Application does not wait until a child Application is
  healthy. Apply `argocd-cm-health-patch.yaml` one time after you install
  Argo CD.
- The order of new Applications is best effort, also with the health check.
  Argo CD reads health from its cache, and a new object can arrive in the
  cache a few seconds late. Thus, the next wave can start too early. Each
  Application has a `retry` policy, and the hook Jobs wait for MySQL. An early
  start causes a retry, not a failure.

The db-manager Job of WProofreader Server and the migration Job of
Admin-panel are Helm `pre-install,pre-upgrade` hooks. Argo CD runs them as
PreSync hooks.

## Step by step

This procedure deploys the `demo` environment from this repository, without
changes, on a local [kind](https://kind.sigs.k8s.io/) cluster. Use it to see
how the stack starts and how Argo CD shows it. On another cluster, start at
step 2.

To deploy your own configuration, first make your own copy of the
repository. See [Make your own copy](../README.md#make-your-own-copy). Then
use the same steps with your copy.

### 0. Prerequisites

- `kubectl`, `kind`, `openssl`, `git`, and Docker.
- [cloud-provider-kind](https://github.com/kubernetes-sigs/cloud-provider-kind).
  It gives LoadBalancer addresses to Services in kind clusters.
- A WProofreader license ticket ID.

### 1. Create the cluster

```bash
kind create cluster --name wproofreader --image kindest/node:v1.31.9
```

In a second terminal, start cloud-provider-kind and keep it running:

```bash
sudo cloud-provider-kind
```

Without it, the Traefik Service stays `<pending>` and the `shared`
Application does not become healthy.

Clone this repository:

```bash
git clone https://github.com/WebSpellChecker/wproofreader-gitops.git
cd wproofreader-gitops
```

### 2. Install Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.3/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=180s
kubectl -n argocd patch configmap argocd-cm --type merge \
  --patch-file argocd/argocd-cm-health-patch.yaml
```

Use `--server-side`. The ApplicationSet CRD is too large for client-side
apply.

To open the Argo CD UI, get the `admin` password and start a port forward:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
kubectl -n argocd port-forward service/argocd-server 8080:443
```

Then open `https://localhost:8080` and sign in as `admin`.

### 3. Optional: give Argo CD access to private repositories

Skip this step if Argo CD can read the repositories without credentials. If
you use private copies of the repositories, create a repository credential
template for their organization. Replace the placeholders:

```bash
kubectl -n argocd create secret generic github-creds \
  --from-literal=type=git \
  --from-literal=url=https://github.com/<organization> \
  --from-literal=username='<user>' \
  --from-literal=password='<read_only_token>'
kubectl -n argocd label secret github-creds \
  argocd.argoproj.io/secret-type=repo-creds
```


### 4. Create the namespace and the Secrets

Create the namespace and the four Secrets before the first sync. Argo CD
reads these Secrets, but it does not create or delete them. Use the
commands in the [repository README](../README.md#secrets). They create the
`wsc` namespace and the Secrets `mysql-credentials`, `wproofreader-db`,
`wproofreader-license`, and `admin-panel-secrets`.

### 5. Deploy the stack

```bash
kubectl apply -n argocd -f argocd/root-app.yaml
```

The root Application `wproofreader-root` syncs `argocd/bootstrap/`. Wave -1
creates the AppProjects, wave 0 creates `shared`, and wave 1 creates the
`wproofreader-stacks` ApplicationSet. The ApplicationSet finds
`argocd/environments/demo/stack.yaml` and creates `demo-wproofreader-stack`.

### 6. Monitor the sync

```bash
kubectl -n argocd get applications --watch
```

The `shared` Application installs the cluster components. Then
`demo-wproofreader-stack` creates `demo-mysql`, `demo-wproofreader-app`, and
`demo-admin-panel` in this order. The first sync takes approximately 10
minutes. Most of the time is for image downloads.

Wait until all Applications show `Synced` and `Healthy`. The status of the
ApplicationSet does not show the health of the workloads. Look at the
Applications for that.

You can monitor the hook Jobs in the `wsc` namespace:

```bash
kubectl -n wsc get jobs,pods --watch
```

The `wproofreader-app-db-provision` Job completes before the WProofreader
Server Pod starts. The `admin-panel-migrate` Job completes before the
Admin-panel web, worker, and scheduler Pods start.

### 7. Check the stack

Get the external address of Traefik:

```bash
LB_IP="$(kubectl -n traefik get service traefik \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "${LB_IP}"
```

Check the Gateway, the routes, and the certificate:

```bash
kubectl -n wsc get gateway,httproute,certificate
```

The Gateway shows `PROGRAMMED True`, and the certificate shows `READY True`.

Send requests to Admin-panel and WProofreader Server. The `--resolve` option
sends the host name to the Traefik address, so you do not need a DNS record:

```bash
H=wproofreader.example.com
curl --silent --output /dev/null --write-out '%{http_code}\n' \
  --resolve "${H}:80:${LB_IP}" "http://${H}/up"
curl --silent --insecure --output /dev/null --write-out '%{http_code}\n' \
  --resolve "${H}:443:${LB_IP}" "https://${H}/up"
curl --silent --insecure --resolve "${H}:443:${LB_IP}" \
  "https://${H}/wscservice/api?cmd=ver"
curl --silent --insecure --resolve "${H}:443:${LB_IP}" \
  "https://${H}/wscservice/api?cmd=license_status"
```

The first command shows `301` (redirect to HTTPS). The second command shows
`200`. The third response contains `6.18.1.0`, and the fourth response
contains `"valid":true`.

### 8. Create the first administrator

To open Admin-panel in a web browser, add this line to `/etc/hosts`. Replace
`<LB_IP>` with the address from step 7:

```
<LB_IP> wproofreader.example.com
```

Get a setup link:

```bash
kubectl -n wsc exec deployment/admin-panel-web -- \
  php artisan app:setup-token --regenerate --no-ansi
```

Open the setup URL from the output. The certificate is self-signed, so the
browser shows a warning. Create the administrator, then sign in. The demo
writes email to the log. To get invitation links, read the log of the web
Pod:

```bash
kubectl -n wsc logs deployment/admin-panel-web
```

## Add an environment

Copy the `demo` environment:

```bash
cp -r argocd/environments/demo argocd/environments/production
```

1. Set the namespace in `environments/production/stack.yaml`.
2. Add the namespace to `destinations` in `bootstrap/projects/wproofreader.yaml`.
3. Change the values files: host name, issuer, storage sizes, and resources.
   Also change the namespace in these addresses: `config.db.host`,
   `config.serviceDb.host`, and `config.appServerInternalUrl` in
   `admin-panel.yaml`, and `database.host` in `wproofreader-app.yaml`. Do not
   change the release names. The addresses `mysql-primary.<namespace>` and
   `wproofreader-app.<namespace>` use them.
4. Create the namespace and its Secrets. The Applications do not create the
   namespace.
5. Commit and push. The ApplicationSet creates
   `production-wproofreader-stack`.

## Change a chart version

The product charts are pinned to commit SHAs in
`wproofreader-stack/values.yaml`. Change the revision, then commit and push.
Use a commit that exists in the remote chart repository. You can use a release
tag after the chart repository publishes one.

Before you upgrade, back up `admin_panel_db` and `cloud_service`. A rollback
does not undo database migrations.

The cert-manager and Traefik versions are in `shared/apps/`. Change the
Traefik chart version and the Gateway API version in
`shared/gateway-api-crds/kustomization.yaml` together.

## Remove the stack

To remove a disposable kind cluster:

```bash
kind delete cluster --name wproofreader
```

To remove one environment and keep the shared components, delete the
directory of the environment from Git. If you delete the generated
`<environment>-wproofreader-stack` Application directly, the ApplicationSet
creates it again.

```bash
git rm -r argocd/environments/demo
git commit -m "Remove the demo environment"
git push
kubectl -n argocd get applications --watch
```

The ApplicationSet deletes `demo-wproofreader-stack`. Its finalizers delete
the three product Applications and their workloads. The namespace, the
Secrets, and the MySQL volume stay. To delete them also:

```bash
kubectl delete namespace wsc
```

This deletes the MySQL data. Back up the databases first.

To remove all Applications of the root:

```bash
kubectl -n argocd delete application wproofreader-root
```

The child Applications of `shared` have no finalizers. Thus, cert-manager,
Traefik, and the Gateway API CRDs stay in the cluster. Remove them manually
if you do not need them.
