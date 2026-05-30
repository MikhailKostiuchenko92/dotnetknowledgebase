# Command Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🟡 Middle
**Tags:** `command`, `behavioral`, `MediatR`, `undo-redo`

## Question
> What is the Command pattern, and how would you use it for undo/redo or command queues in a .NET application?

## Short Answer
The Command pattern wraps a request in an object so it can be executed, stored, queued, logged, or undone independently of the caller. It separates the object that asks for work from the object that actually performs it. In modern .NET, MediatR requests often resemble commands at the application layer, although classic GoF Command is more focused on encapsulating an action and optionally reversing it.

## Detailed Explanation
### What it is
Command turns “do this action” into a first-class object. Instead of a button, controller, or service directly calling a receiver method, it creates a command object that knows enough to execute the request later.

The pattern usually involves:

- **Command** – common interface like `Execute()`.
- **Concrete command** – wraps a specific action.
- **Receiver** – the object that contains the real business behavior.
- **Invoker** – triggers commands and may keep history.

That separation is useful when you want more than immediate execution.

### How it works internally
A command stores all information needed to perform the action: target object, parameters, and sometimes the previous state required for undo. Because the request is data plus behavior, you can place commands in a queue, retry them, serialize them, or keep them in history stacks.

Undo/redo is where the pattern becomes especially clear. Each command executes and then gets pushed onto an undo stack. If the user chooses Undo, the application pops the last command and calls `Undo()`. A redo stack can replay undone commands.

| Scenario | Why Command helps | Example |
| --- | --- | --- |
| UI actions | Decouple button from action logic | Menu item executes a command |
| Undo/redo | Keep reversible action history | Text editor operations |
| Queues/background work | Store actions for later processing | Process order commands asynchronously |
| Logging/auditing | Persist what was requested | Command history for diagnostics |

### Why it matters
Command improves extensibility. The caller no longer needs to know the details of how work is performed, and the application can attach cross-cutting behavior such as retries, logging, transactions, or scheduling around commands.

This is also why developers connect it to MediatR. A `CreateOrderCommand : IRequest<Guid>` is not pure GoF Command, but it follows the same idea of packaging intent into an object and routing it through a handler. MediatR adds mediator-style dispatch; classic Command emphasizes executable request objects and reversible actions.

> Not every method call needs to become a command class. If you only add wrappers around trivial service methods, the design becomes noisy without adding flexibility.

### Trade-offs and when not to use it
The main downside is extra indirection and more types. If there is no need for queuing, history, retries, or decoupled execution, direct method calls are simpler.

Use Command when:
- actions need undo/redo;
- work may run later or in another component;
- you want to log or queue business actions explicitly.

Avoid it when:
- the action is a simple one-step method call with no lifecycle;
- command classes would only forward parameters with no added value;
- the team cannot clearly distinguish command intent from ordinary service APIs.

In interviews, mention both forms: classic object-oriented commands for action history and modern application commands used with MediatR/CQRS-style handlers.

## Code Example
```csharp
using System;
using System.Collections.Generic;

namespace OopAndDesign.CommandPattern;

public interface IEditorCommand
{
    void Execute();
    void Undo();
}

public sealed class TextDocument
{
    public string Text { get; private set; } = string.Empty;

    public void Append(string value) => Text += value;

    public void RemoveLast(int length) =>
        Text = Text[..Math.Max(0, Text.Length - length)];
}

public sealed class AppendTextCommand(TextDocument document, string value) : IEditorCommand
{
    public void Execute() => document.Append(value);

    public void Undo() => document.RemoveLast(value.Length);
}

public sealed class EditorInvoker
{
    private readonly Stack<IEditorCommand> _undoStack = new();
    private readonly Stack<IEditorCommand> _redoStack = new();

    public void Execute(IEditorCommand command)
    {
        command.Execute();
        _undoStack.Push(command);
        _redoStack.Clear();
    }

    public void Undo()
    {
        if (_undoStack.TryPop(out var command))
        {
            command.Undo();
            _redoStack.Push(command);
        }
    }

    public void Redo()
    {
        if (_redoStack.TryPop(out var command))
        {
            command.Execute();
            _undoStack.Push(command);
        }
    }
}

public static class Program
{
    public static void Main()
    {
        var document = new TextDocument();
        var editor = new EditorInvoker();

        editor.Execute(new AppendTextCommand(document, "Hello"));
        editor.Execute(new AppendTextCommand(document, ", world"));
        Console.WriteLine(document.Text);

        editor.Undo();
        Console.WriteLine(document.Text);

        editor.Redo();
        Console.WriteLine(document.Text);
    }
}
```

## Common Follow-up Questions
- How is Command different from Strategy?
- What extra state is needed to support undo/redo safely?
- How does MediatR relate to the Command pattern?
- When would you queue commands instead of executing them immediately?
- How would you persist command history?

## Common Mistakes / Pitfalls
- Creating command types that only add boilerplate and no real lifecycle value.
- Implementing `Undo()` without capturing the full previous state needed for reversal.
- Mixing command objects with query/read operations and blurring intent.
- Assuming MediatR requests automatically provide undo/redo semantics.

## References
- [Command pattern - Refactoring.Guru](https://refactoring.guru/design-patterns/command)
- [MediatR on GitHub](https://github.com/jbogard/MediatR)
- [ICommand Interface](https://learn.microsoft.com/dotnet/api/system.windows.input.icommand)
