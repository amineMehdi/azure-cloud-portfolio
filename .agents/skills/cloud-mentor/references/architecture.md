# Architecture & Roadmap

Reference detail for the `cloud-mentor` skill. Phases are ordered, not
calendar-scheduled — move on when the deliverable is solid, not when a week
ends.

## Why this design

- **Terraform** provisions Azure, **Ansible** makes the VPS and Azure
  WireGuard VM configuration repeatable, and **Kubernetes** is learned on
  k3s before a short-lived **AKS** comparison. These are the three core
  portfolio tools; each must produce a demonstrable project outcome.
- VPS is the "on-prem" site in every hybrid exercise. It's also home for
  anything wasteful to run 24/7 in Azure (Jenkins, Prometheus, a plain DB).
- Azure side is deliberately minimal and destroy-after-use: Terraform
  `apply` for a session, `destroy` after. A B1s VM running WireGuard
  replaces Azure VPN Gateway (Basic SKU alone is ~$27+/month left running);
  same routing/NSG/UDR concepts, pennies per session instead.
- The workload glueing both sides together (Container App / Function) uses
  tools already known — it exists only to give the network something real
  to carry, it is not the learning target.

## VPS layout (2GB RAM — budget it, don't just install everything)

1. Swapfile (2-4GB) — do this before anything else. Non-negotiable; skip it
   and every phase past 1 will randomly hang from OOM/swap thrash.
2. Always-on, lean:
   - WireGuard (tunnel endpoint)
   - k3s (single node, ~500MB idle) — the on-prem Kubernetes cluster
   - Postgres (small container) — the "on-prem database" workload
3. On-demand only, via `docker compose --profile`, started for the session
   that needs them, stopped after:
   - Jenkins (~1GB alone, don't leave it resident)
   - Prometheus + Grafana

## Azure layout

- 1 resource group, 1 VNet, 2-3 subnets (app, private-endpoint, gateway/vpn)
- NSG per subnet, explicit priorities, default-deny mindset
- Route table (UDR): on-prem-bound ranges → next hop = the WireGuard VM's
  private IP
- Small B1s VM running WireGuard as the Azure-side tunnel endpoint
- Private DNS zone + Private Endpoint on a Storage Account (public vs
  private connectivity contrast — real AZ-104/305 exam point)
- Terraform remote state in a Storage Account (bootstrapped manually once —
  the chicken/egg problem is itself worth understanding)
- Custom RBAC role for the Terraform service principal, scoped to the RG,
  least privilege (not Owner)
- Log Analytics workspace (free 5GB/day grant) + NSG flow logs +
  VPN/VM diagnostics
- Azure Budget + action group alert at $5 as a cost safety net
- Optional stretch, one session only, then destroyed: AKS, to compare
  managed vs self-run Kubernetes (who manages control plane vs node pool)

## Phases

**Phase 0 — Foundations & safety net**
- VPS hardening: SSH key-only, ufw, fail2ban (quick, non-negotiable)
- Swapfile
- Azure Budget + $5/$10 alert
- Terraform: install, azurerm provider, remote state bootstrap
- Deliverable: `terraform plan` runs clean against an empty RG; VPS
  reachable only via SSH key.

**Phase 1 — Core networking (the named skill gap, the heart of this project)**
- VNet + subnets + NSGs, nothing internet-facing yet
- Learn: subnet delegation, NSG rule priority/evaluation order, service
  endpoint vs private endpoint
- Use Network Watcher (effective routes / effective NSG rules / IP flow
  verify) instead of Azure Bastion (cost) to inspect, not just build
- Deliverable: a diagram + README explaining *why* each subnet/NSG rule
  exists, reviewed before moving on

**Phase 2 — Hybrid connectivity & Ansible**
- WireGuard VPS <-> Azure VM, static routes, UDR wiring
- After manually understanding the setup, use one idempotent Ansible
  playbook to configure WireGuard prerequisites and the VPS baseline
- Validate: ping/traceroute across the tunnel, on-prem Postgres reachable
  from inside the Azure VNet
- Deliverable: the packet path written out hop-by-hop end to end, plus the
  Ansible playbook and inventory documentation

**Phase 3 — Identity & governance**
- Custom least-privilege RBAC role for the Terraform SP
- 1-2 Azure Policies (e.g. deny public IP, require tags) — light touch,
  not a whole framework

**Phase 4 — Workload on top**
- Container App or Function (VNet-integrated) in the spoke subnet, calling
  on-prem Postgres over the tunnel
- Optional: Event Grid trigger (blob upload) → Function → writes to
  on-prem Postgres, tying existing PaaS knowledge into the new network
  fabric

**Phase 5 — Kubernetes**
- k3s on the VPS as the primary, always-available learning cluster
- Deploy the same small app as a Helm chart there; compare with the
  Container App version
- AKS for one planned session: deploy the same workload and document what
  Azure manages versus k3s; destroy the cluster immediately afterward

**Phase 6 — CI/CD (small, on purpose — supporting skill, not the goal role)**
- One GitHub Actions infrastructure workflow running `terraform plan` on PR
  and a protected `apply` on merge, targeting Azure
- Add an application workflow only after the workload has a separate build
  and deployment lifecycle; resist further pipeline splitting

**Phase 7 — Observability**
- Prometheus scraping k3s + node_exporter locally; pull Azure-side metrics
  via Log Analytics or an exporter across the tunnel
- Grafana dashboard unifying both sides — the portfolio screenshot

## Deliverable pattern (every phase)

Terraform/config code + a short README explaining the *why* — this is what
becomes portfolio material and interview talking points, not just "it
works."
