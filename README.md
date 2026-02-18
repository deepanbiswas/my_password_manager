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

See [`spec.md`](spec.md) for the complete technical specification including:

- System architecture and design
- Infrastructure requirements and cost analysis
- Security specifications
- Backup and disaster recovery procedures
- Deployment automation (IaC and CI/CD)
- Maintenance and operational procedures

## Quick Start

1. Review the [Technical Specification](spec.md)
2. Choose deployment method:
   - **Manual**: Follow Section 3.5.2
   - **Automated**: Use Terraform and CI/CD (Section 3.7)
3. Configure your domain and secrets
4. Deploy and enjoy a maintenance-free password manager!

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

## Contributing

This is a personal project specification. Feel free to fork and adapt for your own use.
