#!/usr/bin/env bash
# Fails the build on the deploy misconfigurations that otherwise fail
# silently - the app stays Synced/Healthy while nothing ships.
set -euo pipefail

d="${1:-deploy}"
fail=0
err() { echo "ERROR: $*" >&2; fail=1; }

[ -d "$d" ] || { err "no $d/ directory"; exit 1; }

# Without this, argocd-image-updater skips the app entirely: it can only
# write image bumps into Kustomize/Helm/Plugin sources, and a plain
# directory gives it nowhere to write.
[ -f "$d/kustomization.yaml" ] || err "$d/kustomization.yaml is missing - image-updater will silently skip this app"

# The field the updater rewrites. Without it there is nothing to bump.
grep -q '^images:' "$d/kustomization.yaml" 2>/dev/null || err "$d/kustomization.yaml has no 'images:' block for image-updater to write"

grep -rq 'CHANGEME' "$d" 2>/dev/null && err "$d still contains CHANGEME placeholders"

# An abbreviated SHA is not a real registry tag; it yields ImagePullBackOff.
if grep -rnE 'image:.*:[0-9a-f]{7,12}([^0-9a-f]|$)' "$d" 2>/dev/null | grep -v '@sha256:'; then
  err "image tag looks like an abbreviated SHA - registry tags are full 40-char SHAs"
fi

[ "$fail" -eq 0 ] && echo "deploy manifests OK"
exit "$fail"
