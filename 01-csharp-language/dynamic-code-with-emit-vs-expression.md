# Dynamic Code with Emit vs Expression

**Category:** C# / Reflection / Dynamic Code
**Difficulty:** Senior
**Tags:** `reflection-emit`, `expression-trees`, `dynamicmethod`, `aot`, `runtime-codegen`

## Question
> What is the difference between `Reflection.Emit` and compiling expression trees at runtime?
>
> When would you choose `ILGenerator` over `Expression.Compile`, and what are the platform limitations in .NET 8/9?
>
> How do `DynamicMethod`, `AssemblyBuilder`, and expression compilation compare for dynamic code generation?

## Short Answer
`Reflection.Emit` is a low-level API for generating IL, methods, and even full types at runtime, while expression trees model code as a higher-level syntax tree that can be compiled into a delegate. Expressions are easier and safer when you need dynamic delegates for property accessors, filters, or composable logic; `Emit` is more powerful when you need exact IL control or runtime-generated types. Both rely on dynamic code support, so they are a poor fit for Native AOT and other restricted platforms unless you provide a non-dynamic fallback.

## Detailed Explanation
### High-level trees versus raw IL
Expression trees let you describe code in terms of parameters, constants, member access, and calls. The API is verbose, but it stays at the level of language concepts. `Compile()` then turns that tree into an executable delegate.

`Reflection.Emit` is lower level. You work with opcodes through `ILGenerator`, control the evaluation stack manually, and can emit methods, constructors, fields, and types. That power is useful for proxy libraries, serializers, and advanced metaprogramming, but it is much easier to get wrong.

| Concern | `Expression.Compile()` | `Reflection.Emit` |
| --- | --- | --- |
| Abstraction level | High | Low |
| Generates full runtime types | No | Yes |
| Easier to read and maintain | Yes | No |
| Fine-grained IL control | Limited | Excellent |
| Typical use | Delegates, predicates, accessors | Proxies, dynamic types, advanced serializers |

See [expression-trees.md](./expression-trees.md) for the tree model and [reflection-basics.md](./reflection-basics.md) for the broader runtime metadata story.

> Tip: if the output you need is “a delegate I can call,” start by asking whether an expression tree is enough. Many teams reach for IL too early.

### Performance and deployment reality
Compiled expressions are usually fast enough after the one-time compilation cost, and the code is much easier to reason about than handwritten IL. For many scenarios, the real competition is not `Emit` versus expressions, but “runtime code generation versus source generation or handwritten code.”

`Reflection.Emit` can produce extremely optimized code, but it comes with higher maintenance cost and more portability issues. In .NET 8/9, both expression compilation and `Emit` depend on dynamic code generation being allowed by the runtime. That matters on Native AOT, iOS, browser WebAssembly, and similar environments.

| Deployment model | Expressions | `Reflection.Emit` |
| --- | --- | --- |
| CoreCLR server app | Usually fine | Usually fine |
| Trimmed app | Works, but watch hidden dependencies | Works poorly with reflection-heavy designs |
| Native AOT | Usually not supported for JIT compilation | Not supported |
| Restricted sandbox/mobile | Often limited | Often limited |

Use `RuntimeFeature.IsDynamicCodeSupported` and `RuntimeFeature.IsDynamicCodeCompiled` when a library needs to detect these capabilities.

### When each tool is appropriate
Choose expressions when you want:
- dynamic filters and projections
- compiled property getters/setters
- query composition
- logic that is easier to inspect or rewrite before execution

Choose `Emit` when you need:
- runtime-generated types or interfaces
- exact IL instructions
- advanced proxy/interception scenarios
- the smallest possible overhead in a CoreCLR-only environment

> Warning: handwritten IL is easy to break with a wrong stack shape, invalid cast, or unverifiable sequence. It is powerful, but the debugging experience is much worse than ordinary C#.

For AOT-friendly alternatives, see [reflection-vs-source-generators.md](./reflection-vs-source-generators.md) and [source-generators-intro.md](./source-generators-intro.md).

## Code Example
```csharp
using System;
using System.Linq.Expressions;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.CompilerServices;

var person = new Person("Mikhail", 32);
var property = typeof(Person).GetProperty(nameof(Person.Name))!;

Func<Person, string> expressionGetter = BuildWithExpression(property);
Func<Person, string> emitGetter = BuildWithEmit(property);

Console.WriteLine($"Dynamic code supported: {RuntimeFeature.IsDynamicCodeSupported}");
Console.WriteLine(expressionGetter(person)); // Generated from an expression tree.
Console.WriteLine(emitGetter(person));       // Generated from IL instructions.

static Func<Person, string> BuildWithExpression(PropertyInfo property)
{
    var instance = Expression.Parameter(typeof(Person), "person");
    var body = Expression.Property(instance, property);

    // Easier to author and maintain for delegate generation.
    return Expression.Lambda<Func<Person, string>>(body, instance).Compile();
}

static Func<Person, string> BuildWithEmit(PropertyInfo property)
{
    var method = new DynamicMethod(
        name: "GetName",
        returnType: typeof(string),
        parameterTypes: new[] { typeof(Person) },
        m: typeof(Program).Module,
        skipVisibility: false);

    ILGenerator il = method.GetILGenerator();
    il.Emit(OpCodes.Ldarg_0);                     // Load the Person argument.
    il.EmitCall(OpCodes.Callvirt, property.GetMethod!, null); // Call get_Name().
    il.Emit(OpCodes.Ret);

    return method.CreateDelegate<Func<Person, string>>();
}

public sealed record Person(string Name, int Age);
```

## Common Follow-up Questions
- Why is `Expression.Compile()` often easier to maintain than `ILGenerator` code?
- When do you need `AssemblyBuilder` instead of `DynamicMethod`?
- Why are runtime code-generation techniques a bad fit for Native AOT?
- What does `RuntimeFeature.IsDynamicCodeSupported` tell you in practice?
- When is a source generator a better alternative than either expressions or IL emit?

## Common Mistakes / Pitfalls
- Using `Reflection.Emit` when a simple compiled expression or cached delegate would do.
- Forgetting that `Compile()` itself is expensive and should usually be cached.
- Assuming dynamic code generation works everywhere, including Native AOT and browser/mobile targets.
- Writing invalid IL and discovering the failure only at runtime.
- Mixing runtime-generated delegates into hot paths without measuring startup and compilation cost.

## References
- [Microsoft Docs: Reflection.Emit namespace](https://learn.microsoft.com/dotnet/api/system.reflection.emit)
- [Microsoft Docs: Expression trees](https://learn.microsoft.com/dotnet/csharp/advanced-topics/expression-trees/)
- [Microsoft Docs: RuntimeFeature.IsDynamicCodeSupported](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.runtimefeature.isdynamiccodesupported)
- [See: Expression Trees](./expression-trees.md)
- [See: Reflection vs Source Generators](./reflection-vs-source-generators.md)
