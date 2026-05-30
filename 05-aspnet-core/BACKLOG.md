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

**Total:** 0 / 92
**By difficulty:** 🟢 0/17 · 🟡 0/46 · 🔴 0/29

---

## §1 Hosting & Application Bootstrap (10 questions)

- [ ] 🟢 `webapplication-builder.md` — WebApplication.CreateBuilder, minimal hosting model, Program.cs without Startup
- [ ] 🟢 `environment-configuration.md` — IWebHostEnvironment, ASPNETCORE_ENVIRONMENT, appsettings.{env}.json layering
- [ ] 🟢 `generic-host.md` — IHost, IHostedService, BackgroundService, hosted service lifetime
- [ ] 🟡 `configuration-system.md` — IConfiguration, provider chain (JSON/env/CLI/secrets), IOptions\<T\> binding
- [ ] 🟡 `background-services.md` — BackgroundService, long-running work, graceful stop, scoped DI inside hosted service
- [ ] 🟡 `app-lifecycle.md` — IHostApplicationLifetime, ApplicationStarted/Stopping/Stopped events, graceful shutdown
- [ ] 🟡 `health-checks.md` — IHealthCheck, AddHealthChecks, publisher, readiness vs liveness probe, UI dashboard
- [ ] 🟡 `options-validation.md` — IValidateOptions\<T\>, DataAnnotations on options, ValidateOnStart (.NET 7+), early failure
- [ ] 🔴 `kestrel-configuration.md` — Kestrel limits, HTTPS cert config, HTTP/2, HTTP/3 (QUIC), Unix sockets, IIS in-process
- [ ] 🔴 `startup-filters.md` — IStartupFilter, middleware ordering at startup, use cases vs conventional middleware ordering

---

## §2 Middleware Pipeline (9 questions)

- [ ] 🟢 `middleware-pipeline-fundamentals.md` — Use/Run/Map, request delegate chain, short-circuiting, order matters
- [ ] 🟢 `built-in-middleware-overview.md` — StaticFiles, Routing, Authentication, Authorization, CORS, HTTPS, Exception
- [ ] 🟡 `writing-custom-middleware.md` — IMiddleware vs convention-based middleware, InvokeAsync, DI in middleware
- [ ] 🟡 `middleware-vs-filters.md` — What each has access to, HttpContext vs ActionContext, which to choose when
- [ ] 🟡 `use-when-map-branching.md` — UseWhen vs MapWhen vs Map, conditional branching, path-based split
- [ ] 🟡 `exception-handling-middleware.md` — UseExceptionHandler, IExceptionHandler chain (.NET 8), ProblemDetails integration
- [ ] 🟡 `cors-middleware.md` — CORS policy, AddCors/UseCors, AllowSpecificOrigins, preflight OPTIONS, credentials
- [ ] 🟡 `request-response-pipeline.md` — HttpContext lifetime, request/response body buffering, HttpRequest/Response APIs
- [ ] 🔴 `middleware-pipeline-internals.md` — Middleware compilation into RequestDelegate chain, ApplicationBuilder internals, branching cost

---

## §3 Dependency Injection (10 questions)

- [ ] 🟢 `di-fundamentals.md` — Service registration (AddSingleton/Scoped/Transient), constructor injection, IServiceProvider
- [ ] 🟢 `service-lifetimes.md` — Singleton vs Scoped vs Transient semantics, when to use each, scope validation
- [ ] 🟡 `ioptions-lifetimes.md` — IOptions\<T\> vs IOptionsSnapshot\<T\> vs IOptionsMonitor\<T\>, named options, reloading
- [ ] 🟡 `keyed-services.md` — Keyed DI (.NET 8+), [FromKeyedServices], named service resolution, vs factory pattern
- [ ] 🟡 `open-generic-di-registration.md` — Open-generic registration, typeof(IRepository\<\>), conditional registration
- [ ] 🟡 `factory-registration-di.md` — Func\<T\> factory delegate, IServiceProvider factory, lazy resolution
- [ ] 🟡 `di-with-hosted-services.md` — Scoped services inside BackgroundService, IServiceScopeFactory pattern, disposal
- [ ] 🔴 `scoped-in-singleton-pitfall.md` — Captive dependency anti-pattern, ValidateScopes, BuildServiceProvider(true)
- [ ] 🔴 `service-scope-factory.md` — IServiceScopeFactory, creating scopes manually, async scope management, disposal
- [ ] 🔴 `scrutor-and-decorator-di.md` — Scrutor Decorate/Scan, assembly scanning conventions, open-generic decoration

---

## §4 Routing & Model Binding (10 questions)

- [ ] 🟢 `routing-fundamentals.md` — Conventional vs attribute routing, route templates, constraints, route order
- [ ] 🟢 `action-results.md` — IActionResult, IResult, TypedResults (minimal API), status code helpers, negotiation
- [ ] 🟡 `minimal-api-routing.md` — MapGet/Post/Put/Delete, RouteGroupBuilder, endpoint metadata, IEndpointRouteBuilder
- [ ] 🟡 `model-binding-pipeline.md` — [FromBody]/[FromQuery]/[FromRoute]/[FromHeader]/[FromForm], binding order
- [ ] 🟡 `model-validation.md` — DataAnnotations, [ApiController] auto-400, ModelState, FluentValidation integration
- [ ] 🟡 `parameter-binding-minimal-api.md` — Minimal API special binding: IFormFile, HttpContext, CancellationToken, IBindableFromHttpContext
- [ ] 🟡 `problem-details-integration.md` — IProblemDetailsFactory, ValidationProblemDetails, RFC 9457, custom extensions
- [ ] 🟡 `content-negotiation.md` — Accept header, IOutputFormatter, adding XML support, custom formatters
- [ ] 🔴 `custom-model-binder.md` — IModelBinder, IModelBinderProvider, binding from custom sources, composites
- [ ] 🔴 `endpoint-filters.md` — IEndpointFilter (.NET 7+), minimal API filter pipeline, vs action filters, factory pattern

---

## §5 Filters & Action Pipeline (7 questions)

- [ ] 🟢 `filters-overview.md` — Filter types (Authorization/Resource/Action/Exception/Result), execution order, pipeline diagram
- [ ] 🟡 `action-filters.md` — IActionFilter/IAsyncActionFilter, OnActionExecuting/Executed, modifying args/result
- [ ] 🟡 `exception-filters.md` — IExceptionFilter, global exception filter, vs UseExceptionHandler middleware
- [ ] 🟡 `result-filters.md` — IResultFilter, modifying response before write, content-negotiation hook
- [ ] 🟡 `filter-di-and-registration.md` — TypeFilterAttribute, ServiceFilterAttribute, global filters via AddMvc
- [ ] 🔴 `resource-filters.md` — IResourceFilter, short-circuit before model binding, short-circuit caching use case
- [ ] 🔴 `filter-ordering-and-scope.md` — Filter execution order, IOrderedFilter, controller vs action scope, override filter

---

## §6 Web API Design (9 questions)

- [ ] 🟢 `controller-vs-minimal-api.md` — When to choose controllers vs minimal APIs, feature parity, code organisation
- [ ] 🟡 `api-controller-attribute.md` — [ApiController] auto-features: binding inference, auto-400, problem details
- [ ] 🟡 `versioning-aspnet-core.md` — Asp.Versioning, URL/header/query strategies, version sets, deprecated versions, Swagger
- [ ] 🟡 `openapi-in-aspnet-core.md` — Swashbuckle vs NSwag vs Microsoft.AspNetCore.OpenApi (.NET 9), Scalar UI
- [ ] 🟡 `response-caching.md` — [ResponseCache], Cache-Control/Vary headers, IResponseCachePolicy, CDN interaction
- [ ] 🟡 `http-client-factory.md` — IHttpClientFactory, named/typed clients, handler lifetime, Polly/resilience integration
- [ ] 🔴 `grpc-in-aspnet-core.md` — Grpc.AspNetCore, Protobuf codegen, HTTP/2 requirement, transcoding, gRPC-Web
- [ ] 🔴 `rate-limiting.md` — RateLimiter middleware (.NET 7+), fixed/sliding/token-bucket/concurrency limiters, partitioned
- [ ] 🔴 `output-caching.md` — IOutputCacheStore (.NET 7+), cache policies, vary-by, tag-based eviction, vs response caching

---

## §7 Authentication & Authorization (12 questions)

- [ ] 🟢 `authentication-fundamentals.md` — Authentication vs authorisation, IAuthenticationService, scheme, challenge, forbid
- [ ] 🟢 `jwt-authentication.md` — AddJwtBearer, TokenValidationParameters, issuer/audience/key validation, bearer scheme
- [ ] 🟡 `cookie-authentication.md` — Cookie auth handler, sliding expiration, data protection keys, SameSite, anti-forgery
- [ ] 🔴 `oauth2-and-oidc.md` — OAuth2 flows, OpenID Connect, AddOpenIdConnect, PKCE, token storage in ASP.NET Core
- [ ] 🟡 `authorization-policies.md` — AddAuthorization, policy builder, RequireClaim/Role/AuthenticatedUser, [Authorize(Policy)]
- [ ] 🔴 `claims-transformation.md` — IClaimsTransformation, enriching claims post-authentication, multi-tenant identity
- [ ] 🟡 `asp-net-core-identity.md` — UserManager\<T\>, SignInManager\<T\>, RoleManager\<T\>, custom stores, password hashing
- [ ] 🟡 `anti-forgery.md` — CSRF protection, IAntiforgery, [ValidateAntiForgeryToken], SameSite cookies, SPA handling
- [ ] 🟡 `api-key-authentication.md` — Custom AuthenticationHandler\<T\>, API key scheme, [ApiKey] attribute pattern
- [ ] 🔴 `resource-based-authorization.md` — IAuthorizationService.AuthorizeAsync, IAuthorizationRequirement, IAuthorizationHandler
- [ ] 🔴 `data-protection-api.md` — IDataProtector, purpose strings, IDataProtectionProvider, key ring storage, key rotation
- [ ] 🔴 `microsoft-identity-platform.md` — MSAL, AddMicrosoftIdentityWebApi, Azure AD/B2C, on-behalf-of flow, token caching

---

## §8 Performance & Diagnostics (8 questions)

- [ ] 🟢 `logging-in-aspnet-core.md` — ILogger\<T\>, log levels, category, structured logging, Serilog/NLog provider wiring
- [ ] 🟡 `response-compression.md` — AddResponseCompression, Brotli/Gzip providers, compression for APIs, chunked encoding
- [ ] 🔴 `distributed-caching.md` — IDistributedCache, AddStackExchangeRedisCache, cache-aside, sliding vs absolute expiry
- [ ] 🔴 `signalr-overview.md` — Hub, client methods, groups, IHubContext, backplane (Redis), connection lifecycle
- [ ] 🟡 `minimal-api-source-gen.md` — RequestDelegateGenerator (.NET 8+), source-generated endpoint handlers, AOT compatibility
- [ ] 🔴 `aspnet-core-metrics.md` — Built-in meters (Microsoft.AspNetCore.Hosting), kestrel/routing/http meters, OTEL export
- [ ] 🔴 `request-tracing.md` — Activity per request, DiagnosticSource events, OTEL sampling, correlation IDs, baggage
- [ ] 🔴 `minimal-api-performance.md` — TypedResults vs IResult allocation, endpoint filter cost, AOT-safe patterns, benchmarks

---

## §9 Security Best Practices (8 questions)

- [ ] 🟢 `https-and-hsts.md` — UseHttpsRedirection, UseHsts, HSTS max-age, preloading, reverse-proxy header trust
- [ ] 🟢 `secrets-management.md` — User Secrets (dev), environment variables, Azure Key Vault, IConfiguration providers
- [ ] 🟡 `security-headers.md` — CSP, X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, NWebSec, custom middleware
- [ ] 🟡 `input-validation-security.md` — XSS via HtmlEncoder, mass-assignment protection, [BindProperty] vs [Bind]
- [ ] 🟡 `https-certificate-management.md` — Dev certs (dotnet dev-certs), Let's Encrypt, Kestrel cert config, cert hot-reload
- [ ] 🔴 `content-security-policy-advanced.md` — CSP directives, nonce-based scripts, violation reporting, SPA/Blazor challenges
- [ ] 🔴 `supply-chain-security.md` — dotnet list package --vulnerable, NuGet audit, Dependabot, SBOM generation
- [ ] 🔴 `threat-model-web-api.md` — OWASP API Top 10 in .NET context: broken object auth, mass assignment, SSRF, injection

---

## §10 Testing in ASP.NET Core (9 questions)

- [ ] 🟢 `webapplicationfactory-basics.md` — WebApplicationFactory\<T\>, test server, HttpClient, basic integration test setup
- [ ] 🟡 `integration-test-configuration.md` — WithWebHostBuilder, overriding services/config, test-specific DI, environment override
- [ ] 🟡 `test-authentication.md` — Fake authentication scheme for integration tests, AddAuthentication test handler
- [ ] 🟡 `mocking-httpclient.md` — MockHttpMessageHandler, IHttpClientFactory in tests, WireMock.Net, typed client testing
- [ ] 🟡 `database-in-integration-tests.md` — In-memory EF vs real DB in tests, Testcontainers for SQL Server/PostgreSQL
- [ ] 🟡 `minimal-api-testing.md` — Testing minimal API endpoints, IResult assertion, TypedResults, route-level unit tests
- [ ] 🔴 `test-isolation-patterns.md` — Parallel test isolation, database seeding/cleanup, IAsyncLifetime (xUnit), test fixtures
- [ ] 🔴 `contract-testing-aspnet.md` — Consumer-driven contracts with Pact, provider verification, CI pipeline integration
- [ ] 🔴 `performance-testing-aspnet.md` — k6/BenchmarkDotNet/NBomber for API load testing, latency percentiles, baseline
