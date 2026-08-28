# Gravity Language Server

`gravity-lsp` is AdaEngine's language server for Gravity/Ada Script files. AdaEditor uses the same language core internally, while other editors can start the executable over standard input and output.

## Build

From the `Editor` package directory:

```sh
swift build --product gravity-lsp
```

The debug executable is written to SwiftPM's binary directory. To get its exact path, run:

```sh
swift build --show-bin-path
```

Then configure an LSP client to start `<bin-path>/gravity-lsp` for files ending in `.ada` or `.gravity`, with the language identifier `gravity`. The server communicates using standard LSP `Content-Length` framing over stdin/stdout; logs must not be written to stdout.

## Supported features

- Completion for Gravity declarations, inferred local values, and AdaEngine scripting APIs such as `AdaPlugin`, `AdaQuery`, `AdaSystem`, query collections, and entities.
- Workspace symbols collected from `.ada` and `.gravity` files below the configured root.
- Full-document synchronization for open and changed documents.
- Document symbols.
- Syntax diagnostics that remain available while the document is incomplete.
- UTF-16 LSP positions and completion replacement ranges.

The first implementation intentionally does not advertise hover, go-to-definition, references, rename, formatting, or incremental text synchronization. Diagnostics currently cover tolerant lexical and delimiter errors; they are not yet compiler-level type diagnostics.

## Protocol lifecycle

The client must send `initialize`, then `initialized`, before document notifications and requests. The server supports `textDocument/didOpen`, `textDocument/didChange`, `textDocument/didSave`, `textDocument/didClose`, `textDocument/completion`, `textDocument/documentSymbol`, `workspace/didChangeWatchedFiles`, `shutdown`, and `exit`.
