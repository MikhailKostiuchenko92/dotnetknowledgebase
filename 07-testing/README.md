# Testing

> xUnit, NUnit, Moq, NSubstitute, integration & E2E testing.

## Questions

## Index

### 1. Unit Testing Fundamentals
- [What is a unit test and how does it differ from an integration test?](what-is-a-unit-test.md) 🟢
- [What is the AAA (Arrange–Act–Assert) pattern and why is it important?](aaa-pattern.md) 🟢
- [What makes a "good" unit test? (FIRST criteria)](good-unit-test-first-criteria.md) 🟢
- [What is test isolation and why does it matter?](test-isolation.md) 🟢
- [What is the difference between a unit test, integration test, and end-to-end test?](unit-vs-integration-vs-e2e.md) 🟡
- [What is the testing pyramid and how should you distribute tests across layers?](testing-pyramid.md) 🟡
- [What is a test fixture and how is it used?](test-fixture.md) 🟡
- [What is the difference between state-based and interaction-based testing?](state-vs-interaction-testing.md) 🟡
- [How do you decide what NOT to test?](what-not-to-test.md) 🔴
- [What are "test smells" and can you name common ones?](test-smells.md) 🔴

### 2. xUnit
- [What attributes does xUnit use to mark test methods?](xunit-fact-theory-attributes.md) 🟢
- [What is the difference between `[Fact]` and `[Theory]`?](xunit-fact-vs-theory.md) 🟢
- [How do you pass parameters to a `[Theory]` using `[InlineData]`?](xunit-inlinedata.md) 🟢
- [How does xUnit handle test class instantiation (new instance per test)?](xunit-test-class-instantiation.md) 🟡
- [What is `IClassFixture<T>` and when would you use it?](xunit-iclassfixture.md) 🟡
- [What is `ICollectionFixture<T>` and how does it differ from `IClassFixture<T>`?](xunit-icollectionfixture.md) 🟡
- [How do you use `[MemberData]` and `[ClassData]` for complex theory data?](xunit-memberdata-classdata.md) 🟡
- [How do you skip a test in xUnit?](xunit-skip-test.md) 🟡
- [How do you categorize/filter tests using traits in xUnit?](xunit-traits.md) 🟡
- [How do you implement custom `ITestOutputHelper` logging in xUnit?](xunit-itestoutputhelper.md) 🔴
- [How do you write async tests in xUnit and what pitfalls exist?](xunit-async-tests.md) 🔴
- [How do xUnit's `IAsyncLifetime` and `IAsyncDisposable` work for async setup/teardown?](xunit-iasynclifetime.md) 🔴

### 3. NUnit
- [What attributes does NUnit use for test discovery?](nunit-test-attributes.md) 🟢
- [What are `[SetUp]` and `[TearDown]` in NUnit?](nunit-setup-teardown.md) 🟢
- [What is `[TestCase]` and how does it relate to xUnit's `[InlineData]`?](nunit-testcase.md) 🟢
- [What is the difference between `[SetUp]`/`[TearDown]` and `[OneTimeSetUp]`/`[OneTimeTearDown]`?](nunit-setup-vs-onetimesetup.md) 🟡
- [How does NUnit's `Assert.That` constraint model work compared to classic `Assert.*`?](nunit-assert-that.md) 🟡
- [What is `[TestCaseSource]` and when would you use it?](nunit-testcasesource.md) 🟡
- [How do you run parameterized tests with `[Values]` and `[Range]` in NUnit?](nunit-values-range.md) 🟡
- [How does NUnit handle parallel test execution and what risks does it introduce?](nunit-parallel-execution.md) 🔴
- [What is NUnit's `[Retry]` attribute and when is it appropriate vs. a code smell?](nunit-retry-attribute.md) 🔴

### 4. MSTest
- [What attributes does MSTest use (`[TestClass]`, `[TestMethod]`, `[DataRow]`)?](mstest-attributes.md) 🟢
- [How do `[TestInitialize]` and `[ClassInitialize]` differ in MSTest?](mstest-initialize-vs-classinitialize.md) 🟡
- [How do you use `[DataTestMethod]` with `[DataRow]` in MSTest v2?](mstest-datatestmethod.md) 🟡
- [What are the key differences between MSTest, xUnit, and NUnit?](mstest-vs-xunit-vs-nunit.md) 🟡

### 5. Mocking & Test Doubles
- [What is a test double and what are the different types?](test-doubles.md) 🟢
- [What is the difference between a stub and a mock?](stub-vs-mock.md) 🟢
- [How do you create a basic mock with Moq?](moq-basic-mock.md) 🟢
- [How do you set up a method return value with `Setup` and `Returns` in Moq?](moq-setup-returns.md) 🟡
- [How do you verify a method was called using `Verify` in Moq?](moq-verify.md) 🟡
- [What is `It.IsAny<T>()` and when would you use argument matchers?](moq-argument-matchers.md) 🟡
- [What is `MockBehavior.Strict` vs `MockBehavior.Loose` in Moq?](moq-strict-vs-loose.md) 🟡
- [How do you mock async methods (returning `Task`) with Moq?](moq-async-methods.md) 🟡
- [How do you mock properties with Moq?](moq-properties.md) 🟡
- [How do you set up a mock to throw an exception?](moq-throw-exception.md) 🟡
- [What is `SetupSequence` in Moq and when is it useful?](moq-setup-sequence.md) 🟡
- [How do you mock `HttpClient` for unit testing?](moq-httpclient.md) 🟡
- [What is `Mock.Of<T>()` and how does it differ from `new Mock<T>()`?](moq-mock-of.md) 🔴
- [How do you mock protected members in Moq?](moq-protected-members.md) 🔴
- [What are the limitations of Moq (can't mock static/non-virtual/sealed)?](moq-limitations.md) 🔴
- [How does NSubstitute differ from Moq in terms of API design and philosophy?](nsubstitute-vs-moq.md) 🔴
- [What is `AutoMock` / `AutoFixture` and how does it reduce mock boilerplate?](automock-autofixture.md) 🔴

### 6. Assertion Libraries
- [What does FluentAssertions provide over xUnit's built-in `Assert`?](fluent-assertions-overview.md) 🟢
- [How do you assert on collections with FluentAssertions?](fluent-assertions-collections.md) 🟡
- [How do you assert on exceptions with FluentAssertions?](fluent-assertions-exceptions.md) 🟡
- [How do you assert on async methods that throw with FluentAssertions?](fluent-assertions-async-exceptions.md) 🟡
- [What is `AssertionScope` in FluentAssertions and why is it useful?](fluent-assertions-assertion-scope.md) 🟡
- [What is Shouldly and how does it compare to FluentAssertions?](shouldly-vs-fluent-assertions.md) 🟡
- [How do you write custom FluentAssertions extensions?](fluent-assertions-custom-extensions.md) 🔴

### 7. Test Design & Best Practices
- [What does the acronym F.I.R.S.T stand for in unit testing?](first-criteria.md) 🟢
- [What is the Single Assert / Single Concept principle in unit tests?](single-assert-principle.md) 🟡
- [What is the "test data builder" pattern and when is it useful?](test-data-builder.md) 🟡
- [How should you name test methods?](test-naming-conventions.md) 🟡
- [What is the Arrange-Act-Assert vs. Given-When-Then naming convention?](aaa-vs-given-when-then.md) 🟡
- [How do you handle shared test setup without creating hidden coupling between tests?](shared-test-setup.md) 🟡
- [What is an Object Mother pattern and how does it differ from a Test Data Builder?](object-mother-pattern.md) 🟡
- [What is the "test isolation vs. test speed" trade-off and how do you balance it?](test-isolation-vs-speed.md) 🔴
- [How do you test code that uses `DateTime.Now` or `Guid.NewGuid()`?](testing-nondeterministic-dependencies.md) 🔴
- [When is it appropriate to use a fake vs. a mock?](fake-vs-mock.md) 🔴
- [What are the dangers of over-mocking and how do you know when you've mocked too much?](over-mocking.md) 🔴

### 8. Integration Testing in ASP.NET Core
- [What is `WebApplicationFactory<TEntryPoint>` and what does it enable?](webapplicationfactory.md) 🟢
- [How do you use `WebApplicationFactory` to spin up an in-process test server?](webapplicationfactory.md) 🟢
- [How do you override services in `WebApplicationFactory`?](webapplicationfactory-services.md) 🟡
- [How do you send HTTP requests and assert responses in integration tests?](integration-tests-http.md) 🟡
- [How do you handle authentication/authorization in integration tests?](integration-tests-auth.md) 🟡
- [What is the `TestServer` class and how does it relate to `WebApplicationFactory`?](testserver.md) 🟡
- [How do you share a single `WebApplicationFactory` instance across an entire test collection?](webapplicationfactory-collection.md) 🔴
- [How do you test middleware in isolation vs. as part of the full pipeline?](testing-middleware.md) 🔴
- [How do you seed a test database and reset state between integration test runs?](seed-and-reset-database.md) 🔴
- [In-process integration tests vs. spinning up a real container (Testcontainers)?](testcontainers-vs-inmemory.md) 🔴

### 9. EF Core Testing
- [What is the EF Core in-memory database provider and what is it useful for?](ef-core-inmemory.md) 🟢
- [What are the limitations of the EF Core in-memory provider?](ef-core-inmemory-limitations.md) 🟡
- [How do you use SQLite in-memory mode for EF Core tests to get closer to real SQL behavior?](ef-core-sqlite-inmemory.md) 🟡
- [How do you test a repository class that depends on `DbContext`?](ef-core-repository-testing.md) 🟡
- [Should you mock `DbContext` directly? What problems does that cause?](ef-core-mock-dbcontext.md) 🟡
- [What is Respawn and how does it help with EF Core integration test database reset?](respawn.md) 🔴
- [How do you use Testcontainers for .NET to run a real PostgreSQL/SQL Server in integration tests?](testcontainers-dotnet.md) 🔴
- [How do you test EF Core migrations (ensure they apply cleanly)?](ef-core-migration-testing.md) 🔴

### 10. Testing Async Code
- [How do you write an async unit test in xUnit/NUnit?](async-unit-tests.md) 🟢
- [What is the danger of `async void` in test methods?](async-void-danger.md) 🟡
- [How do you test a method that uses `CancellationToken`?](testing-cancellation-token.md) 🟡
- [How do you test a method that uses `Task.Delay` or time-based logic?](testing-task-delay.md) 🟡
- [How do you test code that uses `Channel<T>` or `IAsyncEnumerable<T>`?](testing-channel-asyncenumerable.md) 🔴
- [What is `FakeTimeProvider` and how does it solve time-dependent test problems?](fake-time-provider.md) 🔴

### 11. Code Coverage
- [What is code coverage and what does line/statement coverage measure?](code-coverage-overview.md) 🟢
- [What is the difference between line coverage, branch coverage, and path coverage?](coverage-line-vs-branch-vs-path.md) 🟡
- [How do you generate a code coverage report in .NET (Coverlet + ReportGenerator)?](coverlet-reportgenerator.md) 🟡
- [What coverage percentage should you aim for and why is 100% not always meaningful?](coverage-target-percentage.md) 🟡
- [What is mutation testing and how does it reveal weaknesses that code coverage misses?](mutation-testing.md) 🔴
- [What is Stryker.NET and how do you interpret its mutation score?](stryker-net.md) 🔴

### 12. TDD (Test-Driven Development)
- [What are the three steps of TDD (Red–Green–Refactor)?](tdd-red-green-refactor.md) 🟢
- [What is the "Outside-In" (London School) TDD style vs. "Inside-Out" (Chicago School)?](tdd-outside-in-vs-inside-out.md) 🟡
- [What is the practical benefit of writing a failing test before the implementation?](tdd-test-first-benefit.md) 🟡
- [What are common objections to TDD and how do you address them?](tdd-objections.md) 🟡
- [When is TDD impractical or counterproductive (e.g., exploratory code, spike solutions)?](tdd-when-impractical.md) 🔴
- [How do you apply TDD when working with a legacy codebase?](tdd-legacy-codebase.md) 🔴

### 13. BDD & Specification Testing
- [What is BDD (Behavior-Driven Development) and how does it differ from TDD?](bdd-vs-tdd.md) 🟡
- [What is SpecFlow and how does it map Gherkin feature files to .NET test code?](specflow-reqnroll.md) 🟡
- [What is the Given-When-Then structure in BDD scenarios?](given-when-then.md) 🟡
- [What are the pros and cons of BDD tools (SpecFlow / Reqnroll) in a .NET project?](bdd-pros-cons.md) 🔴
- [How do you keep BDD scenarios readable while keeping step definitions maintainable?](bdd-maintainable-steps.md) 🔴

### 14. Performance & Load Testing
- [What is BenchmarkDotNet and what kind of questions does it answer?](benchmarkdotnet-overview.md) 🟡
- [How do you write a simple benchmark with BenchmarkDotNet?](benchmarkdotnet-writing.md) 🟡
- [What are common sources of benchmark inaccuracy?](benchmarking-pitfalls.md) 🟡
- [What is NBomber and how does it differ from BenchmarkDotNet?](nbomber-overview.md) 🟡
- [What is k6 and when would you choose it over NBomber for .NET services?](k6-load-testing.md) 🔴
- [How do you profile memory allocations in a benchmark to detect excessive allocations?](benchmarking-memory-profiling.md) 🔴

### 15. Advanced & Cross-Cutting Topics
- [What is snapshot testing and when is it useful for .NET code?](snapshot-testing.md) 🟡
- [What is contract testing and how does Pact.NET enable consumer-driven contract testing?](pact-net-contract-testing.md) 🟡
- [How do you test background services (`IHostedService`, `BackgroundService`) in .NET?](testing-background-services.md) 🟡
- [How do you test code that publishes/consumes messages (e.g., via MediatR, RabbitMQ)?](testing-messaging-mediatr.md) 🟡
- [What is Approval Tests and how does it differ from traditional assertion testing?](approval-tests.md) 🔴
- [How do you test Minimal API endpoints without a full integration test?](testing-minimal-apis.md) 🔴
- [How do you test gRPC services in .NET?](testing-grpc-services.md) 🔴
- [What is the Humble Object pattern and how does it make untestable code testable?](humble-object-pattern.md) 🔴
- [How do you approach testing in a CQRS architecture (handlers, queries, commands)?](testing-cqrs.md) 🔴
- [How do you test a SignalR hub?](testing-signalr-hub.md) 🔴