# ASP.NET Core

> Web API, middleware, DI, authentication, minimal APIs.

## Questions

## Index

### §10 Testing in ASP.NET Core

- [WebApplicationFactory Basics](webapplicationfactory-basics.md)
- [Integration Test Configuration](integration-test-configuration.md)
- [Test Authentication](test-authentication.md)
- [Mocking HttpClient](mocking-httpclient.md)
- [Database Integration Tests](database-in-integration-tests.md)
- [Testing Minimal APIs](minimal-api-testing.md)
- [Test Isolation Patterns](test-isolation-patterns.md)
- [Contract Testing](contract-testing-aspnet.md)
- [Performance Testing](performance-testing-aspnet.md)

### §9 Security Best Practices

- [HTTPS and HSTS](https-and-hsts.md)
- [Secrets Management](secrets-management.md)
- [Security Headers](security-headers.md)
- [Input Validation and XSS Prevention](input-validation-security.md)
- [HTTPS Certificate Management](https-certificate-management.md)
- [Advanced Content Security Policy](content-security-policy-advanced.md)
- [Supply Chain Security](supply-chain-security.md)
- [Threat Modeling a Web API](threat-model-web-api.md)

### §8 Performance & Diagnostics

- [Logging in ASP.NET Core](logging-in-aspnet-core.md)
- [Response Compression](response-compression.md)
- [Distributed Caching](distributed-caching.md)
- [SignalR Overview](signalr-overview.md)
- [Minimal API Source Generation](minimal-api-source-gen.md)
- [ASP.NET Core Metrics (.NET 8+)](aspnet-core-metrics.md)
- [Request Tracing and Distributed Tracing](request-tracing.md)
- [Minimal API Performance Patterns](minimal-api-performance.md)

### §7 Authentication & Authorization

- [Authentication Fundamentals](authentication-fundamentals.md)
- [JWT Authentication](jwt-authentication.md)
- [Cookie Authentication](cookie-authentication.md)
- [Authorization Policies](authorization-policies.md)
- [ASP.NET Core Identity](asp-net-core-identity.md)
- [Anti-Forgery (CSRF)](anti-forgery.md)
- [API Key Authentication](api-key-authentication.md)
- [Resource-Based Authorization](resource-based-authorization.md)
- [Claims Transformation](claims-transformation.md)
- [Data Protection API](data-protection-api.md)

### §6 Web API Design

- [Controllers vs Minimal APIs](controller-vs-minimal-api.md)
- [[ApiController] Attribute](api-controller-attribute.md)
- [API Versioning](versioning-aspnet-core.md)
- [OpenAPI in ASP.NET Core](openapi-in-aspnet-core.md)
- [Response Caching](response-caching.md)
- [IHttpClientFactory](http-client-factory.md)
- [gRPC in ASP.NET Core](grpc-in-aspnet-core.md)
- [Rate Limiting (.NET 7+)](rate-limiting.md)
- [Output Caching (.NET 7+)](output-caching.md)

### §5 Filters & Action Pipeline

- [Filters Overview](filters-overview.md)
- [Action Filters](action-filters.md)
- [Exception Filters](exception-filters.md)
- [Result Filters](result-filters.md)
- [Filter DI and Registration](filter-di-and-registration.md)
- [Resource Filters](resource-filters.md)
- [Filter Ordering and Scope](filter-ordering-and-scope.md)

### §4 Routing & Model Binding

- [Routing Fundamentals](routing-fundamentals.md)
- [Action Results and IResult](action-results.md)
- [Minimal API Routing](minimal-api-routing.md)
- [Model Binding Pipeline](model-binding-pipeline.md)
- [Model Validation](model-validation.md)
- [Parameter Binding in Minimal APIs](parameter-binding-minimal-api.md)
- [ProblemDetails Integration](problem-details-integration.md)
- [Content Negotiation](content-negotiation.md)
- [Custom Model Binder](custom-model-binder.md)
- [Endpoint Filters (.NET 7+)](endpoint-filters.md)

### §3 Dependency Injection

- [DI Fundamentals](di-fundamentals.md)
- [Service Lifetimes — Singleton, Scoped, Transient](service-lifetimes.md)
- [IOptions, IOptionsSnapshot, and IOptionsMonitor](ioptions-lifetimes.md)
- [Keyed Services (.NET 8+)](keyed-services.md)
- [Open-Generic DI Registration](open-generic-di-registration.md)
- [Factory Registration in DI](factory-registration-di.md)
- [DI with Hosted Services](di-with-hosted-services.md)
- [Captive Dependency / Scoped-in-Singleton Pitfall](scoped-in-singleton-pitfall.md)
- [IServiceScopeFactory — Manual Scope Management](service-scope-factory.md)
- [Scrutor — Decorator Pattern and Assembly Scanning](scrutor-and-decorator-di.md)

### §2 Middleware Pipeline

- [Middleware Pipeline Fundamentals](middleware-pipeline-fundamentals.md)
- [Built-in Middleware Overview](built-in-middleware-overview.md)
- [Writing Custom Middleware](writing-custom-middleware.md)
- [Middleware vs Filters](middleware-vs-filters.md)
- [UseWhen, MapWhen, and Map — Conditional Branching](use-when-map-branching.md)
- [Exception Handling Middleware](exception-handling-middleware.md)
- [CORS Middleware](cors-middleware.md)
- [Request/Response Pipeline — HttpContext](request-response-pipeline.md)
- [Middleware Pipeline Internals](middleware-pipeline-internals.md)

### §1 Hosting & Application Bootstrap
- [Environment Configuration](environment-configuration.md)
- [Generic Host — IHost, IHostedService, BackgroundService](generic-host.md)
- [Configuration System](configuration-system.md)
- [BackgroundService — Long-Running Work](background-services.md)
- [App Lifecycle — IHostApplicationLifetime](app-lifecycle.md)
- [Health Checks](health-checks.md)
- [Options Validation](options-validation.md)
- [Kestrel Configuration](kestrel-configuration.md)
- [IStartupFilter — Middleware Ordering at Startup](startup-filters.md)