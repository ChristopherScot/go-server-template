#!/usr/bin/env bash
# Turn this template into a real service.
#
#   ./scripts/init.sh <name> [--namespace NS] [--host HOST] [--monorepo]
#
# Standalone (default): run inside a fresh clone of the template. Rewrites
# this repo in place for <name>.
#
# Monorepo (--monorepo): run from the monorepo root. Creates
# services/<name>/ with its own go.mod, so each service is an independent
# module and `go build ./services/<name>` works.
#
# Either way you get: a Go service that builds, a deploy/ folder whose
# kustomization image-updater can write to, and CI that pushes an image
# using only GITHUB_TOKEN - no homelab credential in the repo.
set -euo pipefail

OWNER="${GHCR_OWNER:-christopherscot}"
name=""; ns=""; host=""; monorepo=0

while [ $# -gt 0 ]; do
  case "$1" in
    --namespace) ns="$2"; shift 2 ;;
    --host)      host="$2"; shift 2 ;;
    --monorepo)  monorepo=1; shift ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    -*)          echo "unknown flag: $1" >&2; exit 1 ;;
    *)           name="$1"; shift ;;
  esac
done

[ -n "$name" ] || { echo "usage: $0 <name> [--namespace NS] [--host HOST] [--monorepo]" >&2; exit 1; }
echo "$name" | grep -Eq '^[a-z][a-z0-9-]{1,38}[a-z0-9]$' || {
  echo "name must be a DNS label: lowercase letters, digits, hyphens" >&2; exit 1; }
ns="${ns:-$name}"

src="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$monorepo" -eq 1 ]; then
  dest="services/$name"
  [ -e "$dest" ] && { echo "$dest already exists" >&2; exit 1; }
  mkdir -p "$dest"
  # Copy the service, not the template's own git or CI - a monorepo has one
  # workflow covering every service (see .github/workflows in the monorepo
  # example), not one per folder.
  tar -C "$src" --exclude .git --exclude .github --exclude bin -cf - . | tar -C "$dest" -xf -
  rm -rf "$dest/scripts/init.sh"
  image="ghcr.io/$OWNER/$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo monorepo)")-$name"
else
  dest="."
  image="ghcr.io/$OWNER/$name"
fi

cd "$dest"

# go.mod per service, so each is an independent module in either topology.
mod="github.com/$OWNER/$name"
[ "$monorepo" -eq 1 ] && mod="$(head -1 "$src/go.mod" | awk '{print $2}' | sed "s|/[^/]*$|/$name|")"
sed -i.bak "s|^module .*|module $mod|" go.mod && rm -f go.mod.bak

# deploy manifests
for f in deploy/*.yaml; do
  sed -i.bak "s|ghcr.io/christopherscot/CHANGEME|$image|g; s|CHANGEME|$name|g" "$f" && rm -f "$f.bak"
done
# namespace is separate: it is not always the service name
for f in deploy/*.yaml; do
  sed -i.bak "s|^  namespace: $name$|  namespace: $ns|" "$f" && rm -f "$f.bak"
done

cat > deploy/namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $ns
EOF
sed -i.bak "s|^resources:|resources:\n  - namespace.yaml|" deploy/kustomization.yaml && rm -f deploy/kustomization.yaml.bak

if [ -n "$host" ]; then
  cat > deploy/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $name
  namespace: $ns
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  # "public" is the internet-facing controller; use "external" for LAN-only.
  ingressClassName: public
  tls:
    - hosts: [$host]
      secretName: $name-tls
  rules:
    - host: $host
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $name
                port:
                  number: 80
EOF
  sed -i.bak "s|^  - service.yaml$|  - service.yaml\n  - ingress.yaml|" deploy/kustomization.yaml && rm -f deploy/kustomization.yaml.bak
fi

# The Argo Application, with the annotations image automation needs. Print
# it rather than writing into the homelab repo: this script holds no
# credential for that repo, by design.
cat > /tmp/$name-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $name
  namespace: argocd
  annotations:
    argocd-image-updater.argoproj.io/image-list: $name=$image:latest
    argocd-image-updater.argoproj.io/$name.update-strategy: digest
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/write-back-target: kustomization
    argocd-image-updater.argoproj.io/git-branch: main
spec:
  project: default
  source:
    repoURL: 'https://github.com/$OWNER/homelab'
    targetRevision: HEAD
    path: $name
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: $ns
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true]
EOF

sed -i.bak "s|^# Go Server Template$|# $name|" README.md 2>/dev/null && rm -f README.md.bak

echo
echo "created $name ($image)"
echo
echo "next:"
if [ "$monorepo" -eq 1 ]; then
  echo "  1. git add services/$name && commit"
else
  echo "  1. push this repo to github.com/$OWNER/$name (public, so image-updater"
  echo "     can read the package without a registry credential)"
fi
echo "  2. copy deploy/ into the homelab repo as $name/"
echo "  3. copy /tmp/$name-app.yaml into homelab app-of-apps/apps/$name.yaml"
echo
echo "after that every push to main builds an image and image-updater"
echo "deploys it. no homelab secret lives in this repo."
