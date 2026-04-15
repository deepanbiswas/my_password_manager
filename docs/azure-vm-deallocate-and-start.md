# Azure VM: deallocate (cost-saving shutdown) and start

Use this when you want to **stop compute billing** for the Vaultwarden VM (e.g. overnight or while away) without destroying infrastructure. Terraform state and Azure resources stay as-is; disks and networking remain.

**Default names in this project** (adjust if you changed them in Terraform):

| Setting | Example value |
|---------|-----------------|
| Resource group | `rg-password-manager-production` |
| VM name | `vm-password-manager` |

## Shut down the VM (deallocate)

**Prefer `deallocate`** for cost savings: the VM releases its compute resources. A plain `az vm stop` can leave the VM in a **stopped** state that may still incur compute charges depending on SKU and policy—use **deallocate** for the same “power off” effect this guide assumes.

### Using fixed names

```bash
az vm deallocate \
  --resource-group rg-password-manager-production \
  --name vm-password-manager
```

### Using Terraform outputs (from repo root)

```bash
cd infrastructure/terraform/azure
az vm deallocate \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --name "$(terraform output -raw vm_name)"
```

Wait until the VM shows **VM deallocated** (or **PowerState/deallocated**) in the portal or:

```bash
az vm get-instance-view \
  --resource-group rg-password-manager-production \
  --name vm-password-manager \
  --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv
```

## Start the VM again

```bash
az vm start \
  --resource-group rg-password-manager-production \
  --name vm-password-manager
```

Or with Terraform outputs:

```bash
cd infrastructure/terraform/azure
az vm start \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --name "$(terraform output -raw vm_name)"
```

Wait until the instance reports **VM running**, then SSH and run your usual checks (e.g. iteration `verify.sh` from `infrastructure/terraform/azure` per `auto_deploy_iterations.md`).

## What stops billing vs what still costs

| Action | Effect |
|--------|--------|
| **Deallocated** | VM compute (size) billing stops while stopped. |
| **Still billed** | Managed OS disk, public IP (if Standard/static), VNet/NSG/NIC (usually small vs compute). |

No resources are removed by deallocate/start; **do not** run `terraform destroy` if you want to keep the same infrastructure.

## See also

- [Cost analysis](cost-analysis.md) — credits and optimization context
