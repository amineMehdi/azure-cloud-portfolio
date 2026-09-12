# Project Memory

This is the durable status log for the portfolio. Record confirmed facts, not
assumptions. Update it after a meaningful milestone, decision, blocker, or
teardown.

## Current status

**Last reviewed:** 2026-09-12  
**Roadmap position:** Phase 1 (VNet/subnets/NSGs) — code complete for 3 subnets
+ 3 NSGs, RG imported. **Nothing applied yet**; one blocker stands between the
config and a clean apply (RG name casing, below).

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

### Phase 1 progress (started 2026-08-24; re-verified 2026-09-12)
- `terraform/dev/main.tf` (122 lines) has: VNet `main-vnet` 10.0.0.0/16, three
  subnets (app-subnet 10.0.1.0/24, pe-subnet 10.0.2.0/24, vpn-subnet
  10.0.3.0/24), one NSG per subnet, each wired via
  `azurerm_subnet_network_security_group_association`.
- Subnet delegation: NOT used anywhere (correct for now). Concepts covered:
  delegation = reserved-floor sign for VNet-injected services (Flexible Server, Container Apps);
  private endpoint = private door to Microsoft-owned PaaS (not needed for VPS DB); private DNS
  deferred until a PE exists. On-prem DB path stays tunnel + UDR, deliberately no PE.
- **Blocker (found 2026-09-12):** `RG-DEV` was imported into `dev` state, so
  its stored name is `RG-DEV` while the config default is `RG-Dev`. Terraform
  plans **must be replaced** (destroy + recreate) — an apply would delete the
  imported RG. Fix: match the config to Azure's casing (`RG-DEV`); Azure RG
  names are case-insensitive but case-preserving, and Terraform compares
  literally.
- `terraform validate` passes. `terraform plan` = **11 to add, 0 change,
  1 destroy** (the RG replace). Nothing exists in Azure yet: no VNet, no
  subnet, no NSG.
- Provider cache and both lock files were lost by a `git pull`; `terraform
  init` re-created `terraform/dev/.terraform.lock.hcl` (azurerm 3.0.2).
  Lock files are not gitignored but are **untracked** — commit them.
  `bootstrap` still needs `init`.
- NSG review findings, status at 2026-09-12:
  1. `app-nsg` empty `security_rule {}` block — **fixed** (block removed; a
     zero-rule NSG is legitimate).
  2. `vpn-nsg` `allowTunnelVPS`: `direction` now present — **fixed**. Still
     wrong: `protocol = "Tcp"` (WireGuard is UDP 51820), `direction =
     "Outbound"` with `source_address_prefix = "10.2.3.4"` (an address that
     isn't in the VNet space, used as *source* on an outbound rule) → the rule
     can never match. Both custom rules are also redundant: default rule 65001
     already allows all outbound Internet traffic. The rule that matters is
     **inbound** UDP 51820 from the VPS public IP (default 65500 denies).
  3. `pe-nsg` `allowHTTPS` — still wrong: outbound, protocol `Udp` on port 443
     (HTTPS is TCP), and wrong actor (the PE answers, the app initiates).
  4. Tag inconsistency (only `pe-nsg` tagged) and `terraform fmt` — untouched.
  5. `pe-subnet` lacks `enforce_private_link_endpoint_network_policies = true`
     (3.x arg, default false): without it the subnet NSG/UDR is ignored by any
     private endpoint NIC. Needed when the PE actually lands.
- NSG rules in Phase 1 are deliberately rule-minimal: `AllowVnetInBound`
  (65000) already permits all subnet-to-subnet traffic, so isolation requires
  an explicit Deny for `VirtualNetwork` at a priority below 65000 — the README
  must state this honestly instead of implying the rules do something.
- User's correct takeaway: "default-deny mindset" = write explicit allows
  above Azure's 65500 default denies; an empty NSG is fine for Phase 1.
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

Phase 1 close-out, in order:
1. Fix the RG name casing (`RG-Dev` → `RG-DEV`) so plan stops proposing a
   destroy/recreate; then `fmt` → `plan` (expect 11 adds, 0 destroys).
2. Fix the two NSG rules: vpn-nsg → inbound UDP 51820 from the VPS public IP;
   pe-nsg → drop it (or move the allow to where the initiating actor lives).
   Add `enforce_private_link_endpoint_network_policies = true` on pe-subnet.
3. Apply. Verify with `az network nsg rule list` + Network Watcher
   `show-topology` (effective rules / IP flow verify need a NIC — Phase 2).
4. Phase 1 deliverable: diagram + README with a "who initiates / who answers"
   rule table explaining why each subnet/NSG rule exists (and why NSGs are
   rule-minimal in Phase 1). Review before moving to Phase 2.
5. Commit `.terraform.lock.hcl` for both roots.
6. PE + private DNS on a *separate* storage account = later phase (cheap
   teaching exercise, destroyed after; never on the Terraform state backend —
   disabling public access there locks Terraform out of its own state).

AZ-104 mapping so far: NSG rule priority/evaluation, default security rules,
statefulness, service tags; subnet delegation for VNet-injected services.

Deferred (revisit in Phase 3): shared-key access on state storage, SP blob
data role, Entra/RBAC backend — least privilege pass.

Import ID note: `azurerm_storage_container` imports by the blob URL
(`https://commonsaportfolio.blob.core.windows.net/common`), not the ARM
resource-manager path.
