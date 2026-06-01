# 📋 ASP.NET Core — Question Backlog

Master list of planned questions for the `05-aspnet-core` section.
Use this file as the single source of truth for what to add next.

## How to use with Claude Code

- **Add one:** _"add an aspnet-core question on `jwt-authentication` from BACKLOG.md"_
- **Add a group:** _"add all questions from the 'Middleware Pipeline' group in BACKLOG.md"_
- **Continue:** _"pick the next 5 unwritten questions from BACKLOG.md and create them"_
- **Status check:** _"compare BACKLOG.md against existing files in `05-aspnet-core/` and tell me what's missing"_

When a question is created, mark it `[x]` and add a link to the file.

## Conventions

- **Filename:** kebab-case, exactly as listed below.
- **Difficulty:** 🟢 Junior • 🟡 Middle • 🔴 Senior
- **Template:** `_templates/question-template.md`
- **Commit:** `feat(aspnet-core): add question on <topic>`

---

## Progress

**Total:** 92 / 92 ✅
**By difficulty:** 🟢 17/17 · 🟡 46/46 · 🔴 29/29

---

## §1 Hosting & Application Bootstrap (10 questions)

- [x] 🟢 [`webapplication-builder.md`](webapplication-builder.md) — WebApplication.CreateBuilder, minimal hosting model, Program.cs without Startup
- [x] 🟢 [`environment-configuration.md`](environment-configuration.md) — IWebHostEnvironment, ASPNETCORE_ENVIRONMENT, appsettings.{env}.json layering
- [x] 🟢 [`generic-host.md`](generic-host.md) — IHost, IHostedService, BackgroundService, hosted service lifetime
- [x] 🟡 [`configuration-system.md`](configuration-system.md) — IConfiguration, provider chain (JSON/env/CLI/secrets), IOptions\<T\> binding
- [x] 🟡 [`background-services.md`](background-services.md) — BackgroundService, long-running work, graceful stop, scoped DI inside hosted service
- [x] 🟡 [`app-lifecycle.md`](app-lifecycle.md) — IHostApplicationLifetime, ApplicationStarted/Stopping/Stopped events, graceful shutdown
- [x] 🟡 [`health-checks.md`](health-checks.md) — IHealthCheck, AddHealthChecks, publisher, readiness vs liveness probe, UI dashboard
- [x] 🟡 [`options-validation.md`](options-validation.md) — IValidateOptions\<T\>, DataAnnotations on options, ValidateOnStart (.NET 7+), early failure
- [x] 🔴 [`kestrel-configuration.md`](kestrel-configuration.md) — Kestrel limits, HTTPS cert config, HTTP/2, HTTP/3 (QUIC), Unix sockets, IIS in-process
- [x] 🔴 [`startup-filters.md`](startup-filters.md) — IStartupFilter, middleware ordering at startup, use cases vs conventional middleware ordering

---

## §2 Middleware Pipeline (9 questions)

- [x] 🟢 [`middleware-pipeline-fundamentals.md`](middleware-pipeline-fundamentals.md) — Use/Run/Map, request delegate chain, short-circuiting, order matters
- [x] 🟢 [`built-in-middleware-overview.md`](built-in-middleware-overview.md) — StaticFiles, Routing, Authentication, Authorization, CORS, HTTPS, Exception
- [x] 🟡 [`writing-custom-middleware.md`](writing-custom-middleware.md) — IMiddleware vs convention-based middleware, InvokeAsync, DI in middleware
- [x] 🟡 [`middleware-vs-filters.md`](middleware-vs-filters.md) — What each has access to, HttpContext vs ActionContext, which to choose when
- [x] 🟡 [`use-when-map-branching.md`](use-when-map-branching.md) — UseWhen vs MapWhen vs Map, conditional branching, path-based split
- [x] 🟡 [`exception-handling-middleware.md`](exception-handling-middleware.md) — UseExceptionHandler, IExceptionHandler chain (.NET 8), ProblemDetails integration
- [x] 🟡 [`cors-middleware.md`](cors-middleware.md) — CORS policy, AddCors/UseCors, AllowSpecificOrigins, preflight OPTIONS, credentials
- [x] 🟡 [`request-response-pipeline.md`](request-response-pipeline.md) — HttpContext lifetime, request/response body buffering, HttpRequest/Response APIs
- [x] 🔴 [`middleware-pipeline-internals.md`](middleware-pipeline-internals.md) — Middleware compilation into RequestDelegate chain, ApplicationBuilder internals, branching cost

---

## §3 Dependency Injection (10 questions)

- [x] 🟢 [`di-fundamentals.md`](di-fundamentals.md) — Service registration (AddSingleton/Scoped/Transient), constructor injection, IServiceProvider
- [x] 🟢 [`service-lifetimes.md`](service-lifetimes.md) — Singleton vs Scoped vs Transient semantics, when to use each, scope validation
- [x] 🟡 [`ioptions-lifetimes.md`](ioptions-lifetimes.md) — IOptions\<T\> vs IOptionsSnapshot\<T\> vs IOptionsMonitor\<T\>, named options, reloading
- [x] 🟡 [`keyed-services.md`](keyed-services.md) — Keyed DI (.NET 8+), [FromKeyedServices], named service resolution, vs factory pattern
- [x] 🟡 [`open-generic-di-registration.md`](open-generic-di-registration.md) — Open-generic registration, typeof(IRepository\<\>), conditional registration
- [x] 🟡 [`factory-registration-di.md`](factory-registration-di.md) — Func\<T\> factory delegate, IServiceProvider factory, lazy resolution
- [x] 🟡 [`di-with-hosted-services.md`](di-with-hosted-services.md) — Scoped services inside BackgroundService, IServiceScopeFactory pattern, disposal
- [x] 🔴 [`scoped-in-singleton-pitfall.md`](scoped-in-singleton-pitfall.md) — Captive dependency anti-pattern, ValidateScopes, BuildServiceProvider(true)
- [x] 🔴 [`service-scope-factory.md`](service-scope-factory.md) — IServiceScopeFactory, creating scopes manually, async scope management, disposal
- [x] 🔴 [`scrutor-and-decorator-di.md`](scrutor-and-decorator-di.md) — Scrutor Decorate/Scan, assembly scanning conventions, open-generic decoration

---

## §4 Routing & Model Binding (10 questions)

- [x] 🟢 [`routing-fundamentals.md`](routing-fundamentals.md) — Conventional vs attribute routing, route templates, constraints, route order
- [x] 🟢 [`action-results.md`](action-results.md) — IActionResult, IResult, TypedResults (minimal API), status code helpers, negotiation
- [x] 🟡 [`minimal-api-routing.md`](minimal-api-routing.md) — MapGet/Post/Put/Delete, RouteGroupBuilder, endpoint metadata, IEndpointRouteBuilder
- [x] 🟡 [`model-binding-pipeline.md`](model-binding-pipeline.md) — [FromBody]/[FromQuery]/[FromRoute]/[FromHeader]/[FromForm], binding order
- [x] 🟡 [`model-validation.md`](model-validation.md) — DataAnnotations, [ApiController] auto-400, ModelState, FluentValidation integration
- [x] 🟡 [`parameter-binding-minimal-api.md`](parameter-binding-minimal-api.md) — Minimal API special binding: IFormFile, HttpContext, CancellationToken, IBindableFromHttpContext
- [x] 🟡 [`problem-details-integration.md`](problem-details-integration.md) — IProblemDetailsFactory, ValidationProblemDetails, RFC 9457, custom extensions
- [x] 🟡 [`content-negotiation.md`](content-negotiation.md) — Accept header, IOutputFormatter, adding XML support, custom formatters
- [x] 🔴 [`custom-model-binder.md`](custom-model-binder.md) — IModelBinder, IModelBinderProvider, binding from custom sources, composites
- [x] 🔴 [`endpoint-filters.md`](endpoint-filters.md) — IEndpointFilter (.NET 7+), minimal API filter pipeline, vs action filters, factory pattern

---

## §5 Filters & Action Pipeline (7 questions)

- [x] 🟢 [`filters-overview.md`](filters-overview.md) — Filter types (Authorization/Resource/Action/Exception/Result), execution order, pipeline diagram
- [x] 🟡 [`action-filters.md`](action-filters.md) — IActionFilter/IAsyncActionFilter, OnActionExecuting/Executed, modifying args/result
- [x] 🟡 [`exception-filters.md`](exception-filters.md) — IExceptionFilter, global exception filter, vs UseExceptionHandler middleware
- [x] 🟡 [`result-filters.md`](result-filters.md) — IResultFilter, modifying response before write, content-negotiation hook
- [x] 🟡 [`filter-di-and-registration.md`](filter-di-and-registration.md) — TypeFilterAttribute, ServiceFilterAttribute, global filters via AddMvc
- [x] 🔴 [`resource-filters.md`](resource-filters.md) — IResourceFilter, short-circuit before model binding, short-circuit caching use case
- [x] 🔴 [`filter-ordering-and-scope.md`](filter-ordering-and-scope.md) — Filter execution order, IOrderedFilter, controller vs action scope, override filter

---

## §6 Web API Design (9 questions)

- [x] 🟢 [`controller-vs-minimal-api.md`](controller-vs-minimal-api.md) — When to choose controllers vs minimal APIs, feature parity, code organisation
- [x] 🟡 [`api-controller-attribute.md`](api-controller-attribute.md) — [ApiController] auto-features: binding inference, auto-400, problem details
- [x] 🟡 [`versioning-aspnet-core.md`](versioning-aspnet-core.md) — Asp.Versioning, URL/header/query strategies, version sets, deprecated versions, Swagger
- [x] 🟡 [`openapi-in-aspnet-core.md`](openapi-in-aspnet-core.md) — Swashbuckle vs NSwag vs Microsoft.AspNetCore.OpenApi (.NET 9), Scalar UI
- [x] 🟡 [`response-caching.md`](response-caching.md) — [ResponseCache], Cache-Control/Vary headers, IResponseCachePolicy, CDN interaction
- [x] 🟡 [`http-client-factory.md`](http-client-factory.md) — IHttpClientFactory, named/typed clients, handler lifetime, Polly/resilience integration
- [x] 🔴 [`grpc-in-aspnet-core.md`](grpc-in-aspnet-core.md) — Grpc.AspNetCore, Protobuf codegen, HTTP/2 requirement, transcoding, gRPC-Web
- [x] 🔴 [`rate-limiting.md`](rate-limiting.md) — RateLimiter middleware (.NET 7+), fixed/sliding/token-bucket/concurrency limiters, partitioned
- [x] 🔴 [`output-caching.md`](output-caching.md) — IOutputCacheStore (.NET 7+), cache policies, vary-by, tag-based eviction, vs response caching

---

## §7 Authentication & Authorization (12 questions)

- [x] 🟢 [`authentication-fundamentals.md`](authentication-fundamentals.md) — Authentication vs authorisation, IAuthenticationService, scheme, challenge, forbid
- [x] 🟢 [`jwt-authentication.md`](jwt-authentication.md) — AddJwtBearer, TokenValidationParameters, issuer/audience/key validation, bearer scheme
- [x] 🟡 [`cookie-authentication.md`](cookie-authentication.md) — Cookie auth handler, sliding expiration, data protection keys, SameSite, anti-forgery
- [ ] 🔴 `oauth2-and-oidc.md` — OAuth2 flows, OpenID Connect, AddOpenIdConnect, PKCE, token storage in ASP.NET Core
- [x] 🟡 [`authorization-policies.md`](authorization-policies.md) — AddAuthorization, policy builder, RequireClaim/Role/AuthenticatedUser, [Authorize(Policy)]
- [x] 🔴 [`claims-transformation.md`](claims-transformation.md) — IClaimsTransformation, enriching claims post-authentication, multi-tenant identity
- [x] 🟡 [`asp-net-core-identity.md`](asp-net-core-identity.md) — UserManager\<T\>, SignInManager\<T\>, RoleManager\<T\>, custom stores, password hashing
- [x] 🟡 [`anti-forgery.md`](anti-forgery.md) — CSRF protection, IAntiforgery, [ValidateAntiForgeryToken], SameSite cookies, SPA handling
- [x] 🟡 [`api-key-authentication.md`](api-key-authentication.md) — Custom AuthenticationHandler\<T\>, API key scheme, [ApiKey] attribute pattern
- [x] 🔴 [`resource-based-authorization.md`](resource-based-authorization.md) — IAuthorizationService.AuthorizeAsync, IAuthorizationRequirement, IAuthorizationHandler
- [x] 🔴 [`data-protection-api.md`](data-protection-api.md) — IDataProtector, purpose strings, IDataProtectionProvider, key ring storage, key rotation
- [ ] 🔴 `microsoft-identity-platform.md` — MSAL, AddMicrosoftIdentityWebApi, Azure AD/B2C, on-behalf-of flow, token caching

---

## §8 Performance & Diagnostics (8 questions)

- [x] 🟢 [`logging-in-aspnet-core.md`](logging-in-aspnet-core.md) — ILogger\<T\>, log levels, category, structured logging, Serilog/NLog provider wiring
- [x] 🟡 [`response-compression.md`](response-compression.md) — AddResponseCompression, Brotli/Gzip providers, compression for APIs, chunked encoding
- [x] 🔴 [`distributed-caching.md`](distributed-caching.md) — IDistributedCache, AddStackExchangeRedisCache, cache-aside, sliding vs absolute expiry
- [x] 🔴 [`signalr-overview.md`](signalr-overview.md) — Hub, client methods, groups, IHubContext, backplane (Redis), connection lifecycle
- [x] 🟡 [`minimal-api-source-gen.md`](minimal-api-source-gen.md) — RequestDelegateGenerator (.NET 8+), source-generated endpoint handlers, AOT compatibility
- [x] 🔴 [`aspnet-core-metrics.md`](aspnet-core-metrics.md) — Built-in meters (Microsoft.AspNetCore.Hosting), kestrel/routing/http meters, OTEL export
- [x] 🔴 [`request-tracing.md`](request-tracing.md) — Activity per request, DiagnosticSource events, OTEL sampling, correlation IDs, baggage
- [x] 🔴 [`minimal-api-performance.md`](minimal-api-performance.md) — TypedResults vs IResult allocation, endpoint filter cost, AOT-safe patterns, benchmarks

---

## §9 Security Best Practices (8 questions)

- [x] 🟢 [`https-and-hsts.md`](https-and-hsts.md) — UseHttpsRedirection, UseHsts, HSTS max-age, preloading, reverse-proxy header trust
- [x] 🟢 [`secrets-management.md`](secrets-management.md) — User Secrets (dev), environment variables, Azure Key Vault, IConfiguration providers
- [x] 🟡 [`security-headers.md`](security-headers.md) — CSP, X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, NWebSec, custom middleware
- [x] 🟡 [`input-validation-security.md`](input-validation-security.md) — XSS via HtmlEncoder, mass-assignment protection, [BindProperty] vs [Bind]
- [x] 🟡 [`https-certificate-management.md`](https-certificate-management.md) — Dev certs (dotnet dev-certs), Let's Encrypt, Kestrel cert config, cert hot-reload
- [x] 🔴 [`content-security-policy-advanced.md`](content-security-policy-advanced.md) — CSP directives, nonce-based scripts, violation reporting, SPA/Blazor challenges
- [x] 🔴 [`supply-chain-security.md`](supply-chain-security.md) — dotnet list package --vulnerable, NuGet audit, Dependabot, SBOM generation
- [x] 🔴 [`threat-model-web-api.md`](threat-model-web-api.md) — OWASP API Top 10 in .NET context: broken object auth, mass assignment, SSRF, injection

---

## §10 Testing in ASP.NET Core (9 questions)

- [x] 🟢 [`webapplicationfactory-basics.md`](webapplicationfactory-basics.md) — WebApplicationFactory\<T\>, test server, HttpClient, basic integration test setup
- [x] 🟡 [`integration-test-configuration.md`](integration-test-configuration.md) — WithWebHostBuilder, overriding services/config, test-specific DI, environment override
- [x] 🟡 [`test-authentication.md`](test-authentication.md) — Fake authentication scheme for integration tests, AddAuthentication test handler
- [x] 🟡 [`mocking-httpclient.md`](mocking-httpclient.md) — MockHttpMessageHandler, IHttpClientFactory in tests, WireMock.Net, typed client testing
- [x] 🟡 [`database-in-integration-tests.md`](database-in-integration-tests.md) — In-memory EF vs real DB in tests, Testcontainers for SQL Server/PostgreSQL
- [x] 🟡 [`minimal-api-testing.md`](minimal-api-testing.md) — Testing minimal API endpoints, IResult assertion, TypedResults, route-level unit tests
- [x] 🔴 [`test-isolation-patterns.md`](test-isolation-patterns.md) — Parallel test isolation, database seeding/cleanup, IAsyncLifetime (xUnit), test fixtures
- [x] 🔴 [`contract-testing-aspnet.md`](contract-testing-aspnet.md) — Consumer-driven contracts with Pact, provider verification, CI pipeline integration
- [x] 🔴 [`performance-testing-aspnet.md`](performance-testing-aspnet.md) — k6/BenchmarkDotNet/NBomber for API load testing, latency percentiles, baseline
