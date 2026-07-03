## Design System

Always read `DESIGN.md` before making any visual or UI decisions.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that does not match `DESIGN.md`.

## Health Stack

- typecheck: xcodebuild -project Online.xcodeproj -scheme Online -configuration Debug -derivedDataPath build-health -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO build
- lint: swiftlint lint --quiet
- test: xcodebuild -project Online.xcodeproj -scheme Online -configuration Debug -derivedDataPath build-health -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO test
- shell: shellcheck scripts/*.sh
