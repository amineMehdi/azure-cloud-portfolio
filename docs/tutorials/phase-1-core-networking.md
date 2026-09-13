# Phase 1: Core Azure Networking

This phase creates the network foundation for the hybrid project. It does not
create a VM, VPN tunnel, route table, private endpoint, or application yet.
Those later resources will consume this foundation.

## The resource graph

```text
Resource group
└── Virtual network: main-vnet (10.0.0.0/16)
    ├── app-subnet (10.0.1.0/24)
    │   └── app-nsg ── association ──┘
    ├── pe-subnet (10.0.2.0/24)
    │   └── pe-nsg ── association ───┘
    └── vpn-subnet (10.0.3.0/24)
        └── vpn-nsg ── association ─┘
```

Terraform creates each object separately. The association resources are the
wiring: they tell Azure which NSG applies to each subnet. An NSG without an
association is only an unused rule collection.

## Resource roles

| Resource | Azure responsibility | What consumes it |
|---|---|---|
| VNet | Private address space and Azure routing domain | Subnets and VNet resources |
| Subnet | Address segment inside the VNet | VM/NIC, private endpoint, or delegated service |
| NSG | Stateful allow/deny packet filter | Subnet association |
| NSG association | Applies an NSG to a subnet | Azure evaluates it for subnet NIC traffic |
| Route table / UDR | Overrides or adds packet destinations | Subnet association; Phase 2 |
| Private endpoint | Private NIC for an Azure PaaS service | Private DNS and client workload; later phase |

A subnet is not a firewall, and an NSG is not a router:

```text
NSG       = may this traffic pass?
Route     = where should the traffic go?
WireGuard = how does the selected path cross the tunnel?
```

## Subnet design

The three subnets are separated by role, not because Azure requires three
subnets:

- `app-subnet`: future Azure workload.
- `vpn-subnet`: future Azure WireGuard VM.
- `pe-subnet`: future Azure Private Endpoint NICs.

The separation gives each role an independent place for NSGs, route tables,
and future policy. It also makes packet paths visible during troubleshooting.
A subnet does not automatically isolate traffic from other subnets: Azure's
default `AllowVNetInBound` rule permits VNet traffic unless a higher-priority
custom deny is added.


## NSGs and rule evaluation

An NSG evaluates inbound and outbound traffic separately. Custom rules use an
integer priority; the lower number wins. Azure also adds default rules:

```text
65000  AllowVNetInBound / AllowVNetOutBound
65001  AllowAzureLoadBalancerInBound / AllowInternetOutBound
65500  DenyAllInBound / DenyAllOutBound
```

Therefore an empty NSG is valid but not equivalent to deny-all. In this phase
the NSGs are intentionally rule-minimal:

- `app-nsg`: no custom rules yet; there is no application traffic to permit.
- `pe-nsg`: no custom rules yet; there is no private endpoint or client flow.
- `vpn-nsg`: no custom rules yet; the WireGuard VM does not exist yet.

The first Phase 2 rule will describe the real WireGuard handshake:

```text
VPS public IPv4 ── UDP/51820 ──> Azure WireGuard VM
```

That is an inbound rule on `vpn-nsg`, because the packet enters Azure from the
Internet. The fact that the VPS initiated the connection does not make it an
Azure outbound packet.

An NSG is stateful: when an allowed connection is established, the return
traffic is allowed as part of that flow. This is why a separate reverse rule
is normally not required for a permitted TCP or UDP flow.

## Private endpoints: later phase

A private endpoint is a private IP and NIC in your VNet that represents an
Azure PaaS service, such as a separate Storage Account. It is not the same as
a VM and it is not required to reach the VPS database. The VPS database path
will use WireGuard and a UDR instead.

Azure gives private endpoints special routing behavior. Subnet private
endpoint network policies control whether NSGs and/or user-defined routes can
apply to those endpoint NICs. The setting affects private endpoints in that
subnet, not ordinary resources.

## Phase 1 verification

From `terraform/dev`:

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
```

The plan must not propose destroying `RG-DEV`. After apply:

```bash
az network vnet show \
  --resource-group RG-DEV \
  --name main-vnet \
  --query '{addressSpace:addressSpace.addressPrefixes, subnets:subnets[].name}'

az network nsg list \
  --resource-group RG-DEV \
  --query '[].{name:name, rules:securityRules}'
```

Effective NIC rules, effective routes, and IP flow verification become useful
in Phase 2 after the VM and NIC exist. Network Watcher cannot show effective
NIC state for a resource that does not yet have a NIC.

