# How Do You Generate a Code Coverage Report in .NET?

**Category:** Testing / Code Coverage
**Difficulty:** 🟡 Middle
**Tags:** `Coverlet`, `ReportGenerator`, `code-coverage`, `.NET`, `CI`, `Cobertura`

## Question
> How do you generate a code coverage report in .NET (Coverlet + ReportGenerator)?

## Short Answer
Add the `coverlet.collector` NuGet package, run `dotnet test --collect:"XPlat Code Coverage"` to produce a `coverage.cobertura.xml` file, then use `reportgenerator` to convert it to a human-readable HTML report. Optionally enforce coverage thresholds with `--threshold` flags.

## Detailed Explanation

### Step 1: Add Coverlet to the Test Project
```shell
dotnet add package coverlet.collector
```
Or in `csproj`:
```xml
<PackageReference Include="coverlet.collector" Version="6.*" PrivateAssets="all" />
```

### Step 2: Run Tests and Collect Coverage
```shell
dotnet test --collect:"XPlat Code Coverage"
```
Output is written to `TestResults/<guid>/coverage.cobertura.xml`.

To specify the output directory:
```shell
dotnet test --collect:"XPlat Code Coverage" \
  --results-directory ./coverage
```

To change the output format (e.g., OpenCover, LCOV):
```shell
dotnet test --collect:"XPlat Code Coverage" \
  -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=opencover
```

### Step 3: Install ReportGenerator
```shell
dotnet tool install -g dotnet-reportgenerator-globaltool
```

Or as a local tool:
```shell
dotnet tool install dotnet-reportgenerator-globaltool
dotnet tool restore
```

### Step 4: Generate HTML Report
```shell
reportgenerator \
  -reports:"coverage/**/coverage.cobertura.xml" \
  -targetdir:"coverage-report" \
  -reporttypes:Html
```

Open `coverage-report/index.html` in a browser.

### Step 5: Enforce Thresholds in CI
```shell
dotnet test --collect:"XPlat Code Coverage" \
  -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Threshold=80 \
     DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.ThresholdType=line
```

Or with the `coverlet.msbuild` package:
```shell
dotnet test /p:CollectCoverage=true \
            /p:CoverletOutputFormat=cobertura \
            /p:Threshold=80 \
            /p:ThresholdType=branch
```

### Excluding Auto-Generated Code
Annotate with `[ExcludeFromCodeCoverage]` or use exclusion filters:
```shell
/p:Exclude="[*.Migrations]*,[*.Designer]*"
```

### CI (GitHub Actions) Example
```yaml
- name: Test with coverage
  run: |
    dotnet test --collect:"XPlat Code Coverage" --results-directory ./coverage

- name: Generate coverage report
  run: |
    dotnet tool install -g dotnet-reportgenerator-globaltool
    reportgenerator -reports:"coverage/**/coverage.cobertura.xml" \
                    -targetdir:"coverage-report" \
                    -reporttypes:Html

- name: Upload report
  uses: actions/upload-artifact@v4
  with:
    name: coverage-report
    path: coverage-report/
```

## Code Example
```shell
# Full workflow in one script
dotnet add YourProject.Tests package coverlet.collector

dotnet test YourProject.Tests \
  --collect:"XPlat Code Coverage" \
  --results-directory ./coverage/

dotnet tool install -g dotnet-reportgenerator-globaltool

reportgenerator \
  -reports:"./coverage/**/coverage.cobertura.xml" \
  -targetdir:"./coverage-report" \
  -reporttypes:"Html;Badges"

# Open the report (macOS / Linux)
open ./coverage-report/index.html
```

## Common Follow-up Questions
- What is the difference between `coverlet.collector` and `coverlet.msbuild`?
- How do you enforce minimum coverage thresholds in a CI pipeline?
- How do you exclude specific classes or namespaces from coverage?
- How do you merge multiple coverage files when running tests across multiple projects?
- What is the difference between Cobertura, OpenCover, and LCOV formats?

## Common Mistakes / Pitfalls
- **Forgetting `--results-directory`** — without it, results are placed inside `bin/Debug/` in a GUID-named folder, making them hard to find.
- **Not excluding generated code** — EF migrations and similar files inflate uncovered line counts.
- **Running `reportgenerator` before `dotnet test` finishes** — the XML file must exist first.
- **Checking in the `coverage-report/` folder** — add it to `.gitignore`.

## References
- [Coverlet GitHub](https://github.com/coverlet-coverage/coverlet)
- [ReportGenerator GitHub](https://github.com/danielpalme/ReportGenerator)
- [Microsoft Learn — Code coverage with Coverlet](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-code-coverage)
- [ReportGenerator documentation](https://reportgenerator.io/)
