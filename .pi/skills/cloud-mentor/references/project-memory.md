# Project Memory

This is the durable status log for the portfolio. Record confirmed facts, not
assumptions. Update it after a meaningful milestone, decision, blocker, or
teardown.

## Current status

**Last reviewed:** 2026-08-15  
**Roadmap position:** Phase 0 complete. Phase 1 (VNet/subnets/NSGs) starting in `terraform/dev`.

### Evidence in the repository
- `terraform/main.tf` has a minimal AzureRM provider and resource-group
  configuration. It still needs a supplied `resource_group_name` value and
  has no remote-state backend.
- `docs/tutorials/vps-ssh-hardening.md` documents SSH hardening, UFW,
  fail2ban, and a 2 GB swapfile.
- `brainstorming.md` is a learning draft, not an approved implementation
  plan.

### Confirmed outside the repository
- VPS setup is complete and a successful SSH connection was verified on
  2026-08-04.
- `CommonRG` and storage account `commonsaportfolio` exist in West Europe
  (created by the earlier single-root apply).
- A monthly subscription budget is set to $10, with email alerts at 50%
  and 95%. Budget ceiling is confirmed.
- The Terraform service principal has `Contributor` at subscription scope,
  and does not yet hold Storage Blob data roles. This is the accepted
  temporary choice while the subscription remains empty and dedicated to
  the portfolio; revisit least privilege in Phase 3.

### Confirmed structure
- Split into two Terraform roots: `terraform/bootstrap` (persistent
  CommonRG/storage/container) and `terraform/dev` (disposable workload,
  empty, backend key `terraform/dev.tfstate`). Both initialise against
  `commonsaportfolio` / `common`.
- `bootstrap` owns all 3 persistent resources in remote backend state
  (imported: RG and storage by ARM path, container by blob URL
  `https://commonsaportfolio.blob.core.windows.net/common`). Its plan is
  clean (no changes) and validates; `dev` plan is clean/empty.
- `terraform fmt` passes on both roots.
- `.gitignore` tightened: removes blanket `.*` so `.terraform.lock.hcl`
  files are committable; keeps `.terraform/`, `*.tfstate*`, `.env`, `.pi/`
  ignored.

### Phase 0 verification (confirmed 2026-08-15)
- `allowBlobPublicAccess: false` on the state storage account.
- SP still holds only `Contributor` at subscription scope (no blob data
  role); `allowSharedKeyAccess: true`. Both accepted as temporary; revisit
  in Phase 3 (least privilege) — RBAC/Entra backend deferral noted.

### SP / app auth exercise (done 2026-08-15, learning artifacts)
- Built app-a (client) -> app-b (API) app registrations; wrote and decoded a
  client_credentials JWT from scratch.
- Key finding: for client_credentials (app-as-self, no user), the correct
  Entra permission type is an **app role** (`roles` claim), not an OAuth
  **scope** (`scp`, delegated/user). A scope declared+consented but used in a
  client_credentials flow yields neither `roles` nor `scp`.
- app-b has app role `portfolio_read` (id `1a906288-...`) granted to app-a's
  SP; token shows `roles: ["portfolio_read"]`.
- Lesson documented in `docs/concepts/app-registration-auth-walkthrough.md`
  (scopes vs. app roles section) and `docs/concepts/service-principals-explained.md`.
- Note: app-a secrets were rotated during debugging; any lingering secrets on
  app-a may be removed when no longer needed.

## Core portfolio tools

1. **Terraform** — provision Azure infrastructure and manage remote state.
2. **Ansible** — configure the VPS and Azure WireGuard VM repeatably after
   the manual setup is understood.
3. **Kubernetes** — learn operations on k3s, then demonstrate the managed
   Azure equivalent with a short-lived AKS session.

## Working decisions

- The VPS is the always-on, low-cost on-prem site. Workload Azure resources
  are Terraform-managed and destroyed after sessions; the remote-state
  bootstrap resource group/storage account is the deliberate small exception.
- Use GitHub Actions later for CI/CD. Start with one infrastructure workflow;
  split pipelines only when the repository has a real independent workload.
- Keep environments to `dev` first. Do not create staging/production
  resources, state files, or modules until they represent distinct deployed
  environments.

## Next mentoring checkpoint

Phase 1 in `terraform/dev`: VNet + subnets + NSGs, nothing internet-facing
yet. Learn subnet delegation, NSG evaluation order, service vs. private
endpoint. Use Network Watcher (effective routes/NSG/IP flow verify) to
inspect. Deliverable: diagram + README explaining why each subnet/NSG rule
exists, reviewed before moving on.

Deferred (revisit in Phase 3): shared-key access on state storage, SP blob
data role, Entra/RBAC backend — least privilege pass.

Import ID note: `azurerm_storage_container` imports by the blob URL
(`https://commonsaportfolio.blob.core.windows.net/common`), not the ARM
resource-manager path.
