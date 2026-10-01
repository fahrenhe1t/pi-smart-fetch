# pi-smart-fetch

`pi-smart-fetch` adds smarter web fetching tools to pi.dev.

**This is a maintained fork** of [`Thinkscape/agent-smart-fetch`](https://github.com/Thinkscape/agent-smart-fetch) (the `packages/pi-smart-fetch` subpackage), extracted into a standalone pi package so it can be installed directly from git. The fork carries two fixes over the upstream `0.3.17`:

- **Host-provided deps fixed** — `@earendil-works/pi-tui` and `@sinclair/typebox` are declared as `peerDependencies` (`"*"`) and externalized at build time, so they are no longer bundled into `dist/index.js`. This clears pi's *"Host-provided extension packages must be declared in peerDependencies"* warning and the duplicate-runtime-module risk.
- **`defuddle` bumped to `^0.19.4`** — pulls `mathml-to-latex@1.8.0` → `@xmldom/xmldom` (advisory-clean), resolving the high-severity `@xmldom/xmldom` audit.

![pi Smart Fetch](https://raw.githubusercontent.com/fahrenhe1t/pi-smart-fetch/main/demo.gif)

## Features

- 🔐 **Browser-like TLS/SSL + HTTP fingerprints** — better success on bot-defended pages
- 🧹 **Defuddle extraction** — clean readable content instead of noisy HTML
- 🧠 **Useful metadata** — title, author, site, language, published date when available
- 📦 **Downloads + large file support** — stream attachments and binaries to temp files
- 🔁 **Client-side `<meta>` redirects** — follows sane meta refresh redirects with loop limits
- 🔗 **Alternate content fallback** — when extraction produces no/thin content, follows qualified `<link rel="alternate" type="...">` entries in `<head>` that match the requested output format
- ⚡ **Batch fetch** — fetch many URLs with bounded concurrency
- 📝 **Multiple output formats** — `markdown`, `html`, `text`, `json`, `raw`

## Site optimisations

This package works on general web pages, but some site types benefit especially from Defuddle's extractors and cleanup:

- YouTube pages and transcripts
- Reddit posts and comment threads
- X / Twitter posts
- GitHub pages, issues, PRs, and discussions
- Hacker News threads
- Substack posts
- Pages with code blocks, footnotes, math, and callouts

Notes:
- Defuddle is the cleanup layer: it strips common page chrome like nav, sidebars, related links, share widgets, and footers
- It does **not** execute JavaScript or solve interactive anti-bot/login flows
- If an HTML shell advertises alternate content in `<head>`, smart-fetch can follow matching alternates such as `text/markdown`, `text/plain`, `text/html`, or JSON media types according to the requested `format`

## Install

This package is consumed from its git repository (a built `dist/` is committed, so pi does not need Bun at install time — it just runs `npm install` for runtime deps):

```bash
pi install git:github.com/fahrenhe1t/pi-smart-fetch@<commit-sha>
```

In `~/.pi/agent/settings.json`, that is a single entry in the `packages` array:

```json
{ "packages": [ "git:github.com/fahrenhe1t/pi-smart-fetch@<commit-sha>" ] }
```

Pin to a commit SHA for reproducibility; update the SHA (or run `pi update --extensions`) to pick up changes.

## Maintaining this fork

The source of truth is the monorepo fork at `~/projects/agent-smart-fetch` (which tracks `upstream` → `Thinkscape/agent-smart-fetch`). This standalone package (`~/projects/pi-smart-fetch`) is what pi actually installs, with a **committed** `dist/`.

To apply an upstream change (or any fix) and republish:

1. Make the change in `~/projects/agent-smart-fetch/packages/pi-smart-fetch` and commit.
2. Run the publish script:
   ```bash
   ~/projects/pi-smart-fetch/scripts/rebuild-and-publish.sh
   ```
   It rebuilds `dist/` in the monorepo (`bun run build:pi`), syncs `dist/` + `package.json` into this repo, commits, and pushes — then prints the new commit SHA.
3. Update the pinned SHA in `~/.pi/agent/settings.json` and restart pi.

`scripts/rebuild-and-publish.sh` is the only thing you normally need to remember; it keeps the standalone package in sync with the monorepo fork automatically.

## Pi tools

Registers:
- `web_fetch`
- `batch_web_fetch`

Synopsis:

```text
web_fetch(url, browser?, os?, headers?, maxChars?, timeoutMs?, format?, removeImages?, includeReplies?, proxy?, verbose?)
batch_web_fetch(requests, verbose?)
```

For `batch_web_fetch`, each item in `requests` accepts the same parameters as `web_fetch` except `verbose`.

## Output formats

| Format | What you get |
|---|---|
| `markdown` | Best default for readable page content |
| `html` | Cleaned HTML output |
| `text` | Plain text with markdown stripped |
| `json` | Structured JSON for metadata-heavy workflows |
| `raw` | Full raw server response without extraction or truncation — for further parsing |

## Global defaults

Optional settings in `~/.pi/agent/settings.json` or `.pi/settings.json`:

```json
{
  "smartFetchVerboseByDefault": false,
  "smartFetchDefaultMaxChars": 50000,
  "smartFetchDefaultTimeoutMs": 15000,
  "smartFetchDefaultBrowser": "chrome_145",
  "smartFetchDefaultOs": "windows",
  "smartFetchDefaultRemoveImages": false,
  "smartFetchDefaultIncludeReplies": "extractors",
  "smartFetchDefaultBatchConcurrency": 8,
  "smartFetchTempDir": "/tmp/smart-fetch-pi"
}
```

| Setting | Default | Description |
|---|---:|---|
| `smartFetchVerboseByDefault` | `false` | Stored default for the compatibility `verbose` flag |
| `smartFetchDefaultMaxChars` | `50000` | Default `maxChars` limit |
| `smartFetchDefaultTimeoutMs` | `15000` | Default request timeout in milliseconds |
| `smartFetchDefaultBrowser` | `chrome_145` | Default browser fingerprint profile |
| `smartFetchDefaultOs` | `windows` | Default OS fingerprint profile |
| `smartFetchDefaultRemoveImages` | `false` | Strip image references by default |
| `smartFetchDefaultIncludeReplies` | `extractors` | Include replies/comments only when site extractors support them |
| `smartFetchDefaultBatchConcurrency` | `8` | Default bounded concurrency for `batch_web_fetch` |
| `smartFetchTempDir` | OS temp dir | Base directory for attachment and binary downloads |

Notes:
- Project `.pi/settings.json` overrides global `~/.pi/agent/settings.json`
- Legacy `webFetch*` aliases are still supported

## Dev note

The monorepo fork (`agent-smart-fetch`) uses Bun for local development, tests, and builds. This standalone repo is the *published* pi package: it ships a prebuilt `dist/` and is installed by pi via a git source (pi runs `npm install` for runtime deps; it does not build). Rebuilds happen in the monorepo fork and are synced here by `scripts/rebuild-and-publish.sh`.
