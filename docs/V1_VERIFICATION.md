# V1 completion and re-entry verification

The backend remains authoritative for completion flags, scores, streaks, and
attempt enforcement. The iOS re-entry guard reads `users/me` before preparing
gameplay. Completed Maths restores the recorded count/time without creating a
problem sequence or timer. Completed Guess and Trivia use the existing protected
review reads. A failed completion check or Guess review does not enable gameplay.

## Normal verification

Use normal simulator signing; do **not** pass `CODE_SIGNING_ALLOWED=NO` when running
tests that use Supabase sessions. An unsigned test host lacks its simulated
application identity, causing Keychain error -34018. Supabase can return a sign-in
response while failing to persist it; the next token lookup then throws
`sessionMissing`. No app-auth change is needed for that test-build configuration.

Run the unit suite with the existing Blipz scheme and a valid simulator destination:

```sh
xcodebuild test -project Blipz.xcodeproj -scheme Blipz \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -only-testing:BlipzTests
```

`GameReentryTests` covers read-only result restoration and command guards. The
Reveal tests cover all completion-flag combinations, score presentation, UTC day
identity, next-game routing, and automatic/manual presentation policy.

Completed/incomplete UI verification uses a separate disposable app copy and a
loopback-only fixture HTTP server. Neither is installed in the production source
target. All mutating fixture routes are rejected. The harness restores an existing
simulator session, never creates a live test user, and never writes completion
flags, content, scores, history, or streaks to Supabase.

The completed fixture uses Guess 8.4/10 (33.6 points), Maths 60 seconds (19 points),
and Trivia 5/5 (30 points), totaling 82.6/100 using the existing backend formula.
It exercises secure-review presentation, sharing, return to Today, completed-game
re-entry, unavailable ranks, repeated cover dismissal, and light/dark/large-text
layouts. Fixture values must never be copied into production app logic.

## Known hosted-window diagnostic limitation

On Xcode 26.0.1 / Swift 6.2 / the iOS 26 simulator, the optional
`DailyRevealLiveVerificationTests` hosted-window screenshot diagnostic can abort
during teardown in:

```text
DailyRevealViewModel.__deallocating_deinit
swift_task_deinitOnExecutorMainActorBackDeploy
TaskLocal::StopLookupScope
invalid-free malloc abort
```

This has not reproduced in normal SwiftUI cover presentation/dismissal. Independent
controls also passed 100 synchronous, 100 MainActor-task, and 100 main-queue releases
of the unloaded model. The exact runtime fault is not established. No product-code
workaround or broad concurrency refactor was applied.

The hosted-window diagnostic is retained but explicitly opt-in through
`BLIPZ_LIVE_WINDOW_DIAGNOSTIC=1` in the test process environment. It additionally
requires local Debug, an existing signed simulator session, a local backend, and
an incomplete actual day. Do not enable it against uncontrolled player data.
Its skip is intentional and must not be reported as a successful live teardown
test. Treat it as a test-harness/runtime limitation unless future evidence shows
product impact.

The coordinator's optional date argument is resolved inside its MainActor method,
preserving behavior without the previous isolated default-argument warning.

These are UI/lifecycle checks, not authorization to generate content, migrate the
database, deploy, or change production configuration. Release simulator compilation
alone does not establish TestFlight signing or hosted-environment readiness.

## Recorded verification — 2026-10-26

- Signed unit suite: 30 passing cases across 15 test methods; the one explicitly
  opt-in hosted-window diagnostic was skipped, not counted as a pass.
- The separately staged replay-fix snapshot built independently and passed all
  five focused re-entry regression tests before its commit.
- Disposable UI suite: six tests passed, covering completed and incomplete entry
  for all three games, failed Guess review, score/prompt/streak presentation,
  native sharing, five repeated completed-day return cycles, rank omission,
  and screen captures.
- An additional native Dynamic Type matrix test passed in both light and dark
  mode at `accessibility-extra-large` (SwiftUI accessibility size 3). It verified
  the Reveal result cards actually stack vertically, not merely that a test-only
  text-size override was set on the presenting screen.
- Actual-repository Debug and Release simulator builds passed. No backend code,
  scoring, auth, schema, published content, or player records were changed.

Screenshots were inspected for Today, Reveal, Ranks, and You in light/dark and
default/large text. Large text requires scrolling and the controls remain reachable.
Today's pre-existing decorative hero badge can overlap its decorative image
headline at accessibility sizes; its semantic game row remains readable and the
hero decoration is hidden from accessibility. This visual rough edge was not
expanded into an unrelated redesign. These checks are not a full VoiceOver,
contrast, or physical-device accessibility certification.
