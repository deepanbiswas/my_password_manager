# Hosting and running cost (stay within budget)

These measures keep spend **predictable and low** for the typical single-VM Azure layout used by this project. Numbers depend on region, SKU, and currency; use this as a checklist, not a quote.

## 1. Right-size the VM

- Start with the **smallest VM that meets** Vaultwarden + Caddy (see [Cost Analysis](../cost-analysis.md) for examples).
- **Scale up** only if you see sustained high CPU or OOM in `docker stats` / logs.

## 2. Stop compute when you do not need 24/7 uptime

If personal use allows **nights or weekends off**, deallocate the VM so you stop paying for compute (disk and public IP may still bill):

- Full procedure: [Azure VM deallocate and start](../azure-vm-deallocate-and-start.md)

You trade cost for **availability**—clients cannot sync while the VM is deallocated.

## 3. Watch disk and backup growth

- **OS + Docker** images grow over time; occasional `docker system prune` (careful: only when you understand what it removes) can free space—do not prune volumes that hold Vaultwarden data.
- **Google Drive**: Backups are small relative to VM disk, but **retention** (`BACKUP_RETENTION_DAYS` in `.env`) caps how many encrypted copies accumulate. Lower retention slightly if you need to stay under a Drive quota.

## 4. Networking

- Avoid unnecessary **egress** (large logs, misconfigured mirrors). Normal Vaultwarden traffic is modest.
- Use a **basic** public IP/SKU if your architecture allows; premium features cost more.

## 5. Monitoring spend (Azure)

- Review **Cost Management + Billing** in the Azure portal monthly.
- If you use credits (e.g. monthly allowance), set a **budget alert** at 80% of expected burn so you can deallocate or resize before overrun.

## 6. Infra-as-code discipline

- Changes to VM size or disk happen in **Terraform** (or a documented manual change reflected in state). Unplanned “click ops” upgrades are a common cause of bill surprises.

## Quick reference

| Lever | Effect |
|-------|--------|
| Smaller VM SKU | Lower hourly compute |
| Deallocate when idle | Near-zero compute while off |
| Retention days | Caps backup storage in Drive |
| Single region, no extras | Fewer billed services |

For deeper scenarios and credit math, see [Cost Analysis](../cost-analysis.md) and the cost notes in [plan.md](../../plan.md).
