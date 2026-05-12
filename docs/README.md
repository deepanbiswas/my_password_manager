# Documentation Index

This directory contains detailed documentation and guides for the self-hosted password manager setup.

## Documentation Files

### [Automated deployment prerequisites](prerequisites-checklist.md)
- **Common** (GitHub, Terraform, SSH, domain/DNS, Google Drive / Rclone) plus **Azure-only** or **Hetzner-only** sections; aligned with [plan.md](../plan.md) prerequisites
- Verification commands and suggested order

### [Rclone: Google Drive for Vaultwarden backups](rclone-google-drive.md)
- OAuth (e.g. `drive.file`), GCP OAuth client, `rclone config`, `RCLONE_REMOTE_NAME` + `RCLONE_BACKUP_FOLDER` (default `vaultwarden-backups-hetzner/`)

### [Reverse Proxy Comparison](reverse-proxy-comparison.md)
- Why Caddy is recommended vs Nginx
- Feature comparison table
- Complete Nginx configuration (alternative)
- Certbot setup for Nginx
- Migration from Caddy to Nginx

### [Attachments Explained](attachments-explained.md)
- What are attachments and attachment store
- Storage architecture and organization
- Encryption and security details
- Size limits and optimization
- Backup considerations

### [Hetzner automated deployment (TDI)](hetzner-automated-deployment.md)
- Prerequisites, Terraform + CI, then **Iterations 1–7** with steps and `verify.sh` commands; optional Azure cutover

### [Hetzner undeploy / teardown](hetzner-undeploy.md)
- `scripts/undeploy-hetzner.sh`, `terraform destroy`, and manual follow-up (DuckDNS, GitHub secrets, TLS, Terraform Cloud)

### [Azure VM deallocate and start](azure-vm-deallocate-and-start.md)
- Shut down the VM for cost savings (`az vm deallocate`) and start it again (`az vm start`)
- Optional commands using Terraform outputs for resource group and VM name

### [Cost Analysis](cost-analysis.md)
- Detailed Azure cost breakdown
- INR 4,200 monthly credits analysis
- Cost optimization strategies
- Provider comparison table
- Future planning scenarios

### [Maintenance](maintenance/README.md)
- Low-effort ongoing tasks: updates without data loss, security habits, key rotation, budget, restore from Google Drive
- One self-contained guide per topic under `maintenance/`

### [Terraform Guide](terraform-guide.md)
- Complete Terraform infrastructure code
- Cloud-init script details
- Variable explanations
- Step-by-step implementation
- Remote state backend setup

### [CI/CD Pipelines](cicd-pipelines.md)
- GitHub Actions workflow
- Azure DevOps pipeline
- Required secrets configuration
- Deployment automation benefits
- Pipeline best practices

### [Troubleshooting Guide](troubleshooting.md)
- Common issues and solutions
- Emergency procedures
- Debugging steps
- Log locations
- Performance issues

### [Migration Guide](migration-guide.md)
- Step-by-step migration process
- Vendor-specific notes (Azure, AWS, DigitalOcean, Local)
- Migration scenarios
- Pre and post-migration checklists
- Rollback procedures

## Quick Links

- **Main Specification**: [../spec.md](../spec.md)
- **Deployment Checklist**: [../plan.md](../plan.md)
- **Prerequisites (automated deployment)**: [prerequisites-checklist.md](prerequisites-checklist.md)
- **Configuration Template**: [../.env.example](../.env.example)

## Documentation Purpose

These documents provide detailed information that complements the main specification (`spec.md`). The specification focuses on essential, actionable content, while these documents provide:

- Detailed explanations and comparisons
- Alternative configurations
- Implementation guides
- Troubleshooting procedures
- Migration strategies

## Contributing

When updating documentation:
1. Keep detailed guides in this `docs/` folder
2. Update main `spec.md` with brief references and links
3. Maintain consistency across all documentation
4. Test procedures before documenting
