# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:1105d646 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->


## Build & Test

Commands and toolchain versions are in `docs/DEVELOPMENT.md`. From the repo root:

```bash
make tools
make gen
make lint
make check-config
make format
make test
make build-tests
make build-ios
make test-ios
make open
make clean
```

`make test` runs `swift test --package-path Packages/MDCore`, then `make build-tests` (`xcodebuild build-for-testing -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`, which compiles the app and mdviewUITests). It does not boot a simulator and does not need `DEVELOPMENT_TEAM`.

`make lint` ends with `make check-config` (`scripts/check_app_config.py`, `--self-test` available).

`make test-ios` runs the XCUITest launch test on a simulator. It exits non-zero unless `CI=true` or `MDVIEW_ALLOW_SIMULATOR=1`. Do not set the override on a developer Mac. Override the destination with `MDVIEW_IOS_DESTINATION` (default `platform=iOS Simulator,name=iPhone 16`).

## Architecture Overview

mdview is a SwiftUI iOS app. The scene is `DocumentGroup(viewing: TextDocument.self)`. `TextDocument` is a read-only `FileDocument` for the imported Markdown UTI `net.daringfireball.markdown` (extensions `md`, `markdown`, `mdown`) and `public.plain-text`. It decodes bytes with `MDCore.TextDecoding`. The viewer shows the raw string. Later beads replace that with Textual.

`Packages/MDCore` is a Foundation-only package (iOS 18, macOS 15, no dependencies) for logic that `swift test` can run on the Mac. The app target's only remote package is Textual, pinned `.upToNextMinor(from: "0.5.0")`.

The system document browser provides Files, Recents, share sheet, Open In, and iPad drag-and-drop. There is no custom browser.

## Conventions & Patterns

- iOS deployment target 18.0. `SWIFT_VERSION` is 6 with strict concurrency.
- Edit `project.yml`, then `make gen`. `mdview.xcodeproj` is generated and gitignored, except `Package.resolved`.
- `Config/Local.xcconfig` is gitignored. `make gen` copies it from `Config/Local.xcconfig.example` when it is missing. `PRODUCT_BUNDLE_IDENTIFIER` is `us.par72.mdview`. Leave `DEVELOPMENT_TEAM` empty.
- `make lint` runs swiftformat and swiftlint. The custom rule `no_networking` rejects `URLSession`, `NWConnection`, `WKWebView`, and `CFNetwork` under `App/` and `Packages/`.
- Do not boot the iOS Simulator locally.
