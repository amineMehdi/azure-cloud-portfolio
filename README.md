# azure-cloud-portfolio

   Hybrid Azure + on-prem cloud portfolio project. Built for AZ-104 → AZ-305
   study, demonstrating three core tools:

- **Terraform** — Azure infrastructure provisioning and remote state
- **Ansible** — repeatable server configuration (VPS + Azure VMs)
- **Kubernetes** — k3s on-prem, then short-lived AKS comparison

## Phase 0 — Foundations & safety net

   [X] VPS: SSH-hardened, UFW, fail2ban, swapfile configured
   [X] Service Principal created for Terraform (Contributor at subscription
       scope — accepted while subscription is empty and dedicated)
   [X] Remote Terraform state: persistent bootstrap (`CommonRG` /
       `commonsaportfolio`) split from disposable `dev` workload root
