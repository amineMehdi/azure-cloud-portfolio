# Project Memory

This is the durable status log for the portfolio. Record confirmed facts, not
assumptions. Update it after a meaningful milestone, decision, blocker, or
teardown.

## Current status

**Last reviewed:** 2026-09-13  
**Roadmap position:** Phase 1 complete. VNet, three subnets, three NSGs,
associations, documentation, and Azure deployment are confirmed. Ready to
discuss Phase 2 design before implementation.

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

### Phase 1 progress (started 2026-08-24; completed 2026-09-13)
- `terraform/dev/main.tf` provisions `main-vnet` (`10.0.0.0/16`), three
  subnets (`app-subnet` `10.0.1.0/24`, `pe-subnet` `10.0.2.0/24`,
  `vpn-subnet` `10.0.3.0/24`), three NSGs, and one subnet/NSG association per
  subnet.
- Terraform plan completed with **10 to add, 0 change, 0 destroy**. Apply
  completed successfully on 2026-09-13.
- Azure verification confirmed the VNet address space, all three subnets, and
  all three NSG associations. A subsequent `terraform plan -detailed-exitcode`
  reported no changes.
- NSGs intentionally contain no custom rules yet. Azure default rules remain;
  the WireGuard UDP/51820 allow belongs in Phase 2 when the Azure VM and VPS
  public endpoint are real.
- The incorrect PE HTTPS rule and incorrect WireGuard outbound rule were
  removed. Private endpoint network policies remain deferred until a PE exists.
  The AzureRM 3.x argument is deprecated in newer provider versions; current
  syntax is `private_endpoint_network_policies`.
- Phase 1 tutorial: `docs/tutorials/phase-1-core-networking.md`.
- Service principal reference expanded with Terraform authentication and RBAC
  guidance in `docs/concepts/service-principals-explained.md`.
- No UDR, Azure VM, private endpoint, private DNS zone, or tunnel exists yet.

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

Phase 1 is complete. Before implementing Phase 2, discuss and diagram the
planned packet path: Azure workload → subnet route table → WireGuard VM →
WireGuard tunnel → VPS. Phase 2 implementation will then add the Azure VM,
NSG UDP/51820 rule, forwarding, UDR, and Ansible only after the design is
understood.

AZ-104 mapping so far: NSG rule priority/evaluation, default security rules,
statefulness, service tags, subnet delegation, VNet/subnet design, and
Network Watcher preparation.

Deferred (revisit in Phase 3): shared-key access on state storage, SP blob
data role, Entra/RBAC backend — least privilege pass.

Import ID note: `azurerm_storage_container` imports by the blob URL
(`https://commonsaportfolio.blob.core.windows.net/common`), not the ARM
resource-manager path.
