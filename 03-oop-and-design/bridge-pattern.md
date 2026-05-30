# Bridge Pattern

**Category:** OOP & Design / Structural Patterns
**Difficulty:** 🔴 Senior
**Tags:** `bridge`, `structural`, `decoupling`, `abstraction`

## Question
> What is the Bridge pattern, how does it decouple abstraction from implementation, and how is it different from Strategy? Can you give a cross-platform example?

## Short Answer
The Bridge pattern separates an abstraction from its implementation so both can vary independently. Instead of encoding every combination in one inheritance tree, it splits the design into two dimensions connected by composition. In .NET, Bridge is useful when both the high-level API and the low-level platform-specific implementation need to evolve without causing class explosion.

## Detailed Explanation
### What problem Bridge solves
Bridge addresses a design where two different dimensions of change are being forced into one inheritance hierarchy. For example, imagine dialogs that vary by type (`SettingsDialog`, `ErrorDialog`) and also by platform (`Windows`, `Linux`, `macOS`). If you model that only with inheritance, you quickly get classes such as `WindowsSettingsDialog`, `LinuxSettingsDialog`, `WindowsErrorDialog`, and so on.

Bridge avoids that combinatorial explosion by splitting the design into:

| Side | Responsibility | Example |
| --- | --- | --- |
| Abstraction | High-level API visible to clients | `Dialog` |
| Refined abstraction | Variants of the abstraction | `SettingsDialog`, `ErrorDialog` |
| Implementor | Low-level operations contract | `IRenderer` |
| Concrete implementor | Platform-specific behavior | `WindowsRenderer`, `LinuxRenderer` |

The abstraction holds a reference to the implementor and delegates work to it. Both hierarchies can now change independently.

### How it works internally
The abstraction defines the workflow and business-level shape of the operation. The implementor defines the primitive operations required to make that workflow real. When the abstraction needs platform-specific work, it calls the implementor.

This is composition, not inheritance. The abstraction does not know implementation details; it only knows the implementor contract. That keeps responsibilities cleaner and usually improves testability.

### Bridge vs Strategy
Bridge and Strategy both use composition, so they are easy to confuse.

| Pattern | Main intent | Typical question it answers |
| --- | --- | --- |
| Bridge | Separate two dimensions of variation | “How do I avoid class explosion across abstraction and implementation?” |
| Strategy | Swap algorithms for one behavior | “How do I choose one algorithm at runtime?” |
| Adapter | Translate one interface into another | “How do I make incompatible APIs work together?” |

A Strategy is usually about interchangeable behavior for one slot in an object. A Bridge is more structural: it deliberately creates two linked hierarchies so both sides can evolve independently.

> Warning: if only one dimension actually varies, Bridge may be over-engineering. Do not introduce a second hierarchy unless you genuinely expect both sides to change independently.

### Why it matters in .NET
Bridge is useful in cross-platform libraries, rendering systems, messaging abstractions over multiple transports, and persistence abstractions over multiple providers. The high-level model stays stable while the low-level implementation can change for platform, environment, or vendor reasons.

It also aligns well with dependency inversion. The abstraction depends on an implementor interface rather than a concrete platform class.

### Trade-offs and when not to use it
Bridge adds more types and indirection. For small systems, that can feel heavy. If you only have one implementation or do not expect a second dimension of change, a simple interface plus one implementation is enough.

Use Bridge when two axes of variation are real and likely to grow. Avoid it when the design becomes abstract for its own sake.

## Code Example
```csharp
namespace OopDesignSamples;

public interface IRenderer
{
    void DrawWindow(string title);
    void DrawButton(string text);
}

public sealed class WindowsRenderer : IRenderer
{
    public void DrawWindow(string title) => Console.WriteLine($"[Windows] Window: {title}");
    public void DrawButton(string text) => Console.WriteLine($"[Windows] Button: {text}");
}

public sealed class LinuxRenderer : IRenderer
{
    public void DrawWindow(string title) => Console.WriteLine($"[Linux] Window: {title}");
    public void DrawButton(string text) => Console.WriteLine($"[Linux] Button: {text}");
}

public abstract class Dialog(IRenderer renderer)
{
    protected IRenderer Renderer { get; } = renderer;
    public abstract void Render();
}

public sealed class SettingsDialog(IRenderer renderer) : Dialog(renderer)
{
    public override void Render()
    {
        Renderer.DrawWindow("Settings");
        Renderer.DrawButton("Save"); // Abstraction delegates primitive work.
    }
}

public sealed class ErrorDialog(IRenderer renderer) : Dialog(renderer)
{
    public override void Render()
    {
        Renderer.DrawWindow("Error");
        Renderer.DrawButton("Close");
    }
}

public static class Program
{
    public static void Main()
    {
        Dialog settingsOnWindows = new SettingsDialog(new WindowsRenderer());
        Dialog errorOnLinux = new ErrorDialog(new LinuxRenderer());

        settingsOnWindows.Render();
        errorOnLinux.Render();
    }
}
```

## Common Follow-up Questions
- How is Bridge different from Strategy, Adapter, and Abstract Factory?
- What signs indicate that a design is suffering from class explosion?
- Where would Bridge be useful in cross-platform .NET development?
- How does Bridge relate to dependency inversion?
- When would a simple interface be enough instead of Bridge?

## Common Mistakes / Pitfalls
- Using Bridge when only one dimension varies, adding needless abstraction.
- Letting the abstraction leak platform-specific details that should stay in the implementor.
- Confusing Bridge with Strategy because both use composition.
- Creating too many tiny implementor interfaces that do not represent a stable variation point.
- Still encoding platform checks inside the abstraction, defeating the separation.

## References
- [Bridge](https://refactoring.guru/design-patterns/bridge)
- [Strategy](https://refactoring.guru/design-patterns/strategy)
- [Architectural principles](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles)
