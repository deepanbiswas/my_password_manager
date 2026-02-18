# Self-Hosted Personal Password Manager

A comprehensive technical specification and implementation guide for deploying a secure, maintenance-free, vendor-agnostic password manager solution using Vaultwarden.

## Overview

This repository contains the complete technical specification for a self-hosted password manager that can be deployed on Azure (or any VPS provider) with automated backups, updates, and disaster recovery capabilities.

## Key Features

- **Zero-Knowledge Architecture**: Server never sees plaintext passwords
- **Vendor Agnostic**: Deployable on Azure, AWS, DigitalOcean, or local machines
- **Automated Updates**: Watchtower automatically updates containers
- **Automated Backups**: Nightly encrypted backups to Google Drive
- **One-Command Restore**: Complete disaster recovery in minutes
- **HTTPS Only**: Automatic SSL certificate management via Let's Encrypt
- **Infrastructure as Code**: Terraform configurations for automated deployment
- **CI/CD Ready**: GitHub Actions and Azure DevOps pipeline examples

## Documentation

### Main Documentation

- **[spec.md](spec.md)** - Complete technical specification (essential content)
- **[plan.md](plan.md)** - Deployment execution checklist (quick reference)
- **[.env.example](.env.example)** - Configuration template with all variables

### Detailed Guides

See [docs/README.md](docs/README.md) for detailed guides including:

- Reverse proxy comparison (Caddy vs Nginx)
- Attachments architecture explained
- Detailed cost analysis and optimization
- Terraform implementation guide
- CI/CD pipeline configurations
- Troubleshooting guide
- Migration procedures

## Quick Start

1. Review the [Technical Specification](spec.md)
2. Follow the [Deployment Checklist](plan.md)
3. Copy [.env.example](.env.example) to `.env` and configure
4. Choose deployment method:
   - **Manual**: Follow [plan.md](plan.md) checklist
   - **Automated**: Use [Terraform Guide](docs/terraform-guide.md) and [CI/CD Pipelines](docs/cicd-pipelines.md)
5. Deploy and enjoy a maintenance-free password manager!

## Cost Analysis

- **Recommended Setup**: Standard_B2s VM (2 vCPU, 4 GB RAM)
- **Monthly Cost**: ₹3,000 - ₹4,600 (INR)
- **Azure Credits**: ₹4,500/month covers the recommended setup

## Technology Stack

- **Vaultwarden**: Rust-based Bitwarden-compatible server
- **Docker & Docker Compose**: Container orchestration
- **Caddy/Nginx**: Reverse proxy with automatic SSL
- **Watchtower**: Automated container updates
- **Rclone**: Google Drive backup synchronization
- **Terraform**: Infrastructure as Code
- **GitHub Actions**: CI/CD automation

## Security

- Zero-knowledge encryption (client-side)
- HTTPS-only access
- Automatic SSL certificate renewal
- Encrypted backups
- Minimal attack surface (ports 80/443 only)

## License

This specification is provided as-is for personal use.

## Project Structure

```
my_password_manager/
├── .cursorrules          # AI assistant instructions
├── .env.example          # Configuration template
├── .gitignore
├── plan.md               # Deployment execution checklist
├── README.md             # This file
├── spec.md               # Technical specification
├── scratchpad.md         # Personal notes (gitignored)
└── docs/                 # Detailed documentation
    ├── README.md
    ├── reverse-proxy-comparison.md
    ├── attachments-explained.md
    ├── cost-analysis.md
    ├── terraform-guide.md
    ├── cicd-pipelines.md
    ├── troubleshooting.md
    └── migration-guide.md
```

## Contributing

This is a personal project specification. Feel free to fork and adapt for your own use.
