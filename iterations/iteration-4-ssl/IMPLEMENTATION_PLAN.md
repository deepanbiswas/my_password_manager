# Iteration 4: Reverse Proxy & SSL — Implementation Plan

**Branch:** `feature/tdi-iteration-4-ssl`  
**Reference:** [auto_deploy_iterations.md](../../auto_deploy_iterations.md#iteration-4-reverse-proxy--ssl-configuration), [plan.md](../../plan.md) (Automated Deployment → Step 3 + DNS)

---

## Automation vs manual (same pattern as iteration 3)

| Aspect | Automated | Manual / local |
|--------|-----------|----------------|
| **Deploy Caddy + TLS config** | **Yes.** Same path as iteration 3: merge to `main` (or run `infrastructure/scripts/deploy-to-vm.sh` with `VM_*` + `DOMAIN`). The pipeline syncs templates and regenerates `caddy/Caddyfile` on the VM; Caddy obtains/renews Let’s Encrypt certs. | Only if you bypass CI and deploy by hand. |
| **DNS** | **Cannot be fully automated from GitHub** for arbitrary domains. Someone must ensure the hostname (custom domain or Azure FQDN) resolves to the VM IP **before** expecting clean LE issuance. | One-time (or change) at your DNS registrar / Azure. |
| **Verification (`verify.sh`)** | **Not** run in `tdi-quality.yml` today (no SSH/Azure secrets in that job). | **You** run `cd infrastructure/terraform && ../../iterations/iteration-4-ssl/verify.sh` after deploy (merge criteria per [AGENTS.md](../../AGENTS.md)). |
| **First HTTPS / cert errors** | N/A | If DNS or port 80/443 is wrong, fix DNS or NSG, redeploy/restart Caddy, then re-run verify. |

**Bottom line:** Implementation is **mostly automated** the same way as iteration 3 (CI + deploy script). What iteration 4 adds is **explicit SSL/TLS/DNS/headers verification** in `verify.sh` (and optional `rollback.sh`), not a separate manual deployment ritual—unless you choose to deploy only from your laptop without CI.

---

## Deliverables

1. **`iterations/iteration-4-ssl/verify.sh`** (executable)  
   Implement the checks listed in [auto_deploy_iterations.md](../../auto_deploy_iterations.md#verification-script-requirements-2) for iteration 4:
   - Source `../common/lib.sh` and `../common/config.sh` (after `verify_terraform_state` / `load_vm_config` pattern from iteration 3).
   - `DOMAIN` / `DOMAIN_NAME` from Terraform outputs.
   - `dig` (or `getent hosts`) — DNS for `DOMAIN_NAME` resolves to `PUBLIC_IP` (allow Azure FQDN-only setups).
   - VM: Caddyfile exists, contains site block for domain; Caddy container running.
   - Caddy logs — optional grep for ACME success (warn if still provisioning).
   - From the runner machine: `curl`/`openssl s_client` — HTTPS returns 200/301/302; HTTP redirects to HTTPS; TLS 1.2+; HSTS, `X-Frame-Options`, CSP present (warn if CSP optional per doc).

2. **`iterations/iteration-4-ssl/rollback.sh`** (executable)  
   Per doc: warn, confirm, attempt safe revert path for Caddyfile, restart Caddy (document if VM has no git repo in `/opt/vaultwarden`).

3. **Templates (only if verify/spec gaps)**  
   - [Caddyfile.template](../../infrastructure/templates/Caddyfile.template) already sets TLS 1.2/1.3 and security headers.  
   - If [spec.md](../../spec.md) / plan still require **rate limiting** (e.g. 50 req/min), add the appropriate Caddy v2 `rate_limit` (or handler) directive and document in commit message.

4. **CI path filters (if needed)**  
   - `deploy.yml` already watches `infrastructure/**` and `infrastructure/templates/**`. Touching only `iterations/**` may **not** trigger deploy; either include `iterations/**` in deploy paths (separate change) or rely on **manual `deploy-to-vm.sh`** after merging verify scripts-only changes, or fold template tweaks under `infrastructure/templates/`.

5. **Docs**  
   - After verify passes, tick iteration 4 in [plan.md](../../plan.md) TDI block and any iteration-4 success criteria in [auto_deploy_iterations.md](../../auto_deploy_iterations.md) if you maintain checkboxes there.

---

## Suggested implementation order

1. Implement **`verify.sh`** with relaxed DNS (tolerate propagation delays: retry or clear message).
2. Run locally: `shellcheck`, then `verify.sh` against the live VM until exit **0**.
3. Implement **`rollback.sh`** (minimal, safe: no destructive actions without confirmation).
4. Open PR → `main`, ensure **`tdi-quality`** green, **`verify.sh`** exit 0, review, merge.

---

## Merge criteria (reminder)

- CI green (`tdi-quality.yml` + any other required workflows).
- **`../../iterations/iteration-4-ssl/verify.sh`** exit **0** from `infrastructure/terraform`.
- Self/peer review per project rules.
