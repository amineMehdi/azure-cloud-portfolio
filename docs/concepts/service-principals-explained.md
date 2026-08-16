# Service Principals & App Registrations Explained

## The core confusion

Two separate Entra ID objects represent what most people think of as "a service principal." Confusing the two is the most common identity mistake in Azure.

**Application registration** = the identity's *definition* / blueprint.  
**Service principal** = that identity's *instance* with permissions in one specific tenant.

One app registration can have **many service principals** (one per tenant). The app is *who*; the SP is the badge issued at a specific company's front desk with the access level stamped on it.

---

## Object types

### 1. Application (app registration)

| Property | Example | Purpose |
|---|---|---|
| `appId` / `applicationId` | `9c66a059-...` | **Client ID** used for authentication (e.g. `ARM_CLIENT_ID`) |
| `applicationObjectId` | `011e5d94-...` | Entra ID internal identifier for the app definition |
| `displayName` | `azure-cli-2026-08-04-...` | Human-readable name |

- The identity blueprint. Lives in your Entra directory.
- Issued client secrets / certificates.
- Defines OAuth scopes and API permissions.
- **Never used for RBAC role assignments.**

### 2. Service principal (SP)

| Property | Example | Purpose |
|---|---|---|
| `objectId` / `id` | `d1e39568-...` | **SP object ID** — used for RBAC role assignments |
| `appId` | `9c66a059-...` | References the application registration it was created from (identical to app's `appId`) |
| `displayName` | `azure-cli-2026-08-04-...` | Usually matches the app registration |

- The *instance* of an application in a specific tenant.
- Holds role assignments (RBAC).
- This is what authenticates when you use a client secret.
- **This is what you pass to `--assignee-object-id`.**

---

## One app → many SPs (the multi-tenant model)

```
Application registration (global identity)
  ├── Service principal in tenant A  →  role assignments in tenant A
  ├── Service principal in tenant B  →  role assignments in tenant B
  └── Service principal in tenant C  →  role assignments in tenant C
```

Each SP can have **different** roles in **different** tenants. The app registration is shared; the permissions are per-tenant.

In a single-tenant setup (most common for learning projects), there's exactly **one SP** for the one app. The split still exists under the hood — Azure API is built on the multi-tenant model.

---

## Which ID goes where?

| Context | Use | Property |
|---|---|---|
| Terraform / `ARM_CLIENT_ID` | Authentication (client secret) | **appId** |
| `az role assignment create --assignee-object-id` | Who gets the role | **SP objectId** |
| `az ad sp show --id` | Look up SP by its appId | expects **appId** (convenience) |
| OAuth / OIDC flows | Client identity | **appId** |
| Granting API permissions (Entra admin) | Which app definition | app's **applicationObjectId** |

**Rule of thumb:**  
- If it involves **secrets / authentication** → use `appId`.  
- If it involves **permissions / RBAC** → use SP `objectId`.

---

## Commands to get each ID

```bash
# From the .env client ID (appId)
az ad sp show --id "$ARM_CLIENT_ID" --query id -o tsv
# → returns the SP objectId (d1e39568-...)

# List all SPs for your app (useful in multi-tenant)
az ad sp list --display-name "your-sp-name" --query '[].id' -o tsv

# Get the app registration's own object ID
az ad app show --id "$ARM_CLIENT_ID" --query id -o tsv
# → returns the applicationObjectId (011e5d94-...)
```

---

## Common mistake: passing the wrong ID

```bash
# ❌ THIS FAILS — RBAC only accepts SP objectId
az role assignment create \
  --assignee-object-id "9c66a059-..." \   # ← this is the appId, not SP objectId
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/...

# ✅ Correct
az role assignment create \
  --assignee-object-id "d1e39568-..." \   # ← SP objectId
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/... \
  --assignee-principal-type ServicePrincipal
```

Error you'll see with the wrong ID:
> *Principals of type Application cannot validly be used in role assignments.*

---

## Mental model

- **App registration** = identity card / passport. Global. One per app.
- **Service principal** = the badge issued at this specific tenant's front desk. Has the actual access level stamped on it. One per app per tenant.

You authenticate with the passport (`appId` + secret).  
You assign permissions to the badge (`SP objectId`).

## What `az ad sp create-for-rbac` creates

That one command creates **both** objects:

1. An app registration (if one doesn't exist with that name).
2. A service principal in your current tenant.

It returns:
- `appId` → put in `ARM_CLIENT_ID`
- `password` → put in `ARM_CLIENT_SECRET`
- `tenant` → put in `ARM_TENANT_ID`
- The SP `objectId` is NOT returned directly — you query it with `az ad sp show --id "$appId" --query id -o tsv`

---

## Same pattern elsewhere in Azure

This "definition vs. instance with permissions" split is everywhere:

- **Managed identities**: system-assigned vs. user-assigned
- **User-assigned identity** = one identity definition you attach to multiple VMs; each VM is a separate instance
- **Enterprise applications** in the portal = the SP view of an app registration

Look for the pattern: *definition* vs. *instance-with-permissions* and you'll stop being surprised by it.