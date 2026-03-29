# Resume VM after a cost-saving pause

**Paused:** 2026-03-27 — `vm-password-manager` was **deallocated** (not deleted). Terraform state and Azure resources are unchanged; disks and networking remain.

## Start the VM tomorrow

```bash
az vm start --resource-group rg-password-manager-production --name vm-password-manager
```

Wait until the instance reports **VM running**, then SSH and run iteration checks as usual (e.g. `verify.sh` from `infrastructure/terraform` per `auto_deploy_iterations.md`).

## What was stopped vs what still costs

| Action | Effect |
|--------|--------|
| **Deallocated** | VM compute (size) billing stops while stopped. |
| **Still billed** | Managed OS disk, public IP (if Standard/static), VNet/NSG/NIC (usually small vs compute). |

No resources were removed; **do not** run `terraform destroy` if you want the same infrastructure.
