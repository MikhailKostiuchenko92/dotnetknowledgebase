# Strangler Fig vs Modular Monolith

**Category:** Architecture / Modular Monolith
**Difficulty:** 🟡 Middle
**Tags:** `strangler-fig`, `modular-monolith`, `incremental-migration`, `architecture-evolution`, `reversibility`, `technical-debt`

## Question

> How do the Strangler Fig pattern and the Modular Monolith pattern relate to each other in the context of legacy migration? When should you choose one over the other, and what makes modular monolith a better intermediate step?

## Short Answer

**Strangler Fig** is a migration pattern: progressively extract features from a legacy system into new services while routing traffic through a proxy — the old system shrinks as the new one grows, eventually replacing it. **Modular Monolith** is an architectural style — not a migration pattern per se — that can be the target of a Strangler Fig migration or an intermediate step before extracting microservices. The typical recommended path: legacy big ball of mud → modular monolith (domain isolation achieved) → Strangler Fig extract specific modules → microservices where justified. Going directly from big ball of mud to microservices is the "distributed big ball of mud" anti-pattern.

## Detailed Explanation

### Strangler Fig Pattern

```
Origin: Martin Fowler named it after the strangler fig vine that grows around
        a host tree, eventually replacing it while the host dies naturally.

Steps:
  1. Route ALL traffic through a proxy (YARP, nginx, Azure API Management)
  2. Identify one feature/module to extract
  3. Build the new service implementing that feature
  4. Switch routing for that feature to the new service (via proxy config)
  5. Old system no longer serves that feature
  6. Repeat for the next feature until old system is empty
  7. Decommission the old system

Key benefit: users see no downtime; old system still handles unextracted features
Key risk: dual-write period where both systems must stay in sync until cutover
```

```csharp
// YARP proxy — route traffic based on feature readiness
// appsettings.json
{
  "ReverseProxy": {
    "Routes": {
      "orders-new": {
        "ClusterId": "orders-v2",
        "Match": { "Path": "/api/orders/{**catch-all}" }
      },
      "legacy": {
        "ClusterId": "legacy-monolith",
        "Match": { "Path": "/{**catch-all}" }
      }
    },
    "Clusters": {
      "orders-v2": {
        "Destinations": { "default": { "Address": "https://orders-svc:5001" } }
      },
      "legacy-monolith": {
        "Destinations": { "default": { "Address": "https://legacy:8080" } }
      }
    }
  }
}
// ↑ /api/orders/* goes to new service; everything else goes to legacy
```

### Modular Monolith as Intermediate Step

```
Problem with going directly from big ball of mud → microservices:
  - Domain boundaries not yet understood → wrong service splits
  - Splitting a tightly coupled codebase produces "distributed monolith"
    (services that require coordinated deployment, shared DB, etc.)
  - All the operational complexity of microservices + none of the independence

Better path:
  Big Ball of Mud
      ↓ (Strangler Fig or in-place refactoring)
  Modular Monolith    ← domain boundaries proven, module isolation tested
      ↓ (Strangler Fig per module, when justified)
  Microservices       ← only the modules that need independent scaling/deployment

Reversibility advantage of modular monolith:
  - Extracting a module too eagerly? Merge it back — no data migration needed
  - With microservices: merging services requires data migration + client changes
```

### Extracting a Module (Strangler Fig from Modular Monolith)

```
Pre-conditions for extraction:
  ✅ Module has a clear public API (IInventoryModule)
  ✅ Module owns its own DB schema (no shared tables)
  ✅ Module communicates via events (not direct internal calls from other modules)
  ✅ Module has independent deployment requirements or scaling needs

Extraction steps:
  1. Duplicate: build new InventoryService implementing IInventoryModule contract
  2. Configure proxy: route /api/inventory/* to new service
  3. Data migration: move inventory schema to separate DB
  4. Update caller modules: inject HTTP client implementing IInventoryModule
  5. Cutover: disable inventory code in the monolith
  6. Monitor: verify no regressions
  7. Clean up: remove dead inventory code from monolith

Key insight: because the module already had IInventoryModule as its contract,
             the calling modules don't change their code — just the DI binding changes
             from in-process to HTTP client.
```

```csharp
// Before extraction: IInventoryModule resolved to in-process implementation
services.AddScoped<IInventoryModule, InventoryModuleImpl>();

// After extraction: IInventoryModule resolved to HTTP client
services.AddHttpClient<IInventoryModule, InventoryHttpClient>(client =>
    client.BaseAddress = new Uri(configuration["Services:Inventory"]!));

// No other code changes needed! The interface contract is the extraction boundary.
```

## Code Example

```csharp
// Feature toggle: gradual cutover via feature flag (safe Strangler Fig)
services.AddScoped<IInventoryModule>(sp =>
{
    var features = sp.GetRequiredService<IFeatureManager>();
    var isExtracted = features.IsEnabledAsync("InventoryServiceExtracted").GetAwaiter().GetResult();

    if (isExtracted)
        return sp.GetRequiredService<InventoryHttpClient>();   // ← new microservice
    else
        return sp.GetRequiredService<InventoryModuleImpl>();   // ← in-process monolith
});
// ↑ Toggle between implementations without redeployment — safe incremental cutover
```

## Common Follow-up Questions

- How do you handle dual-write (keeping both old and new systems in sync during cutover)?
- What is the "branch by abstraction" technique and how does it relate to Strangler Fig?
- How do you decide which module to extract first?
- How do you handle DB schema ownership when the same data is accessed by old and new systems simultaneously?
- What is the risk of the "distributed monolith" anti-pattern and how do you recognize it?

## Common Mistakes / Pitfalls

- **Extracting the wrong module first**: start with the most isolated module (fewest dependencies, clearest boundaries) — not the largest or most complex. First extraction proves the process; pick an easy win.
- **Skipping the modular monolith step**: going directly from big ball of mud to microservices creates wrong service boundaries that are expensive to fix later. Take the time to identify clean module boundaries first.
- **Dual-write without a coordinator**: during Strangler Fig, both old and new systems need consistent data. Without a proper dual-write strategy (sync events, CDC, or read from one / write to both), data diverges.
- **Forgetting to decommission old code**: Strangler Fig phases often leave "zombie code" in the old system indefinitely. Incomplete extractions where the old code path is never removed negates the maintenance benefit.

## References

- [Strangler Fig pattern — Martin Fowler](https://martinfowler.com/bliki/StranglerFigApplication.html) (verify URL)
- [Branch By Abstraction — Martin Fowler](https://martinfowler.com/bliki/BranchByAbstraction.html) (verify URL)
- [See: strangler-fig-pattern.md](./strangler-fig-pattern.md)
- [See: modular-monolith-structure.md](./modular-monolith-structure.md)
