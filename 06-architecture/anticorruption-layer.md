# Anticorruption Layer

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🔴 Senior
**Tags:** `anticorruption-layer`, `ACL`, `DDD`, `bounded-context`, `integration`, `legacy-systems`, `translation`

## Question

> What is an Anticorruption Layer (ACL), and when do you need one? How do you implement an ACL in .NET to prevent external system models from polluting your domain model?

## Short Answer

An **Anticorruption Layer** (Eric Evans, "Domain-Driven Design") is a translation layer that sits between your domain model and an external or legacy system, converting the external model's concepts into your own domain language. Without an ACL, the external system's naming, structure, and assumptions bleed into your codebase — your domain "conforms" to a foreign model. The ACL translates in both directions: adapting external responses to your domain types on the way in, and translating your commands to the external system's format on the way out.

## Detailed Explanation

### When You Need an ACL

You need an ACL when the external system:
- **Uses different terminology** for the same concept (your "Customer" vs their "Account")
- **Has a legacy/inferior model** that doesn't fit your domain
- **Is controlled by another team** with different design priorities
- **Is a vendor system** whose API design you cannot influence
- **Is likely to change** and you want to isolate your domain from the change

You do NOT need a full ACL when:
- You fully control both sides (same team, same bounded context)
- The external model maps 1:1 to your model (simple property renaming)
- The integration is trivial and unlikely to change

### ACL Anatomy

```
Your Domain Model
       ↑  ↓ (your types only)
  ACL (Translation Layer)
       ↑  ↓ (external types)
 External / Legacy System
```

The ACL owns the translation logic. Your domain objects never see external types.

### Implementation: Translate External API Response

A common scenario: consuming a third-party shipping API that has its own shipping address and carrier model.

```csharp
// External shipping provider types (could come from their SDK or generated client)
namespace ExternalShipping.Api.Models
{
    public class ShippingQuoteResponse
    {
        public string CarrierCode { get; set; } = string.Empty;
        public decimal BaseCharge { get; set; }
        public decimal FuelSurcharge { get; set; }
        public string DeliveryDate { get; set; } = string.Empty; // ← string, not DateTime
        public string StatusCode { get; set; } = string.Empty;  // "OK", "ERR", "UNAVAIL"
    }
}

// Your domain types — clean, no external concepts
namespace YourApp.Domain.Shipping
{
    public record ShippingQuote(
        string Carrier,
        Money TotalCost,
        DateOnly EstimatedDelivery);

    public enum ShippingAvailability { Available, Unavailable }
}

// ACL: Interface defined in Application layer (driven port)
namespace YourApp.Application.Shipping
{
    public interface IShippingService
    {
        Task<(ShippingAvailability, ShippingQuote?)> GetQuoteAsync(
            ShippingAddress destination,
            Weight parcelWeight,
            CancellationToken ct = default);
    }
}

// ACL: Implementation in Infrastructure layer
namespace YourApp.Infrastructure.Shipping
{
    public class FedExShippingService(
        IExternalShippingApiClient client,
        ILogger<FedExShippingService> log) : IShippingService
    {
        public async Task<(ShippingAvailability, ShippingQuote?)> GetQuoteAsync(
            ShippingAddress destination, Weight parcelWeight, CancellationToken ct)
        {
            // Translate OUT: your domain → external format
            var externalRequest = TranslateRequest(destination, parcelWeight);

            ShippingQuoteResponse externalResponse;
            try { externalResponse = await client.GetQuoteAsync(externalRequest, ct); }
            catch (ExternalApiException ex)
            {
                log.LogWarning(ex, "FedEx API unavailable");
                return (ShippingAvailability.Unavailable, null);
            }

            // Translate IN: external format → your domain
            return TranslateResponse(externalResponse);
        }

        private static ExternalQuoteRequest TranslateRequest(ShippingAddress addr, Weight weight)
            => new()
            {
                RecipientZip = addr.PostalCode,
                RecipientCountry = addr.Country.Iso2Code,
                WeightLbs = weight.ToLbs()
            };

        private static (ShippingAvailability, ShippingQuote?) TranslateResponse(
            ShippingQuoteResponse response)
        {
            if (response.StatusCode != "OK")
                return (ShippingAvailability.Unavailable, null);

            var totalCost = new Money(response.BaseCharge + response.FuelSurcharge, "USD");
            var delivery = DateOnly.Parse(response.DeliveryDate); // ← type fix: string → DateOnly

            return (ShippingAvailability.Available,
                new ShippingQuote("FedEx", totalCost, delivery));
        }
    }
}
```

### ACL for Legacy Database (Translation on Read)

When reading from a legacy DB with a different schema/naming:

```csharp
// Legacy DB row (from a 20-year-old system)
public class LegacyAccountRecord
{
    public string ACCT_NUM { get; set; } = "";    // your domain calls this CustomerId
    public string CUST_NM { get; set; } = "";     // CustomerName
    public int ACCT_STS { get; set; }            // 1=Active, 2=Suspended, 3=Closed
    public DateTime OPEN_DT { get; set; }
}

// ACL translation to your domain model
public static class LegacyAccountTranslator
{
    public static Customer ToDomain(LegacyAccountRecord record)
        => new(
            Id: new CustomerId(record.ACCT_NUM),
            Name: new CustomerName(record.CUST_NM),
            Status: TranslateStatus(record.ACCT_STS),
            OpenedAt: record.OPEN_DT);

    private static CustomerStatus TranslateStatus(int code) => code switch
    {
        1 => CustomerStatus.Active,
        2 => CustomerStatus.Suspended,
        3 => CustomerStatus.Closed,
        _ => throw new ArgumentOutOfRangeException(nameof(code), $"Unknown legacy status: {code}")
    };
}
```

## Code Example

```csharp
// Application layer use-case: completely unaware of FedEx, legacy DB, or external types
public class GetShippingQuoteHandler(IShippingService shipping)
    : IRequestHandler<GetShippingQuoteQuery, ShippingQuoteDto?>
{
    public async Task<ShippingQuoteDto?> Handle(GetShippingQuoteQuery q, CancellationToken ct)
    {
        var address = new ShippingAddress(q.PostalCode, Country.FromIso2(q.CountryCode));
        var weight = Weight.FromKg(q.WeightKg);

        var (availability, quote) = await shipping.GetQuoteAsync(address, weight, ct);

        if (availability == ShippingAvailability.Unavailable) return null;

        return new ShippingQuoteDto(
            quote!.Carrier,
            quote.TotalCost.Amount,
            quote.TotalCost.Currency,
            quote.EstimatedDelivery);
    }
}
// ↑ This handler has zero knowledge of FedEx, external API formats, or legacy system quirks.
// The ACL (FedExShippingService) absorbs ALL of that complexity.
```

## Common Follow-up Questions

- How is an ACL different from a simple Adapter pattern?
- When does an ACL become an over-engineering anti-pattern for simple integrations?
- How do you test the ACL translation logic in isolation?
- How does an ACL relate to the Shared Kernel and Conformist integration patterns?
- How do you version an ACL when the external system releases a new API version?

## Common Mistakes / Pitfalls

- **External types leaking through the ACL interface**: if `IShippingService` returns `ShippingQuoteResponse` (an external type), the ACL provides no isolation — callers still depend on the external model.
- **ACL in the wrong layer**: the translation logic (ACL) belongs in Infrastructure; the interface it implements belongs in Application. Putting both in Application re-couples application logic to external types.
- **One ACL per call site**: each use-case handler doing its own translation independently leads to duplicated, inconsistent translation logic. Centralise in one ACL class per external system.
- **Not updating the ACL when the external API changes**: the ACL absorbs changes from the external system — this is its primary value. If you skip updating the ACL and let external changes propagate directly, the protection is lost.

## References

- [Domain-Driven Design: Tackling Complexity in the Heart of Software — Eric Evans](https://www.dddcommunity.org/book/evans_2003/) (verify URL)
- [Implementing Domain-Driven Design — Vaughn Vernon](https://vaughnvernon.com/?page_id=168) (verify URL)
- [See: shared-kernel-vs-separate-ways.md](./shared-kernel-vs-separate-ways.md)
- [See: context-mapping-patterns.md](./context-mapping-patterns.md)
- [See: ports-and-adapters.md](./ports-and-adapters.md)
