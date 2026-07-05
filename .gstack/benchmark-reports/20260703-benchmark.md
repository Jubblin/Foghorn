# PERFORMANCE REPORT — Online (macOS native)

**Date:** 2026-07-03  
**Branch:** main  
**Version:** 0.2.1 (build 3)  
**Mode:** First baseline capture (no prior baseline to compare)

> Online is a native SwiftUI menu bar app, not a web app. Web metrics (TTFB, FCP, LCP, JS bundle) are N/A. This report uses build, binary, runtime, and probe-cycle metrics instead.

---

## Build & Test

| Metric | Value | Status |
|--------|-------|--------|
| Clean build | 9.09s | OK |
| Incremental build | 1.87s | OK |
| Test suite (12 tests) | 7.69s | OK |
| Tests passing | 12/12 | PASS |

---

## Binary Size

| Artifact | Size | Notes |
|----------|------|-------|
| Debug executable | 40 KB | Stripped Mach-O |
| Debug .app bundle | 1.9 MB | Includes debug symbols, dSYM overhead in derived data |
| Release executable | 1.2 MB | Optimized binary |
| Release .app bundle | 1.2 MB | Ship candidate |

---

## Runtime (idle, post-launch)

| Metric | Debug | Release |
|--------|-------|---------|
| RSS memory | 86 MB | 88 MB |
| CPU (idle) | ~0% | ~0% |
| Launch (`open`) | 0.07s | — |

SwiftUI + network stack baseline on macOS 15. Memory is higher than a minimal CLI tool but normal for a SwiftUI app with active probe engine.

---

## Probe Engine

| Setting | Value |
|---------|-------|
| Default poll interval | 2.0s |
| Battery backoff | Yes (doubles interval on battery when base < 3s) |
| Probes per tick | 6 parallel (path, gateway, DNS, HTTP×2, custom hosts) |

Probe work is async and parallel per tick. No blocking main thread observed at idle.

---

## Codebase

| Metric | Value |
|--------|-------|
| Swift files | 22 |
| Lines of Swift | 1,720 |

Small, focused codebase. Low risk of bundle bloat from dependencies.

---

## Performance Budget Check

| Metric | Budget | Actual | Status |
|--------|--------|--------|--------|
| Release bundle | < 5 MB | 1.2 MB | PASS |
| Idle memory | < 100 MB | ~88 MB | PASS |
| Incremental build | < 30s | 1.87s | PASS |
| Test suite | < 60s | 7.69s | PASS |
| Launch | < 1s | 0.07s | PASS |

**Grade: A (5/5 passing)**

---

## Regressions

None (first baseline).

---

## Recommendations

1. **Re-run after changes:** `xcodebuild … build test` and compare against `.gstack/benchmark-reports/baselines/baseline.json`.
2. **Track release bundle size** when adding fonts (Instrument Sans + JetBrains Mono per DESIGN.md backlog) — expect +200–400 KB.
3. **Probe interval** is user-configurable; battery backoff is already in place. No action needed unless users report drain.
4. **Memory:** If RSS exceeds 150 MB at idle, profile with Instruments (Allocations + Leaks) on the probe tick path.

---

## Next Steps

```bash
# Re-benchmark after changes (compare to baseline):
xcodebuild -scheme Online -destination 'platform=macOS' -derivedDataPath build build test

# Capture a new baseline explicitly:
# /benchmark --baseline  (re-run this skill)
```
