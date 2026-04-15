# Agent-style workflows (TDI)

This repo does not run separate review bots on GitHub. Quality is enforced by:

1. **Cursor rules** — `.cursor/rules/tdi-infra-review.mdc` applies when you work under `infrastructure/`, `iterations/`, or `.github/workflows/`. Ask the assistant to apply that checklist before merging, or @-mention the rule if your client supports it.
2. **GitHub Actions** — `.github/workflows/tdi-quality.yml` runs Terraform fmt/validate and shellcheck on relevant paths for PRs to `main`.
3. **Live TDI** — After `terraform apply`, run the iteration `verify.sh` from `infrastructure/terraform/azure` or `infrastructure/terraform/hetzner` (or set `TERRAFORM_DIR`) as described in [auto_deploy_iterations.md](auto_deploy_iterations.md).

Merge criteria: CI green + iteration `verify.sh` exit 0 + your review.
