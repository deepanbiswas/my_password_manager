# Azure → Hetzner migration (TDI + dual paths)

This document is the **in-repo** copy of the migration plan. Terraform roots: `infrastructure/terraform/azure/` and `infrastructure/terraform/hetzner/`; shared cloud-init: `infrastructure/terraform/shared/scripts/cloud-init.sh`.

## Locked requirements

- **Both deployment paths remain**: Azure and Hetzner Terraform coexist with **separate state**; teardown of Azure is optional (final iteration).
- **Configurable hosting**: GitHub repository variable **`HOSTING_PROVIDER`** = `azure` \| `hetzner` selects which Terraform plan/apply path runs in [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml). If unset, behavior defaults to **`azure`**.
- **GitHub Actions**: Only the matching provider runs (mutually exclusive `if:`). **vm-only** deploy is unchanged when no Terraform CI path runs but VM secrets are set.
- **TDI**: Merge when CI is green and relevant **`verify.sh` exits 0** (see [AGENTS.md](../AGENTS.md)).

## Storing the Hetzner API token

| Context | Storage |
|---------|---------|
| **GitHub Actions** | Repository secret **`HCLOUD_TOKEN`** (Read & Write token from Hetzner Cloud Console → project → Security → API tokens). |
| **Local** | `export HCLOUD_TOKEN='...'` or a **gitignored** file (e.g. direnv); never commit real tokens. |
| **Password manager** | Human copy for rotation / DR. |

See also [CI/CD Pipelines](cicd-pipelines.md#hosting-provider--hetzner).

## Per-iteration Git workflow

For **MH1–MH4** (and doc-only MH6): feature branch → PR → automated checks → code review → merge to `main`. See branch naming in the iterations table below.

## Repository layout

| Area | Path |
|------|------|
| Azure IaC | `infrastructure/terraform/azure/` |
| Hetzner IaC | `infrastructure/terraform/hetzner/` |
| Shared cloud-init | `infrastructure/terraform/shared/scripts/cloud-init.sh` |
| App templates | `infrastructure/templates/` (unchanged) |

## Terraform output contract

TDI scripts ([`iterations/common/lib.sh`](../iterations/common/lib.sh)) expect `vm_public_ip`, `vm_admin_username`, `domain`, and optionally `resource_group_name`, `vm_name`, plus **`cloud_provider`** (`azure` \| `hetzner`).

Run verifies from a Terraform root or set **`TERRAFORM_DIR`**:

```bash
export TERRAFORM_DIR="$PWD/infrastructure/terraform/hetzner"
cd "$TERRAFORM_DIR" && ../../iterations/iteration-1-infrastructure/verify.sh
```

## Migrating existing local Terraform state (Azure)

If you previously ran Terraform from `infrastructure/terraform/` (flat layout):

1. Pull this repo layout.
2. Move state into the Azure root:  
   `mv infrastructure/terraform/terraform.tfstate infrastructure/terraform/azure/terraform.tfstate`  
   (and any `*.tfstate.*` backups as needed).
3. From `infrastructure/terraform/azure/`: `terraform init -upgrade` then `terraform plan` — addresses should match if resources were unchanged.

## Migration iterations (MH1–MH9)

| ID | Deliverable | Git / branch | Verification |
|----|-------------|--------------|----------------|
| **MH1** | Repo reorg + dual roots | `feature/mh1-terraform-reorg` → PR | `tdi-quality` green |
| **MH2** | Hetzner Terraform resources | `feature/mh2-hetzner-terraform` → PR | `terraform plan` in `hetzner/`; optional apply |
| **MH3** | `deploy.yml` + `HOSTING_PROVIDER` + docs | `feature/mh3-deploy-provider-switch` → PR | Correct job skips per provider |
| **MH4** | Verify scripts provider-aware | `feature/mh4-verify-provider-branching` → PR | `iteration-1/verify.sh` exit 0 on target |
| **MH5** | Hetzner prod VM live | Branch if code changes | `iteration-3-services/verify.sh` |
| **MH6** | Data migration | Doc/checklist PR optional | Restore/rsync + smoke tests |
| **MH7** | DNS cutover | Branch if repo changes | `iteration-4` + `iteration-5` verify |
| **MH8** | Set `HOSTING_PROVIDER=hetzner` in GitHub **Variables** | UI + doc PR | CI uses Hetzner path |
| **MH9** | Optional Azure teardown | PR if removing Azure from CI | `terraform destroy` in `azure/` |

## Risks

- **Two state files**: Always run `terraform` from `azure/` or `hetzner/` intentionally.
- **`terraform validate` for hcloud** may require a token at init; CI uses a placeholder where possible.

## Hetzner implementation notes

- Provider: `hetznercloud/hcloud`; token via **`HCLOUD_TOKEN`** only.
- Default image: Ubuntu 22.04; default SSH user on Hetzner images is typically **`root`** (see `hetzner/variables.tf`).
- Firewall: inbound 22, 80, 443; restrict **`ssh_allowed_cidr`** when you know your admin IP.
