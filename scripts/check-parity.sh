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
argo_pins=$(grep -oE 'revision: [0-9a-f]{40}|revision: v[0-9.]+' argocd/wproofreader-stack/values.yaml | awk '{print $2}' | sort)
flux_pins=$(grep -oE 'commit: [0-9a-f]{40}|tag: v[0-9.]+' flux/sources/charts.yaml | awk '{print $2}' | sort)
[ "$argo_pins" = "$flux_pins" ] || { echo "DRIFT: chart pins"; echo "argocd: $argo_pins"; echo "flux:   $flux_pins"; rc=1; }
gw_argo=$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' argocd/shared/gateway-api-crds/kustomization.yaml | head -1)
gw_flux=$(grep -oE 'tag: v[0-9.]+' flux/sources/gateway-api.yaml | awk '{print $2}')
[ "$gw_argo" = "$gw_flux" ] || { echo "DRIFT: Gateway API version $gw_argo vs $gw_flux"; rc=1; }
[ $rc -eq 0 ] && echo "parity OK"
exit $rc
