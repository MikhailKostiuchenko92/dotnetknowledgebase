# Memento Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🟡 Middle
**Tags:** `memento`, `behavioral`, `undo-redo`, `snapshot`

## Question
> What is the Memento pattern, and how would you use it to implement undo/redo while preserving encapsulation?

## Short Answer
Memento captures an object’s state in a snapshot object so it can be restored later without exposing or breaking the object’s internal representation. It is commonly used for undo/redo, editors, workflow drafts, or form state history. In modern C#, immutable records and cloning make memento-style snapshots much easier to implement cleanly.

## Detailed Explanation
### What the pattern does
The Memento pattern separates three roles:

- **Originator**: the object whose state can change;
- **Memento**: the snapshot of that state;
- **Caretaker**: the component that stores history.

The key design goal is **encapsulation**. The caretaker should be able to keep snapshots, but it should not need direct access to the originator’s internal fields. The originator knows how to create and restore the memento safely.

### Why it is useful for undo/redo
Undo/redo is the classic example because you want to move backward through history without leaking every internal detail of the edited object to the rest of the system. A text editor, drawing canvas, and form wizard all fit this model.

| Approach | Pros | Cons |
| --- | --- | --- |
| Expose mutable internals | Simple initially | Breaks encapsulation and invariants |
| Memento snapshots | Safe restore point | Can use more memory |
| Event sourcing | Rich audit trail | More complex reconstruction |

### Modern C# view: records and cloning
In older OO examples, mementos were often verbose private classes. In modern C#, immutable records are a natural fit because they make snapshot state explicit and value-like. If your state is immutable, “saving history” often becomes just “store the old record.”

That said, the pattern still matters conceptually. The important question is not whether you call the snapshot a record or a memento, but whether the originator controls how state is captured and restored.

> Be careful with shallow copies. If your memento stores references to mutable collections, “undo” may silently restore already-mutated objects instead of a true historical snapshot.

### Trade-offs and when not to use it
The biggest trade-off is memory and snapshot cost. If the object is large and changes often, full snapshots can become expensive. In that case, you may prefer delta-based history, command-based undo, or event sourcing.

Memento also works best when state restoration is a real requirement. If you only need audit history or append-only logging, a snapshot pattern may be the wrong abstraction.

| Good fit | Poor fit |
| --- | --- |
| Small-to-medium state, frequent undo | Huge mutable graphs with expensive copies |
| Draft editors, forms, workflows | Systems needing durable distributed history |
| Encapsulation-sensitive models | Scenarios where replayed commands matter more |

### When to use it
Use Memento when you need rollback and want the object itself to guard its invariants during restore. Avoid it when naive snapshots would be too large, too frequent, or too shallow to be trustworthy.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

namespace OopAndDesign.MementoPattern;

public sealed record DocumentMemento(string Title, IReadOnlyList<string> Paragraphs);

public sealed class DocumentEditor
{
    private string _title = string.Empty;
    private List<string> _paragraphs = [];

    public void Update(string title, IEnumerable<string> paragraphs)
    {
        _title = title;
        _paragraphs = paragraphs.ToList(); // Copy mutable input.
    }

    public DocumentMemento Save() => new(_title, _paragraphs.ToArray()); // Store snapshot safely.

    public void Restore(DocumentMemento memento)
    {
        _title = memento.Title;
        _paragraphs = memento.Paragraphs.ToList();
    }

    public void Print() => Console.WriteLine($"{_title}: {string.Join(" | ", _paragraphs)}");
}

public static class Program
{
    public static void Main()
    {
        var editor = new DocumentEditor();
        var undoStack = new Stack<DocumentMemento>();

        editor.Update("Draft", ["Intro"]);
        undoStack.Push(editor.Save());

        editor.Update("Draft", ["Intro", "Details"]);
        editor.Print();

        editor.Restore(undoStack.Pop());
        editor.Print();
    }
}
```

## Common Follow-up Questions
- What is the difference between Memento and Command for undo/redo?
- When should you store full snapshots versus deltas?
- How do immutable records improve a memento-style design?
- What problems appear if your snapshot contains mutable references?
- When would event sourcing be a better fit than Memento?
- Who should own restore logic: the caretaker or the originator?

## Common Mistakes / Pitfalls
- Creating shallow snapshots of mutable collections and assuming undo will be correct.
- Letting the caretaker inspect or mutate internal state directly.
- Taking snapshots too frequently and causing unnecessary memory pressure.
- Using Memento where command replay or event sourcing would better match the domain.
- Forgetting redo history invalidation after a new edit branch is created.

## References
- [Memento](https://refactoring.guru/design-patterns/memento)
- [Introduction to record types in C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/records)
- [MemberwiseClone Method](https://learn.microsoft.com/dotnet/api/system.object.memberwiseclone)
