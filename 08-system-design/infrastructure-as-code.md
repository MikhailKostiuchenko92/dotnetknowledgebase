# Infrastructure as Code

**Category:** System Design / Cloud-Native
**Difficulty:** Senior
**Tags:** `iac`, `terraform`, `bicep`, `pulumi`, `idempotency`, `state-management`, `drift-detection`

## Question

> What is Infrastructure as Code (IaC) and why does it matter? What are the differences between Terraform, Bicep, and Pulumi? How does state management work and what is drift detection? What are the pitfalls of IaC at scale?

- What does "idempotent" mean in the context of IaC?
- How do you handle secrets and sensitive values in IaC safely?

## Short Answer

Infrastructure as Code treats infrastructure provisioning (VMs, databases, networks, Kubernetes clusters) as code: version-controlled, reviewed, tested, and applied automatically. The key property is idempotency — applying the same definition multiple times converges to the desired state without side effects. Terraform (HCL, cloud-agnostic, state file), Bicep (ARM-based, Azure-only, no state file), and Pulumi (real programming languages, cloud-agnostic, state backend) are the main tools. At scale, the critical operational concerns are state management (who holds the lock?), drift (manual changes that diverge from IaC), and secrets handling (never check secret values into source control).

## Detailed Explanation

### Why IaC?

Manual infrastructure provisioning via portal clicks or ad-hoc scripts leads to:
- **Snowflake servers**: each environment differs slightly; "works in staging" failures.
- **No audit trail**: who created this resource? when? why?
- **Disaster recovery**: recreating the environment from scratch is weeks of work.
- **Drift**: production has extra resources added manually that don't exist in staging.

IaC solves this: the entire infrastructure is described in files, stored in Git, reviewed in PRs, and applied by a pipeline.

### Tool Comparison

| | Terraform | Bicep | Pulumi |
|--|-----------|-------|--------|
| Language | HCL (DSL) | Bicep (DSL, ARM JSON) | TypeScript / C# / Python |
| Cloud scope | Multi-cloud | Azure only | Multi-cloud |
| State | Remote state file (S3, Azure Blob, HCP) | Azure manages state | Remote state (similar to Terraform) |
| Learning curve | Medium | Low (for Azure teams) | Low for developers, high for ops |
| Ecosystem | Largest provider registry | Azure-native, no 3rd party | Growing |
| Testing | Terratest (Go), native plan | arm-ttk, Pester | Built-in (unit + integration) |

**Choose Terraform** for multi-cloud or strong community ecosystem requirements.  
**Choose Bicep** for Azure-only shops that want deep ARM integration and type safety.  
**Choose Pulumi** for teams that prefer their application language over a DSL.

### Terraform Example: AKS + ACR

```hcl
# versions.tf
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatestorage"
    container_name       = "tfstate"
    key                  = "orders-prod.tfstate"
  }
}

# main.tf
resource "azurerm_resource_group" "orders" {
  name     = "orders-${var.environment}-rg"
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = "orders${var.environment}acr"
  resource_group_name = azurerm_resource_group.orders.name
  location            = azurerm_resource_group.orders.location
  sku                 = "Premium"
  admin_enabled       = false
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "orders-${var.environment}-aks"
  resource_group_name = azurerm_resource_group.orders.name
  location            = azurerm_resource_group.orders.location
  dns_prefix          = "orders-${var.environment}"

  default_node_pool {
    name       = "system"
    node_count = var.node_count
    vm_size    = "Standard_D4s_v5"
    os_disk_size_gb = 100
  }

  identity {
    type = "SystemAssigned"   # Managed Identity — no service principal credentials
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }
}

# Grant AKS pull access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
```

```hcl
# variables.tf
variable "environment" {
  type    = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "node_count" {
  type    = number
  default = 2
}
```

### Bicep Example (Azure-Native)

```bicep
// aks.bicep
param environment string
param nodeCount int = 2
param location string = resourceGroup().location

resource aks 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: 'orders-${environment}-aks'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: 'orders-${environment}'
    agentPoolProfiles: [
      {
        name: 'system'
        count: nodeCount
        vmSize: 'Standard_D4s_v5'
        mode: 'System'
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
    }
  }
}

output aksName string = aks.name
output aksFqdn string = aks.properties.fqdn
```

Bicep compiles to ARM JSON and is idempotent via Azure Resource Manager's PUT semantics.

### State Management

Terraform's state file records what resources it has created and their current properties. This enables:
- **Plan**: compare desired state (HCL) with actual state (Azure) → show diff.
- **Apply**: update Azure to match HCL.
- **Destroy**: remove resources recorded in state.

**Remote state is critical for teams:**

```hcl
backend "azurerm" {
  resource_group_name  = "tfstate-rg"
  storage_account_name = "tfstatestorage"
  container_name       = "tfstate"
  key                  = "orders-prod.tfstate"
  use_azuread_auth     = true   # use Managed Identity; no storage key in config
}
```

Azure Blob storage provides **state locking** (via blob lease) — prevents two `terraform apply` runs from corrupting state simultaneously.

### Drift Detection

**Drift**: someone manually changes a resource (adds a firewall rule via portal, resizes a VM) that differs from what IaC defines.

```bash
# Detect drift: compare actual Azure state with Terraform state
terraform plan -detailed-exitcode
# Exit code 2 = changes detected = drift found

# Or with explicit refresh:
terraform refresh   # update state file with current Azure reality
terraform plan      # show diff between refreshed state and HCL
```

**Automated drift detection**: run `terraform plan` in a scheduled GitHub Actions workflow and alert if changes are detected:

```yaml
# .github/workflows/drift-detection.yml
schedule:
  - cron: "0 6 * * *"   # daily at 6am
jobs:
  detect-drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init
      - run: terraform plan -detailed-exitcode
        id: plan
      - if: steps.plan.outputs.exitcode == '2'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({ ... title: "Infrastructure drift detected" })
```

### Secrets in IaC

Never store secret values in `.tf` files or state files:

```hcl
# ❌ Bad: secret in HCL (goes into Git and state file)
resource "azurerm_key_vault_secret" "db_password" {
  value = "SuperSecret123!"   # visible in state file, Git history
}

# ✅ Better: secret value from CI/CD environment variable
resource "azurerm_key_vault_secret" "db_password" {
  value = var.db_password     # passed at apply time: TF_VAR_db_password=...
}

variable "db_password" {
  type      = string
  sensitive = true   # redacted from plan output
}
```

Use **Azure Key Vault** as the source of truth for secrets; IaC only grants access policies and references — it doesn't store the secret values.

> **Warning:** Terraform state files can contain sensitive values in plaintext (connection strings, passwords that the provider returns). Always encrypt state at rest (enable Storage Account infrastructure encryption) and restrict access with RBAC. Consider using `sensitive` attribute for outputs.

## Code Example

```bash
# Typical IaC CI/CD pipeline flow
# 1. PR opened → plan runs, diff posted as PR comment
# 2. PR approved → plan re-runs on merge to main
# 3. Manual approval gate for production
# 4. Apply runs → infrastructure updated

# GitHub Actions: plan on PR
- name: Terraform Plan
  run: |
    terraform init
    terraform plan -out=tfplan -var-file="environments/production.tfvars"
  env:
    ARM_USE_OIDC: true              # federated identity — no service principal secret
    ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
    ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
    ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}

- name: Show Plan
  run: terraform show -no-color tfplan

# GitHub Actions: apply on main (after approval)
- name: Terraform Apply
  if: github.ref == 'refs/heads/main'
  run: terraform apply -auto-approve tfplan
```

## Common Follow-up Questions

- How do you manage multiple environments (dev/staging/prod) in Terraform without duplicating code?
- What is a Terraform workspace and when should you use modules vs workspaces?
- How do you handle breaking changes to existing resources (e.g., renaming an AKS cluster requires destroy + recreate)?
- What is the `lifecycle` block in Terraform and when do you use `prevent_destroy`?
- How do you test IaC — what does a good IaC test suite look like?

## Common Mistakes / Pitfalls

- **Local state file**: storing `terraform.tfstate` locally prevents team collaboration and has no locking; always use remote backend from day one.
- **Not locking provider versions**: `~> 3.90` locks to 3.x; without a version constraint, `terraform init` may pull a major version upgrade that breaks everything.
- **Sensitive values in outputs**: Terraform outputs are stored in state; mark sensitive outputs with `sensitive = true` to prevent them being shown in plan output.
- **Applying without reviewing the plan**: `terraform apply -auto-approve` in a pipeline without reviewing the plan can silently destroy production resources; always review the plan diff.
- **Manual portal changes**: a culture of "I'll just fix it in the portal" defeats IaC; enforce that all changes go through code review by using Azure Policy to deny resource modifications outside tagged deployments.

## References

- [Terraform documentation](https://developer.hashicorp.com/terraform/docs)
- [Bicep documentation — Microsoft Docs](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview)
- [Pulumi .NET SDK](https://www.pulumi.com/docs/languages-sdks/dotnet/)
- [Terraform with Azure — Microsoft Docs](https://learn.microsoft.com/en-us/azure/developer/terraform/)
- [See: containers-and-orchestration.md](./containers-and-orchestration.md)
- [See: kubernetes-for-dotnet-devs.md](./kubernetes-for-dotnet-devs.md)
