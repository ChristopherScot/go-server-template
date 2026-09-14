# Go Server Template

Scaffolds a Go service that builds an image on every push and deploys
itself, with **no homelab credential in the service repo**.

## Quick start

```sh
# standalone repo
gh repo create myservice --public --template ChristopherScot/go-server-template
git clone .../myservice && cd myservice
./scripts/init.sh myservice --host myservice.chrisscotmartin.com

# or as a folder in a monorepo
./scripts/init.sh myservice --monorepo
```

Then follow the three steps it prints.

## How deployment works

```
push to main
  -> GitHub Actions builds + pushes ghcr.io/<owner>/<name>:latest
  -> argocd-image-updater (in-cluster) sees the new digest
  -> commits it to the homelab repo
  -> ArgoCD syncs -> new pod
```

The service repo's CI only needs `GITHUB_TOKEN`, which Actions issues per
run. The credential that can write the homelab repo lives **in the
cluster** — a Vault-backed, fine-grained PAT scoped to `contents:write` on
that one repo, projected by External Secrets. Nothing to store here, one
place to rotate.

An earlier design had each service's CI clone the homelab repo and push
manifests, which meant a long-lived `CI_PAT` in every service repo. That is
what this avoids.

## Things that bite, and why the template does what it does

**`deploy/kustomization.yaml` is required.** argocd-image-updater can only
write image bumps into Kustomize, Helm or Plugin sources. Without it Argo
classifies the app as `Directory`, the updater skips it with only a log
warning, and the app sits `Synced/Healthy` on a stale image while new
builds pile up. `scripts/check-deploy.sh` fails the build if it is missing.

**The image tag must be a full 40-char SHA.** Abbreviated SHAs are not real
registry tags and give `ImagePullBackOff`. The check script rejects them.

**The package must be readable by image-updater.** Public is simplest and
needs no registry credential. A private package requires giving the updater
a GHCR credential it does not have by default — the failure mode is
`Could not get tags from registry: unauthorized` in the updater's log, and
nowhere else.

**The Dockerfile's nonroot user matches the deployment's securityContext.**
Change one and the pod cannot exec its binary: `permission denied`, no
logs.

**`CGO_ENABLED=0`** in both the Makefile and CI. With cgo on, the binary
links against glibc and will not run on alpine.

## Layout

```
main.go, main_test.go, go.mod   one module per service
Dockerfile                      nonroot 65532
Makefile                        build / run / test
deploy/                         kustomization + manifests
scripts/init.sh                 scaffold a service
scripts/check-deploy.sh         CI guard against silent deploy failures
```
