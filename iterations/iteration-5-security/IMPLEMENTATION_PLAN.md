# Iteration 5: Security Hardening — Implementation Plan

**Branch:** `feature/tdi-iteration-5-security`  
**Reference:** [auto_deploy_iterations.md](../../auto_deploy_iterations.md#iteration-5-security-hardening), [plan.md — Step 4 & Post-Deployment Verification](../../plan.md#step-4-verification--cost-monitoring)

---

## Objective

Confirm the two-phase signup flow (enable signups → create account → **disable signups**), validate host and edge hardening (UFW, rate limits, compose limits, `.env`, non-root Vaultwarden, TLS settings in Caddy), and ship **`verify.sh`** / **`rollback.sh`** per the TDI doc.

---

## Automation vs manual

| Aspect | Automated | Manual / local |
|--------|-----------|----------------|
| **Config on the VM** | Same as prior iterations: merge to `main` and let **`deploy.yml`** run, or run **`infrastructure/scripts/deploy-to-vm.sh`** with `VM_*` and `DOMAIN`. | Template edits (e.g. Caddy rate limit) must be **deployed** before `verify.sh` can pass. |
| **Create Vaultwarden user & turn off signups** | Not fully automatable from a script without API tokens and vault access. | **You** create the first account in the web UI, then set **`SIGNUPS_ALLOWED=false`** in **`.env`** and **`docker-compose.yml`** (or redeploy from updated template), and restart Vaultwarden — or follow the **interactive prompts** in `verify.sh` as specified under **Iteration 5** in [auto_deploy_iterations.md](../../auto_deploy_iterations.md#iteration-5-security-hardening). |
| **`verify.sh`** | **Not** run in **`tdi-quality.yml`** (no SSH to the VM). | Run from **`infrastructure/terraform`**: `../../iterations/iteration-5-security/verify.sh`. Expect at least one **interactive** step (confirm account created + signups disabled). |
| **`rollback.sh`** | N/A | Run locally when you need to **re-enable signups** for recovery (see doc). |

---

## Prerequisites (before coding `verify.sh`)

1. **Iterations 1–4 complete** — VM reachable, HTTPS OK, iteration 4 `verify.sh` passes.
2. **Rate limiting** — [Caddyfile.template](../../infrastructure/templates/Caddyfile.template) currently has **no** `rate_limit` block; [spec.md](../../spec.md) / [plan.md](../../plan.md) call for limits (e.g. ~50 requests/minute per IP). **Add** the appropriate **Caddy v2** rate-limit configuration (built-in or module, matching the Caddy version in compose), **deploy**, then assert it in `verify.sh`.
3. **UFW vs doc wording** — [auto_deploy_iterations.md](../../auto_deploy_iterations.md) says “only ports 80/443”; **`cloud-init.sh`** also allows **22/tcp** for SSH. Implement `verify.sh` to expect **UFW active** and inbound **22, 80, 443** (adjust the auto_deploy wording in a small doc fix if you want strict alignment).

---

## Deliverables

1. **`iterations/iteration-5-security/verify.sh`** (executable)  
   Follow the **Verification Script Requirements** bullet list under **Iteration 5** in [auto_deploy_iterations.md](../../auto_deploy_iterations.md#iteration-5-security-hardening):
   - Source **`../common/lib.sh`** and **`../common/config.sh`** after `verify_terraform_state`.
   - Assert **`DOMAIN` / `DOMAIN_NAME`**.
   - **Phase A (automated checks):** `SIGNUPS_ALLOWED=true` in **`docker-compose.yml`** on the VM *before* the user disables signups (or document order: first run checks pre-requisites, then manual phase — see below).
   - **Interactive block:** Print clear steps: open `https://…`, create account, set **`SIGNUPS_ALLOWED=false`** in `.env` and in **`docker-compose.yml`** (if your workflow duplicates it), `docker compose up -d` / restart Vaultwarden; **`read -r`** to continue.
   - **Phase B:** `SIGNUPS_ALLOWED=false`, curl signup/API returns **400/403/404** as appropriate.
   - **UFW:** `ufw status` — active; rules include **22, 80, 443** (see Prerequisites).
   - **Caddyfile:** rate limiting present (string match or structured check).
   - **`docker-compose.yml`:** `deploy.resources.limits` present for services (already in template).
   - **`.env`:** mode **600**; Vaultwarden container user **1000:1000**; optional TLS stanza warning in Caddyfile.

   **Design choice:** Either require **`SIGNUPS_ALLOWED=true`** on first run and fail iteration 5 until the operator completes the manual step, or split into **`verify.sh --phase=pre|post`** — keep it simple and match the TDI doc (single script + prompt).

2. **`iterations/iteration-5-security/rollback.sh`** (executable)  
   Per the **Rollback Script Requirements** under **Iteration 5** in [auto_deploy_iterations.md](../../auto_deploy_iterations.md#iteration-5-security-hardening): warn, confirm **`yes`**, set **`SIGNUPS_ALLOWED=true`** in **`.env`** and **`docker-compose.yml`** on the VM (via `sed` or heredoc over SSH), restart Vaultwarden.

3. **Template / infra tweaks (as needed)**  
   - **[Caddyfile.template](../../infrastructure/templates/Caddyfile.template)** — add **rate limiting** consistent with Caddy version in [docker-compose.yml.template](../../infrastructure/templates/docker-compose.yml.template).  
   - Optionally **`deploy.yml`** path filters** — if you only touch `iterations/**`, add **`iterations/**`** to deploy paths or run **`deploy-to-vm.sh`** manually after template changes.

4. **Docs after green verify**  
   - **[auto_deploy_iterations.md](../../auto_deploy_iterations.md)** — Success Criteria checkboxes for iteration 5.  
   - **[AGENTS.md](../../AGENTS.md)** — merge = CI green + **`verify.sh`** exit **0** + review.

5. **Update [plan.md](../../plan.md) (tick completed work for this iteration)**  
   After **`verify.sh`** exits **0**, edit **`plan.md`** in the same feature branch (or a follow-up commit before merge) and **check off** every item that iteration 5 actually completes, for example:
   - **TDI progress** — set **Iteration 5 — Security hardening** to **`[X]`** and reference **`iterations/iteration-5-security/verify.sh`** (mirror the style used for iterations 3–4).
   - **Automated Deployment → Step 4** — add or tick a line for **TDI iteration 5** verification if you introduce one (same pattern as iteration 4’s SSL line).
   - **Common Configuration Steps → [Post-Deployment Verification](../../plan.md#post-deployment-verification)** — tick items now satisfied (e.g. first user account, **disable public signups**, signup page blocked, optional client/WebSocket checks if you performed them as part of the manual phase).
   - Any other **`[ ]`** rows in **`plan.md`** that iteration 5 explicitly covers (UFW/rate limits/signups) — tick or annotate *“covered by iteration 5 `verify.sh`”* so the guide matches reality.

   Treat **`plan.md`** updates as **part of the iteration deliverable**, not an optional follow-up.

---

## Suggested implementation order

1. Add **rate limiting** to `Caddyfile.template`; deploy to VM; confirm Caddy reloads.
2. Implement **`verify.sh`** (interactive flow + SSH checks); **`shellcheck`** clean.
3. Implement **`rollback.sh`**.
4. Run **`../../iterations/iteration-5-security/verify.sh`** from **`infrastructure/terraform`** until exit **0**.
5. **Update `plan.md`** (and **`auto_deploy_iterations.md`** iteration 5 success criteria) by ticking completed items as in **Deliverable 5** above.
6. Open PR → **`main`**, wait for **`tdi-quality`**, merge.

---

## Merge criteria

- **`tdi-quality.yml`** green on the PR.
- **`../../iterations/iteration-5-security/verify.sh`** exits **0** (from `infrastructure/terraform`) after the manual signup step.
- **`plan.md`** updated with iteration 5 items ticked (see **Deliverable 5**).
- Review against [`.cursor/rules`](../../.cursor/rules) if you use TDI infra review for `infrastructure/` changes.

---

## Status

**Implemented:** Custom Caddy Dockerfile (`mholt/caddy-ratelimit`), template updates, `deploy-to-vm.sh` syncs `infrastructure/docker/caddy`, `verify.sh` / `rollback.sh`, and **`plan.md`** / **`auto_deploy_iterations.md`** ticked per Deliverable 5. Run `verify.sh` from `infrastructure/terraform` after deploying to the VM (first Caddy **build** can take several minutes).
