# Project Memory

This is the durable status log for the portfolio. Record confirmed facts, not
assumptions. Update it after a meaningful milestone, decision, blocker, or
teardown.

## Current status

**Last reviewed:** 2026-08-24  
**Roadmap position:** Phase 0 complete. Phase 1 (VNet/subnets/NSGs) mid-way in `terraform/dev` — subnets + NSG skeleton built, NSG rules reviewed and need fixes before apply.

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

### Phase 1 progress (2026-08-24, session 2 — unapplied, user to commit/push)
- `terraform/dev/main.tf` now has: VNet `main-vnet` 10.0.0.0/16, three subnets
  (app-subnet 10.0.1.0/24, pe-subnet 10.0.2.0/24, vpn-subnet 10.0.3.0/24),
  one NSG per subnet, each wired via `azurerm_subnet_network_security_group_association`.
- Subnet delegation: NOT used anywhere (correct for now). Concepts covered this session:
  delegation = reserved-floor sign for VNet-injected services (Flexible Server, Container Apps);
  private endpoint = private door to Microsoft-owned PaaS (not needed for VPS DB); private DNS
  deferred until a PE exists. On-prem DB path stays tunnel + UDR, deliberately no PE.
- NSG review findings (user's draft, not yet fixed):
  1. `app-nsg` has an empty `security_rule {}` block → validate fails; must be deleted
     (NSG with zero custom rules is legitimate — default rules already allow VNet traffic).
  2. `vpn-nsg` rule `allowTunnelVPS` uses `Tcp` — WireGuard is **UDP**; also missing
     `direction` (validate fails) and source pinning — should be inbound UDP 51820 from
     the VPS public IP (least privilege).
  3. `pe-nsg` `allowHTTPS` is outbound 443 on the PE side — wrong actor; the PE answers,
     the app initiates. Rule belongs inbound on pe-subnet (or outbound on app-nsg).
  4. Tag inconsistency: only pe-nsg has tags. `terraform fmt` pending.
- `terraform validate` (provider ~>3.0.2) confirms failures 1 and 2.
- User's correct takeaways this session: "default-deny mindset" = write explicit allows
  above Azure's 65500 default denies; empty NSG fine for Phase 1; explicit rules are
  currently redundant with defaults (README must say this honestly).
- Work insight: user's "flexible server SQL" at work required an exclusive subnet —
  consistent with VNet-injected service needing a delegated subnet. Exact product
  (PG/MySQL Flexible Server vs SQL MI vs SQL DB) still unconfirmed.

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

Resume Phase 1, session 2 of 2026-08-24 (user said "we'll continue later" after
committing/pushing):
1. Fix the three NSG findings above (delete empty rule block, UDP 51820 inbound
   from VPS public IP, pe rule direction/actor). Then `fmt` → `plan` → `apply`.
2. Apply, then Network Watcher → Effective security rules per subnet;
   screenshot the custom-rules-over-defaults stack.
3. Phase 1 deliverable: diagram + README with a "who initiates / who answers"
   rule table explaining why each subnet/NSG rule exists (and why NSGs are
   rule-minimal in Phase 1). Review before moving to Phase 2.
4. PE + private DNS on the storage account = later phase (cheap teaching
   exercise, destroyed after; beware locking Terraform state backend if public
   access gets disabled).

AZ-104 mapping so far: NSG rule priority/evaluation, default security rules,
statefulness, service tags; subnet delegation for VNet-injected services.

Deferred (revisit in Phase 3): shared-key access on state storage, SP blob
data role, Entra/RBAC backend — least privilege pass.

Import ID note: `azurerm_storage_container` imports by the blob URL
(`https://commonsaportfolio.blob.core.windows.net/common`), not the ARM
resource-manager path.
