<#
.SYNOPSIS
    Scaffolds the full folder structure for the .NET Interview Preparation repo.

.DESCRIPTION
    Creates all 11 section folders with placeholder README.md files,
    the _templates folder with three Markdown templates, and a .gitignore.
    Safe to re-run: existing files are skipped, not overwritten.

.EXAMPLE
    # From the root of your dotnet-interview-prep folder:
    .\bootstrap.ps1

.NOTES
    If you get an execution policy error, run once in the same PowerShell session:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ---- Pretty output helpers ---------------------------------------------------
function Write-Info { param([string]$Msg) Write-Host "i  $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "OK $Msg" -ForegroundColor Green }
function Write-Skip { param([string]$Msg) Write-Host ".. $Msg" -ForegroundColor Yellow }

# ---- Helpers -----------------------------------------------------------------
function New-DirectorySafe {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path -PathType Container) {
        Write-Skip "exists:  $Path\"
    }
    else {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Ok "created: $Path\"
    }
}

function New-FileSafe {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Write-Skip "exists:  $Path"
        return
    }

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # UTF-8 without BOM, LF line endings (friendlier for git/GitHub)
    $normalized = $Content -replace "`r`n", "`n"
    $utf8NoBom  = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $dir).Path + [IO.Path]::DirectorySeparatorChar + (Split-Path -Leaf $Path), $normalized, $utf8NoBom)

    Write-Ok "created: $Path"
}

# ---- Section definitions -----------------------------------------------------
$sections = @(
    @{ Folder = '01-csharp-language';     Title = 'C# Language';                    Description = 'Language features: async/await, generics, delegates, records, LINQ, pattern matching.' },
    @{ Folder = '02-dotnet-runtime';      Title = '.NET Runtime';                   Description = 'CLR, Garbage Collection, memory model, JIT/AOT, threading.' },
    @{ Folder = '03-oop-and-design';      Title = 'OOP & Design';                   Description = 'OOP principles, SOLID, GoF design patterns, DDD basics.' },
    @{ Folder = '04-data-access';         Title = 'Data Access';                    Description = 'EF Core, Dapper, ADO.NET, SQL, transactions, performance.' },
    @{ Folder = '05-aspnet-core';         Title = 'ASP.NET Core';                   Description = 'Web API, middleware, DI, authentication, minimal APIs.' },
    @{ Folder = '06-architecture';        Title = 'Architecture';                   Description = 'Clean Architecture, CQRS, Mediator, microservices, messaging.' },
    @{ Folder = '07-testing';             Title = 'Testing';                        Description = 'xUnit, NUnit, Moq, NSubstitute, integration & E2E testing.' },
    @{ Folder = '08-system-design';       Title = 'System Design';                  Description = 'High-level design problems (rate limiter, URL shortener, cache, queue).' },
    @{ Folder = '09-algorithms-and-ds';   Title = 'Algorithms & Data Structures';   Description = 'Coding problems with multiple C# solutions and complexity analysis.' },
    @{ Folder = '10-behavioral';          Title = 'Behavioral';                     Description = 'STAR-format answers for soft-skill and experience questions.' },
    @{ Folder = '11-real-interviews';     Title = 'Real Interviews';                Description = 'Anonymized retrospectives of actual interviews.' }
)

# ---- 1. Create section folders + placeholder README.md -----------------------
Write-Info 'Creating section folders...'
foreach ($s in $sections) {
    New-DirectorySafe -Path $s.Folder

    $readme = @"
# $($s.Title)

> $($s.Description)

## Questions

_No questions added yet. Use the [question template](../_templates/question-template.md) to add one._

## Index

<!-- Add links to question files as you create them -->
- _empty_
"@
    New-FileSafe -Path (Join-Path $s.Folder 'README.md') -Content $readme
}

# ---- 2. Algorithms sub-folder ------------------------------------------------
New-DirectorySafe -Path '09-algorithms-and-ds/problems'
$problemsReadme = @"
# Coding Problems

Each problem lives in its own folder following the [coding problem template](../../_templates/coding-problem-template.md).

## Index
- _empty_
"@
New-FileSafe -Path '09-algorithms-and-ds/problems/README.md' -Content $problemsReadme

# ---- 3. Templates ------------------------------------------------------------
Write-Info 'Creating templates...'
New-DirectorySafe -Path '_templates'

$questionTemplate = @'
# <Question Title>

**Category:** <e.g., C# / Async>
**Difficulty:** 🟢 Junior | 🟡 Middle | 🔴 Senior
**Tags:** `tag1`, `tag2`

## Question
> The exact question as typically asked in an interview.

## Short Answer
A 2–3 sentence summary suitable for a verbal response.

## Detailed Explanation
In-depth explanation with internals, edge cases, and "why it matters."

## Code Example
```csharp
// Minimal, runnable example
```

## Common Follow-up Questions
- ...
- ...

## Common Mistakes / Pitfalls
- ...

## References
- [Microsoft Docs](https://learn.microsoft.com/dotnet/)
'@
New-FileSafe -Path '_templates/question-template.md' -Content $questionTemplate

$codingTemplate = @'
# <Problem Name>

**Source:** LeetCode #X / Custom / Real interview
**Difficulty:** 🟢 Easy | 🟡 Medium | 🔴 Hard
**Topics:** Arrays, HashMap, ...

## Problem Statement
...

## Examples
```
Input:  ...
Output: ...
```

## Constraints
- ...

## Approach 1: <Name> — O(?) time, O(?) space
Explanation...

```csharp
// solution
```

## Approach 2: <Name> — O(?) time, O(?) space
Explanation...

```csharp
// solution
```

## Final Solution
See `solution.cs`.

## Interview Tips
- What to clarify with the interviewer
- Edge cases to mention out loud
'@
New-FileSafe -Path '_templates/coding-problem-template.md' -Content $codingTemplate

$behavioralTemplate = @'
# <Question>

**Category:** Conflict | Leadership | Failure | Mentorship | ...

## Situation
What was the context? Where, when, who was involved?

## Task
What was your responsibility or goal?

## Action
What specific steps did **you** take? (Use "I", not "we".)

## Result
What was the outcome? Quantify if possible.

## Reflection / What I Would Do Differently
Lessons learned and how it shaped your approach today.
'@
New-FileSafe -Path '_templates/behavioral-template.md' -Content $behavioralTemplate

# ---- 4. Real-interviews README (override default with filename convention) ---
$realInterviewsReadme = @"
# Real Interviews

Retrospectives of actual interviews. Anonymize company and personal names.

Filename convention: ``YYYY-MM-company-or-role.md``

## Index
- _empty_
"@
# Only overwrite if it's still the generic placeholder (i.e. doesn't yet mention 'Filename convention')
$riPath = '11-real-interviews/README.md'
if ((Test-Path -LiteralPath $riPath) -and -not (Select-String -Path $riPath -Pattern 'Filename convention' -Quiet)) {
    Remove-Item -LiteralPath $riPath -Force
}
New-FileSafe -Path $riPath -Content $realInterviewsReadme

# ---- 5. .gitignore -----------------------------------------------------------
$gitignore = @'
# OS
.DS_Store
Thumbs.db

# Editors
.vscode/
.idea/
*.swp

# Claude Code
.claude/

# .NET
bin/
obj/
*.user
'@
New-FileSafe -Path '.gitignore' -Content $gitignore

# ---- Done --------------------------------------------------------------------
Write-Host ''
Write-Ok 'Bootstrap complete!'
Write-Host ''
Write-Info 'Next steps:'
@'
  1. Review the created structure:
       Get-ChildItem -Recurse -Depth 1
  2. Stage and commit:
       git add .
       git commit -m "chore: scaffold project structure"
       git push
  3. Open the folder in Claude Code - CLAUDE.md will load automatically.
'@ | Write-Host