# AdaUI Views in Ada Script

Declare native AdaUI view trees in `.ada` files and preview them directly in AdaEditor.

## Declare a view

Annotate a class with `@view`. The build plugin derives its runtime identity
from the Swift module and class name, humanizes the class name for AdaEditor,
and emits a typed accessor. Use `id` or `title` only when an explicit override
is required.

```ada
@view
class WelcomeView {
    @state var message = "Hello from Ada Script";
    @environment(colorScheme) var colorScheme;

    func body() {
        VStack(spacing: 12) {
            Text(message).fontSize(28);
            Text("Appearance: " + colorScheme);
            HStack {
                Text("Native AdaUI");
                Spacer();
            }
            Button("Change message") {
                message = "State updated";
            };
        }
        .padding(24)
        .background("#20232aff");
    }
}
```

`body()` is an implicit view-builder context. AdaEngine lowers its declarative
expressions into the same native `View` graph used by Swift declarations. It
does not use an immediate-mode drawing callback or retain live ECS pointers.

## Show a registered view

`AdaScriptBuildPlugin` embeds `.ada` files and registers their `@view`
declarations from `AdaScriptPluginsGenerated`. Use the generated typed accessor
in a Swift window or another AdaUI hierarchy:

```swift
WindowGroup {
    AdaScriptViewsGenerated.welcomeView
}
.addPlugins(AdaScriptPluginsGenerated())
```

The first view slice supports `Text`, `VStack`, `HStack`, `ZStack`, `Spacer`,
`Divider`, and `EmptyView`. Container children are collected implicitly by the
`body()` view builder. Available modifiers are
`.padding`, `.frame`, `.fontSize`, `.foregroundColor`, `.background`,
`.opacity`, and `.accessibilityIdentifier`. Colors accept common names or
`#RRGGBB` / `#RRGGBBAA` strings.

## State and environment

Declare view-owned values with `@state`. The script view instance remains alive
while its AdaUI identity remains alive. A `Button` action mutates that same
instance, reevaluates `body()`, and invalidates the native view subtree.

Use `@environment(key)` to bind a read-only AdaUI environment value before each
evaluation. The current keys are `colorScheme`, `isEnabled`, `scaleFactor`, and
`userInterfaceIdiom`.

The intended two-way child-view syntax is `@binding var value;` with `$value`
at the call site. Nested script-view parameters are not implemented in this
slice, so `@binding` currently produces a compile-time diagnostic instead of a
silently disconnected value.

## Preview in AdaEditor

Open a `.ada` file containing `@view`. AdaEditor lists each declaration by its
title, gathers the target's `.ada` sources, substitutes the current unsaved
document, evaluates the selected view, and mounts the resulting native AdaUI
tree in the Preview panel.

Preview actions and state use the same persistent instance path as runtime
views. Cross-view bindings and state migration across source generations remain
follow-up work.
