---
title: Documentation
---

# Foghorn docs

**The truth about your connection.**

Product and contributor documentation for Foghorn — same content as the [GitHub repository](https://github.com/Jubblin/Foghorn), published here for reading without cloning.

<nav class="foghorn-site-nav" aria-label="Documentation">
  <a href="{{ site.baseurl }}/">Home</a>
  <a href="{{ site.baseurl }}/README.html">Overview</a>
  <a href="{{ site.baseurl }}/privacy.html">Privacy</a>
  <a href="{{ site.baseurl }}/DESIGN.html">Design</a>
  <a href="{{ site.baseurl }}/CHANGELOG.html">Changelog</a>
  <a href="https://github.com/Jubblin/Foghorn/releases">Releases</a>
</nav>

## Product

| Doc | Description |
| --- | --- |
| [Overview (README)](README.md) | Install, features, architecture |
| [Privacy policy](privacy.html) | App Store / in-app privacy URL |
| [Privacy (markdown)](PRIVACY.md) | Same policy as markdown |
| [Changelog](CHANGELOG.md) | Keep a Changelog history |
| [Design system](DESIGN.md) | Visual language and Settings guidance |
| [Backlog](TODOS.md) | Shipped history (open work lives in [issues](https://github.com/Jubblin/Foghorn/issues)) |

## Screenshots

![Foghorn menu bar popover showing healthy status](screenshots/menu-bar-healthy.png)

![Traffic-light menu bar icons for all connectivity states](screenshots/traffic-lights.png)

## Contribute & release

| Doc | Description |
| --- | --- |
| [Contributing](CONTRIBUTING.md) | Setup, PR process, version bumps |
| [Code of conduct](CODE_OF_CONDUCT.md) | Community standards |
| [Security policy](SECURITY.md) | How to report vulnerabilities |
| [Releasing](RELEASE.md) | GitHub + Mac App Store release flow |
| [Pre-release checklist](PRE_RELEASE_CHECKLIST.md) | Manual checks before tagging |
| [UI testing](UI_TESTING.md) | XCUITest smoke coverage |
| [App Review notes](APP_REVIEW_NOTES.md) | Mac App Store review copy |
| [Agent / health stack](CLAUDE.md) | Local typecheck, lint, and test commands |

## Canonical sources

Root-level files in the repo (`README.md`, `DESIGN.md`, and the rest) remain canonical. Refresh the site copies with:

```bash
./scripts/sync-docs-site.sh
```

CI runs `./scripts/sync-docs-site.sh --check` so the Pages tree stays aligned.
