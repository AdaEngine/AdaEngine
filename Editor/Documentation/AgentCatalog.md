# Agent catalog

Open **Agent Settings** from the application menu. The **ACP Registry** section
finds local agents and loads the [official ACP Registry](https://agentclientprotocol.com/get-started/registry).

- **Add & Connect** registers an existing ACP executable, selects it for the project,
  and starts the connection without sending a message.
- **Install & Connect** installs the registry distribution and connects it to the project.
  For discovered Codex and Claude CLIs, this action appears directly beside the found CLI
  and installs the matching ACP adapter.
- **Connect** selects an already added agent, saves its connection to `.ada/project.json`,
  creates a new chat session and starts the ACP connection. The selected agent and any
  connection or authentication error are shown in the catalog. Open **Agent Chat** to chat.
- **Remove** removes the catalog registration. Executables and existing project
  connections are retained because other projects may still use them.
- **Refresh** repeats discovery and reloads the registry. A saved catalog and local
  discovery remain available if the registry cannot be reached.

Discovery checks PATH, Homebrew, user CLI directories, NVM installations and
Codex.app. Codex and Claude CLIs are recommendations: they require their ACP
adapters. Already installed adapters can be added directly. Gemini CLI, OpenCode,
GitHub Copilot and Sloppy ACP are also recognized.

Node agents require Node.js/npm; Python agents require uv. The installer uses
private installation directories rather than global package installations. macOS
binary distributions support zip, tar.gz and tar.bz2 archives. SHA-256 is checked
when supplied by the registry. Archives containing links or unsafe paths are
rejected with a manual-install message. Packages with ambiguous executable names
also require manual configuration.

Registry metadata and registrations live in
`~/Library/Application Support/AdaEditor/Agents`. Installation does not sign in,
copy credentials, or send prompts. Authentication and subscriptions belong to the
agent, as described in [Zed's external-agent documentation](https://github.com/zed-industries/zed/blob/main/docs/src/ai/external-agents.md).
Local processes are supported on macOS; iPad displays an availability message.

Validation:

```sh
swift test --filter EditorAgentCatalogTests
ADAEDITOR_ACP_LIVE_TEST=1 swift test --filter EditorAgentCatalogTests/liveInstall
```

The opt-in live test downloads the official registry, installs Codex ACP in a
fresh temporary directory, performs `initialize`, terminates the process, and
removes the installation. It does not authenticate or send a prompt.

If the registry names an npm version that has not been published, an `ETARGET`
response triggers a lookup of the same package's published stable release. The
installer pins that exact version and displays the actual installed version in
the catalog. Other installation failures do not trigger version substitution.
For diagnosis only, `ADAEDITOR_ACP_TEST_CODEX_VERSION` can override the registry
version in the opt-in live test.
