# 07-testing — Question Backlog

> **Target:** 110 questions · ~20% 🟢 / ~45% 🟡 / ~35% 🔴
> Generated: 2026-05-30

Legend: 🟢 Junior · 🟡 Middle · 🔴 Senior | `[ ]` todo · `[x]` done

---

## 1. Unit Testing Fundamentals

- [x] 🟢 [What is a unit test and how does it differ from an integration test?](what-is-a-unit-test.md)
- [x] 🟢 [What is the AAA (Arrange–Act–Assert) pattern and why is it important?](aaa-pattern.md)
- [x] 🟢 [What makes a "good" unit test? (FIRST criteria)](good-unit-test-first-criteria.md)
- [x] 🟢 [What is test isolation and why does it matter?](test-isolation.md)
- [x] 🟡 [What is the difference between a unit test, integration test, and end-to-end test?](unit-vs-integration-vs-e2e.md)
- [x] 🟡 [What is the testing pyramid and how should you distribute tests across layers?](testing-pyramid.md)
- [x] 🟡 [What is a test fixture and how is it used?](test-fixture.md)
- [x] 🟡 [What is the difference between state-based and interaction-based testing?](state-vs-interaction-testing.md)
- [x] 🔴 [How do you decide what NOT to test?](what-not-to-test.md)
- [x] 🔴 [What are "test smells" and can you name common ones (e.g., Mystery Guest, Eager Test, Logic in Tests)?](test-smells.md)

---

## 2. xUnit

- [x] 🟢 [What attributes does xUnit use to mark test methods (`[Fact]`, `[Theory]`)?](xunit-fact-theory-attributes.md)
- [x] 🟢 [What is the difference between `[Fact]` and `[Theory]` in xUnit?](xunit-fact-vs-theory.md)
- [x] 🟢 [How do you pass parameters to a `[Theory]` using `[InlineData]`?](xunit-inlinedata.md)
- [x] 🟡 [How does xUnit handle test class instantiation (new instance per test)?](xunit-test-class-instantiation.md)
- [x] 🟡 [What is `IClassFixture<T>` and when would you use it?](xunit-iclassfixture.md)
- [x] 🟡 [What is `ICollectionFixture<T>` and how does it differ from `IClassFixture<T>`?](xunit-icollectionfixture.md)
- [x] 🟡 [How do you use `[MemberData]` and `[ClassData]` for complex theory data?](xunit-memberdata-classdata.md)
- [x] 🟡 [How do you skip a test in xUnit?](xunit-skip-test.md)
- [x] 🟡 [How do you categorize/filter tests using traits in xUnit?](xunit-traits.md)
- [x] 🔴 [How do you implement custom `ITestOutputHelper` logging in xUnit?](xunit-itestoutputhelper.md)
- [x] 🔴 [How do you write async tests in xUnit and what pitfalls exist?](xunit-async-tests.md)
- [x] 🔴 [How do xUnit's `IAsyncLifetime` and `IAsyncDisposable` work for async setup/teardown?](xunit-iasynclifetime.md)

---

## 3. NUnit

- [x] 🟢 [What attributes does NUnit use for test discovery (`[Test]`, `[TestFixture]`)?](nunit-test-attributes.md)
- [x] 🟢 [What are `[SetUp]` and `[TearDown]` in NUnit?](nunit-setup-teardown.md)
- [x] 🟢 [What is `[TestCase]` and how does it relate to xUnit's `[InlineData]`?](nunit-testcase.md)
- [x] 🟡 [What is the difference between `[SetUp]`/`[TearDown]` and `[OneTimeSetUp]`/`[OneTimeTearDown]`?](nunit-setup-vs-onetimesetup.md)
- [x] 🟡 [How does NUnit's `Assert.That` constraint model work compared to classic `Assert.*`?](nunit-assert-that.md)
- [x] 🟡 [What is `[TestCaseSource]` and when would you use it?](nunit-testcasesource.md)
- [x] 🟡 [How do you run parameterized tests with `[Values]` and `[Range]` attributes in NUnit?](nunit-values-range.md)
- [x] 🔴 [How does NUnit handle parallel test execution and what risks does it introduce?](nunit-parallel-execution.md)
- [x] 🔴 [What is NUnit's `[Retry]` attribute and when is using it appropriate vs. a code smell?](nunit-retry-attribute.md)

---

## 4. MSTest

- [x] 🟢 [What attributes does MSTest use (`[TestClass]`, `[TestMethod]`, `[DataRow]`)?](mstest-attributes.md)
- [x] 🟡 [How do `[TestInitialize]` and `[ClassInitialize]` differ in MSTest?](mstest-initialize-vs-classinitialize.md)
- [x] 🟡 [How do you use `[DataTestMethod]` with `[DataRow]` in MSTest v2?](mstest-datatestmethod.md)
- [x] 🟡 [What are the key differences between MSTest, xUnit, and NUnit? When would you choose each?](mstest-vs-xunit-vs-nunit.md)

---

## 5. Mocking & Test Doubles

- [x] 🟢 [What is a test double and what are the different types (dummy, stub, spy, mock, fake)?](test-doubles.md)
- [x] 🟢 [What is the difference between a stub and a mock?](stub-vs-mock.md)
- [x] 🟢 [How do you create a basic mock with Moq?](moq-basic-mock.md)
- [x] 🟡 [How do you set up a method return value with `Setup` and `Returns` in Moq?](moq-setup-returns.md)
- [x] 🟡 [How do you verify a method was called using `Verify` in Moq?](moq-verify.md)
- [x] 🟡 [What is `It.IsAny<T>()` and when would you use argument matchers?](moq-argument-matchers.md)
- [x] 🟡 [What is `MockBehavior.Strict` vs `MockBehavior.Loose` in Moq?](moq-strict-vs-loose.md)
- [x] 🟡 [How do you mock async methods (returning `Task`) with Moq?](moq-async-methods.md)
- [x] 🟡 [How do you mock properties with Moq?](moq-properties.md)
- [x] 🟡 [How do you set up a mock to throw an exception?](moq-throw-exception.md)
- [x] 🟡 [What is `SetupSequence` in Moq and when is it useful?](moq-setup-sequence.md)
- [x] 🟡 [How do you mock `HttpClient` for unit testing?](moq-httpclient.md)
- [x] 🔴 [What is `Mock.Of<T>()` and how does it differ from `new Mock<T>()`?](moq-mock-of.md)
- [x] 🔴 [How do you mock protected members in Moq?](moq-protected-members.md)
- [x] 🔴 [What are the limitations of Moq (can't mock static/non-virtual/sealed)?](moq-limitations.md)
- [x] 🔴 [How does NSubstitute differ from Moq in terms of API design and philosophy?](nsubstitute-vs-moq.md)
- [x] 🔴 [What is `AutoMock` / `AutoFixture` and how does it reduce mock boilerplate?](automock-autofixture.md)

---

## 6. Assertion Libraries

- [x] 🟢 [What does FluentAssertions provide over xUnit's built-in `Assert`?](fluent-assertions-overview.md)
- [x] 🟡 [How do you assert on collections with FluentAssertions (e.g., `BeEquivalentTo`, `ContainSingle`)?](fluent-assertions-collections.md)
- [x] 🟡 [How do you assert on exceptions with FluentAssertions?](fluent-assertions-exceptions.md)
- [x] 🟡 [How do you assert on async methods that throw with FluentAssertions?](fluent-assertions-async-exceptions.md)
- [x] 🟡 [What is `AssertionScope` in FluentAssertions and why is it useful?](fluent-assertions-assertion-scope.md)
- [x] 🟡 [What is Shouldly and how does it compare to FluentAssertions?](shouldly-vs-fluent-assertions.md)
- [x] 🔴 [How do you write custom FluentAssertions extensions?](fluent-assertions-custom-extensions.md)

---

## 7. Test Design & Best Practices

- [x] 🟢 [What does the acronym F.I.R.S.T stand for in unit testing?](first-criteria.md)
- [x] 🟡 [What is the Single Assert / Single Concept principle in unit tests?](single-assert-principle.md)
- [x] 🟡 [What is the "test data builder" pattern and when is it useful?](test-data-builder.md)
- [x] 🟡 [How should you name test methods? (e.g., `MethodName_Scenario_ExpectedBehavior`)](test-naming-conventions.md)
- [x] 🟡 [What is the Arrange-Act-Assert vs. Given-When-Then naming convention?](aaa-vs-given-when-then.md)
- [x] 🟡 [How do you handle shared test setup without creating hidden coupling between tests?](shared-test-setup.md)
- [x] 🟡 [What is an Object Mother pattern and how does it differ from a Test Data Builder?](object-mother-pattern.md)
- [x] 🔴 [What is the "test isolation vs. test speed" trade-off and how do you balance it?](test-isolation-vs-speed.md)
- [x] 🔴 [How do you test code that uses `DateTime.Now` or `Guid.NewGuid()` (non-deterministic dependencies)?](testing-nondeterministic-dependencies.md)
- [x] 🔴 [When is it appropriate to use a fake vs. a mock? Discuss with an example.](fake-vs-mock.md)
- [x] 🔴 [What are the dangers of over-mocking and how do you know when you've mocked too much?](over-mocking.md)

---

## 8. Integration Testing in ASP.NET Core

- [x] 🟢 [What is `WebApplicationFactory<TEntryPoint>` and what does it enable?](webapplicationfactory.md)
- [x] 🟡 [How do you use `WebApplicationFactory` to spin up an in-process test server?](webapplicationfactory.md)
- [x] 🟡 [How do you override services (e.g., replace a real DB with an in-memory one) in `WebApplicationFactory`?](webapplicationfactory-services.md)
- [x] 🟡 [How do you send HTTP requests and assert responses in ASP.NET Core integration tests?](integration-tests-http.md)
- [x] 🟡 [How do you handle authentication/authorization in integration tests (e.g., fake JWT)?](integration-tests-auth.md)
- [x] 🟡 [What is the `TestServer` class and how does it relate to `WebApplicationFactory`?](testserver.md)
- [x] 🔴 [How do you share a single `WebApplicationFactory` instance across an entire test collection?](webapplicationfactory-collection.md)
- [x] 🔴 [How do you test middleware in isolation vs. as part of the full pipeline?](testing-middleware.md)
- [x] 🔴 [How do you seed a test database and reset state between integration test runs?](seed-and-reset-database.md)
- [x] 🔴 [What are the trade-offs of in-process integration tests vs. spinning up a real container (Testcontainers)?](testcontainers-vs-inmemory.md)

---

## 9. EF Core Testing

- [x] 🟢 [What is the EF Core in-memory database provider and what is it useful for?](ef-core-inmemory.md)
- [x] 🟡 [What are the limitations of the EF Core in-memory provider (no transactions, no SQL-level constraints)?](ef-core-inmemory-limitations.md)
- [x] 🟡 [How do you use SQLite in-memory mode for EF Core tests to get closer to real SQL behavior?](ef-core-sqlite-inmemory.md)
- [x] 🟡 [How do you test a repository class that depends on `DbContext`?](ef-core-repository-testing.md)
- [x] 🟡 [Should you mock `DbContext` directly? What problems does that cause?](ef-core-mock-dbcontext.md)
- [x] 🔴 [What is Respawn and how does it help with EF Core integration test database reset?](respawn.md)
- [x] 🔴 [How do you use Testcontainers for .NET to run a real PostgreSQL/SQL Server in integration tests?](testcontainers-dotnet.md)
- [x] 🔴 [How do you test EF Core migrations (ensure they apply cleanly)?](ef-core-migration-testing.md)

---

## 10. Testing Async Code

- [x] 🟢 [How do you write an async unit test in xUnit/NUnit?](async-unit-tests.md)
- [x] 🟡 [What is the danger of `async void` in test methods?](async-void-danger.md)
- [x] 🟡 [How do you test a method that uses `CancellationToken`?](testing-cancellation-token.md)
- [x] 🟡 [How do you test a method that uses `Task.Delay` or time-based logic?](testing-task-delay.md)
- [x] 🔴 [How do you test code that uses `Channel<T>` or `IAsyncEnumerable<T>`?](testing-channel-asyncenumerable.md)
- [x] 🔴 [What is `FakeTimeProvider` (from Microsoft.Extensions.TimeProvider.Testing) and how does it solve time-dependent test problems?](fake-time-provider.md)

---

## 11. Code Coverage

- [x] 🟢 [What is code coverage and what does line/statement coverage measure?](code-coverage-overview.md)
- [x] 🟡 [What is the difference between line coverage, branch coverage, and path coverage?](coverage-line-vs-branch-vs-path.md)
- [x] 🟡 [How do you generate a code coverage report in .NET (Coverlet + ReportGenerator)?](coverlet-reportgenerator.md)
- [x] 🟡 [What coverage percentage should you aim for and why is 100% not always meaningful?](coverage-target-percentage.md)
- [x] 🔴 [What is mutation testing and how does it reveal weaknesses that code coverage misses?](mutation-testing.md)
- [x] 🔴 [What is Stryker.NET and how do you interpret its mutation score?](stryker-net.md)

---

## 12. TDD (Test-Driven Development)

- [x] 🟢 [What are the three steps of TDD (Red–Green–Refactor)?](tdd-red-green-refactor.md)
- [x] 🟡 [What is the "Outside-In" (London School) TDD style vs. "Inside-Out" (Chicago School)?](tdd-outside-in-vs-inside-out.md)
- [x] 🟡 [What is the practical benefit of writing a failing test before the implementation?](tdd-test-first-benefit.md)
- [x] 🟡 [What are common objections to TDD and how do you address them?](tdd-objections.md)
- [x] 🔴 [When is TDD impractical or counterproductive (e.g., exploratory code, spike solutions)?](tdd-when-impractical.md)
- [x] 🔴 [How do you apply TDD when working with a legacy codebase?](tdd-legacy-codebase.md)

---

## 13. BDD & Specification Testing

- [x] 🟡 [What is BDD (Behavior-Driven Development) and how does it differ from TDD?](bdd-vs-tdd.md)
- [x] 🟡 [What is SpecFlow and how does it map Gherkin feature files to .NET test code?](specflow-reqnroll.md)
- [x] 🟡 [What is the Given-When-Then structure in BDD scenarios?](given-when-then.md)
- [x] 🔴 [What are the pros and cons of BDD tools (SpecFlow / Reqnroll) in a .NET project?](bdd-pros-cons.md)
- [x] 🔴 [How do you keep BDD scenarios readable for non-technical stakeholders while keeping step definitions maintainable?](bdd-maintainable-steps.md)

---

## 14. Performance & Load Testing

- [x] 🟡 [What is BenchmarkDotNet and what kind of questions does it answer?](benchmarkdotnet-overview.md)
- [x] 🟡 [How do you write a simple benchmark with BenchmarkDotNet?](benchmarkdotnet-writing.md)
- [x] 🟡 [What are common sources of benchmark inaccuracy (JIT warmup, GC pressure, CPU caching)?](benchmarking-pitfalls.md)
- [x] 🟡 [What is NBomber and how does it differ from BenchmarkDotNet?](nbomber-overview.md)
- [x] 🔴 [What is k6 and when would you choose it over NBomber for .NET services?](k6-load-testing.md)
- [x] 🔴 [How do you profile memory allocations in a benchmark to detect excessive allocations?](benchmarking-memory-profiling.md)

---

## 15. Advanced & Cross-Cutting Topics

- [x] 🟡 [What is snapshot testing and when is it useful for .NET code?](snapshot-testing.md)
- [x] 🟡 [What is contract testing and how does Pact.NET enable consumer-driven contract testing?](pact-net-contract-testing.md)
- [x] 🟡 [How do you test background services (`IHostedService`, `BackgroundService`) in .NET?](testing-background-services.md)
- [x] 🟡 [How do you test code that publishes/consumes messages (e.g., via MediatR, RabbitMQ)?](testing-messaging-mediatr.md)
- [x] 🔴 [What is Approval Tests and how does it differ from traditional assertion testing?](approval-tests.md)
- [x] 🔴 [How do you test Minimal API endpoints in ASP.NET Core without a full integration test?](testing-minimal-apis.md)
- [x] 🔴 [How do you test gRPC services in .NET?](testing-grpc-services.md)
- [x] 🔴 [What is the Humble Object pattern and how does it make untestable code testable?](humble-object-pattern.md)
- [x] 🔴 [How do you approach testing in a CQRS architecture (handlers, queries, commands)?](testing-cqrs.md)
- [x] 🔴 [How do you test a SignalR hub?](testing-signalr-hub.md)
