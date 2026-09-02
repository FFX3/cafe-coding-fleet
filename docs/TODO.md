# TODO

## Consolidate to yq

Add `yq-go` to flake.nix runtimeDeps and use it consistently across all deploy scripts for YAML/HCL parsing instead of grep/awk/sed.

Why yq over grep/awk:
- Proper YAML parsing (handles multiline strings, quoted values with colons, anchors/aliases)
- jq-compatible syntax for querying
- Clean nested access: `.spec.template.spec.containers[0].image` vs chained greps
- In-place editing: `yq -i '.replicas = 3' deployment.yaml`
- Supports YAML, JSON, HCL, TOML with same query syntax (useful since we have both k8s manifests and terraform)

Scripts currently using yq:
- deploy-conduit.sh
- deploy-email.sh
- deploy-platform-services.sh
- deploy-hermes.sh
- deploy-passbolt.sh
- deploy-studio.sh
- deploy-test-apps.sh
- deploy-twenty.sh
- deploy-webstudio.sh
- internal/setup-databases.sh
- internal/setup-domains.sh
