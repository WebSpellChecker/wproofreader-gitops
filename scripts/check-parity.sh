#!/usr/bin/env bash
# The argocd/ and flux/ trees are deliberately self-contained, so the values files and the
# pinned chart revisions exist twice. This script fails when they drift apart.
set -euo pipefail
cd "$(dirname "$0")/.."
rc=0
for f in mysql wproofreader-app admin-panel; do
  # comments may name the tool; compare everything else
  if ! diff -u <(grep -v '^[[:space:]]*#' "argocd/environments/demo/$f.yaml" | sed 's/#.*//') \
               <(grep -v '^[[:space:]]*#' "flux/environments/demo/values/$f.yaml" | sed 's/#.*//'); then
    echo "DRIFT: environments/demo/$f.yaml"; rc=1; fi
done
for f in cert-manager traefik; do
  diff -u "argocd/shared/$f/values.yaml" "flux/shared/$f/values.yaml" || { echo "DRIFT: shared/$f/values.yaml"; rc=1; }
done
diff -u argocd/shared/cluster-resources/clusterissuer.yaml flux/shared/cluster-resources/clusterissuer.yaml || { echo "DRIFT: cluster-resources"; rc=1; }
# chart pins as <repository>=<tag or commit>, so a tag swapped between charts is drift too
argo_pins=$(awk '/^charts:/{c=1} c && /repoURL:/{r=$2; sub(/.*\//, "", r)} c && /revision:/{print r "=" $2}' \
  argocd/wproofreader-stack/values.yaml | sort)
flux_pins=$(awk '/url:/{r=$2; sub(/.*\//, "", r)} /^ +(tag|commit):/{print r "=" $2}' flux/sources/charts.yaml |
  grep -v '^gateway-api=' | sort || true)
[ "$argo_pins" = "$flux_pins" ] || { echo "DRIFT: chart pins"; echo "argocd: $argo_pins"; echo "flux:   $flux_pins"; rc=1; }
# chart directory in each chart repository (Argo CD path: / Flux chart:)
for f in mysql wproofreader-app admin-panel; do
  argo_path=$(awk '/^ +path:/{print $2; exit}' "argocd/wproofreader-stack/templates/$f.yaml")
  flux_path=$(awk '/^ +chart: \.\//{print $2; exit}' "flux/environments/demo/$f.yaml")
  [ "$argo_path" = "${flux_path#./}" ] || { echo "DRIFT: chart path of $f: $argo_path vs $flux_path"; rc=1; }
done
gw_argo=$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' argocd/shared/gateway-api-crds/kustomization.yaml | head -1)
gw_flux=$(grep -oE 'tag: v[0-9.]+' flux/sources/gateway-api.yaml | awk '{print $2}')
[ "$gw_argo" = "$gw_flux" ] || { echo "DRIFT: Gateway API version $gw_argo vs $gw_flux"; rc=1; }
[ $rc -eq 0 ] && echo "parity OK"
exit $rc
