# WebUI development

Use the real local Cloud stack for development. A static HTTP server cannot create
or save projects: WebUI sends same-origin requests to `/v1/*`.

## Setup (macOS)

The sibling `adaengine-service` checkout is required, together with Swift,
PostgreSQL 17, Redis, Java 21 and Kafka. PostgreSQL and Redis default to their
Homebrew paths. Set `KAFKA_HOME` to an unpacked Kafka distribution; the launcher
also recognizes the existing Cloud checkout's `.local/ugc-tooling/kafka_2.13-4.1.2`.
Python 3 with `venv`, Node and installed WebUI npm dependencies are required.

```sh
cd /path/to/AdaEngine/Editor/WebUI
npm install
npm run dev:setup
npm run dev
```

For another Cloud location, pass `--cloud /absolute/path` to both commands after
`--`. `npm run dev -- --check` checks prerequisites. The Cloud build uses its own
scratch directory; it does not delete or modify the Cloud checkout's shared build.
Cloud sign-in/account/publication panels are built from adawebsite and embedded
in the same Playground shell. The existing adawebsite `dist` supplies legacy static assets; pass
`--website /absolute/path/to/adawebsite/dist` if needed.

- Playground: <http://localhost:8080/games>
- Create: <http://localhost:8080/create>
- My projects: <http://localhost:8080/projects>
- Sign-in/account: <http://localhost:8080/account>
- Publications: <http://localhost:8080/publications>
- Local email codes: <http://127.0.0.1:28088/>

The local launcher adds an **Open test inbox** shortcut on the account page and
next to the email code field. Its label follows the app language. This shortcut
is injected only while serving local development HTML and is absent from exported
frontend files.

Use a disposable email such as `developer@example.test`. Sign-in uses the real
Identity service, PKCE and its normal cookies. Draft development legal documents
are shown inside Playground. No external email is sent. Sign-in restores a safe
Playground destination automatically. The local OTP step links to the test inbox. The `127.0.0.1:8080` entry redirects to `localhost` so the Player
can use a different hostname and never receive Cloud cookies.

All ten Cloud executables run locally, with one PostgreSQL database per service,
Redis and Kafka. S3 is emulated by Moto; acknowledged object writes are mirrored
to disk before their success reaches Cloud and restored at the next start. This
is development storage, not acceptance of an external S3 provider. Publishing
and multiplayer are disabled. AI uses the actual gateway; no provider is
configured by default. Set `STUDIO_PROVIDERS` and its named key environment
variables to exercise a provider, following the Cloud `docs/studio-web.md` guide.
The launcher never saves those keys.

### Local Codex instead of an API key

With Codex CLI installed and signed in through ChatGPT (`codex login`), start:

```sh
npm run dev -- --codex
```

Choose **Local Codex** in the assistant settings. The local edge advertises the
CLI's model catalog and uses `codex app-server` with the CLI's existing sign-in.
No API key is required and no Codex credential is sent to the browser. This
option is exposed only by the opt-in local launcher; hosted Cloud is unchanged.
Cloud sign-in is still required to use the editor and its private projects.

Codex returns structured requests for the existing browser tools. The browser
executes them with its current plan/build filtering, approvals, document history
and Undo. Each provider step uses an ephemeral read-only Codex thread in an empty
development directory; shell, MCP, plugins and host workflows are disabled.
Provider text becomes visible when that structured step finishes. Stop cancels
the local process when the stream disconnects. Model access and usage limits
belong to the signed-in Codex account; a model catalog alone does not prove access.

`npm run test:codex` is an explicit live check that consumes a small Codex turn.
It verifies Cloud admission, origin rejection, a real Codex tool request, and
execution/Undo through the production document tool. Unit tests do not call Codex.

Data, secrets, logs, Python dependencies and build caches stay in ignored
`.local/`. Ctrl-C stops the processes it started and keeps data. A busy port
causes startup to fail before any service starts. No system services are installed.
Use a separate `--state /absolute/path` and matching `--bin-dir` for disposable
experiments; never delete a state directory containing projects you need.

Ports: edge 8080, Player 8081, APIs 28081–28087/28089–28091, inbox 28088,
PostgreSQL 25432, Redis 26379, Kafka 29092/29093, S3 29000/29001. All bind to
loopback. PostgreSQL uses local trust auth inside this development-only cluster.

## Scene and Play

Export the real fixed Player with the matching Swift 6.3.2 WASM SDK and Tint:

```sh
python3 ../../script/export_studio_web.py \
  --swift /path/to/swift-6.3.2-RELEASE.xctoolchain/usr/bin/swift \
  --output "$PWD/.local/studio-web" \
  --scratch-path "$PWD/.local/player-build" \
  --studio-origin http://localhost:8080
```

Restart `npm run dev` after the export. The Player runs at
<http://127.0.0.1:8081/studio-preview.html>, isolated from the Studio hostname.
The launcher does not substitute a fake renderer if the Player is absent.
`--player /absolute/path` selects another prepared export. UI-only changes need
`npm run build` and a browser refresh; Cloud and Player do not need rebuilding.

## Checks

```sh
npm test
npm run test:dev
npm run test:cloud
# With no stack running, also exercise a complete stop/start:
npm run test:cloud -- --restart
```

The dev suite exercises API routing and object persistence across real Moto
restarts. The Cloud smoke uses a disposable account and the actual 3D template,
checking authentication, create/save/read, idempotency, conflicts and origin
rejection. `--restart` also owns the launcher and checks database, session and
project persistence after a full stop/start. It stops its stack when finished.
The default smoke expects no configured AI providers. Browser scene acceptance
additionally requires WebGPU and completed Player frames.

## Single frontend entry

`/studio/` is a legacy URL; `/studio/*` remains the static asset prefix, not a
second app. The HTML base keeps artwork, assistant resources and panel modules
working from every deep link. Games and Create keep the original robot design.
`/games/create` and `/cloud/projects/*` remain compatibility aliases. `/cloud`
continues to accept OAuth and native desktop callbacks before normalization.

Build `adawebsite` with `npm run build:cloud` for an assembled distribution, or
build its panels with `npm run build:panels` then run WebUI's `npm run build`.
`ADA_CLOUD_PANELS_DIST` selects a panels build in another worktree. The WebUI
build fails with a clear setup error if panels are absent. Both the hosted edge
and local launcher serve all public routes from the same WebUI HTML entry.
Private workspaces and publication records retain separate IDs and APIs.

Local browser acceptance (Maestro/Chromium, with the launcher already running):

```sh
maestro test --platform web --headless test/flows/playground-navigation.yaml
maestro test --platform web --headless test/flows/playground-account.yaml
```

The account flow is restricted to localhost and asserts that legal documents are
non-binding drafts. It uses a disposable email and the local mailbox, then creates
a test workspace. It does not run a paid AI request, subscribe or issue a refund.

## Interface language

WebUI uses the native Studio `en.json` and `ru.json` catalogs and the same
`AdaEditor.language` preference (`system`, `en`, `ru`). Settings changes refresh
mounted panels, Cloud account forms and CodeMirror search without discarding
input. Object names, source code, chat messages and other project content remain
as authored. New template names use the language selected when created.

Use `t()` for UI labels and `LocalizedError` for application-authored failures.
The build checks source literals (including escaped Unicode) for hardcoded Russian
and requires both translations. The embedded Cloud panels emit their message keys
in `cloud-panel-messages.json`; rebuild panels before WebUI when changing them.
Run `npm run check:localization`, `npm test`, `npm run build` and
`python ../../script/check_studio_localization.py`. The DOM tests cover live
language changes, input and search preservation; they do not replace visual QA.

Create shows 2D/3D and single-player/multiplayer choices. Dimension selects the
initial template; both choices travel with the first agent request. Multiplayer
is a design request and does not enable a networking service by itself. Local
English/Russian phrase completions appear after a short typing pause; Tab accepts,
Escape dismisses, and Enter sends only the actual draft. These completions use
bundled examples, make no provider calls and preserve the typed prefix.

## Composer attachments

Create stages up to four files locally before a project exists. Picking multiple
files, pasting images/files and dropping files use the same atomic import path.
The first Send creates a snapshot containing the imported assets and attachment
metadata; admission or Cloud failures retain the draft. Removing a chip removes
its chat context while keeping an already imported project asset.

Images: PNG/JPEG and WebP (converted to PNG); models: GLB/VOX; audio: WAV/OGG,
plus MP3/M4A/AAC/FLAC decoded by the browser into PCM16 WAV. Browser codec support
is required for conversion. Limits: 16 MiB per resulting asset, 100 KB for text,
63 MiB total before project creation. Audio is never shortened to fit.
Large images retain original pixels in the asset; a bounded JPEG thumbnail is
sent to vision-capable models. Model and audio files stay in the project for
inspection and use through the existing agent tools. Sending attachments alone
uses a localized default instruction. Unsaved staged files protect tab closing.

Tests exercise the production document/ZIP and agent request paths plus mounted
DOM picker/paste/drop/removal. Image/codec browser APIs are simulated in unit
tests; those checks do not establish live browser decode or native playback.
