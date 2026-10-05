# Morse Than Words — Implementation & Verification Plan

Status: **P3 done** (audio engine + Learn screen); manual listening check pending. Requirements source: `CLAUDE.md`.

## 0. Decisions made in the planning session

| Topic | Decision |
|---|---|
| App name | **Morse Than Words** (App Store subtitle e.g. "Learn & practice Morse code" for search) |
| Xcode project / target | `MorseThanWords`, bundle ID proposal `com.norberttak.morsethanwords` |
| Platforms | iPhone + iPad, single universal SwiftUI app, **iOS/iPadOS 17+** |
| Speed | **WPM (PARIS standard) + Farnsworth** effective speed (replaces "bps" from CLAUDE.md) |
| Character set | A–Z, 0–9, punctuation `. , ? / = + - ' ( ) : ; " @ !`, prosigns `AR SK BT KN SOS` |
| Practice compare (v1) | **Reveal only** — app shows the sent sequence laid out like your paper; scoring comes with OCR |
| Text sources | `.txt` via Files document picker, and paste/type |
| Background audio | **No** — foreground only (playback stops when app leaves foreground) |
| History | **Local only** practice history (SwiftData), never leaves the device |
| Extras in v1 | Adjustable tone envelope (rise/fall time) |
| Privacy / business | No analytics, no network, no accounts, no ads, no IAP / paywall |

> Note: CLAUDE.md's example `L ..-.` is actually **F**. L is `.-..`. The code table will be
> checked against ITU-R M.1677-1 in unit tests so this cannot slip in.

---

## 1. Architecture

```
MorseThanWords.xcodeproj
├── MorseThanWords/          (iOS app target – SwiftUI views, view models, persistence)
└── Packages/MorseKit/       (local Swift package – pure logic, no UIKit)
    ├── MorseCode            code table, encoder (text → symbols), normalizer
    ├── MorseTiming          WPM/Farnsworth → durations; symbols → timed key events
    ├── MorseSynth           sample generator: tone + envelope + HF-impairment chain
    ├── PracticeGenerator    seeded random sequence generation, grouping
    └── (later) Comparison   alignment/scoring for OCR phase
```

Why the split: everything that can be wrong numerically (timing, code table, audio samples,
randomness) lives in `MorseKit`, which runs with `swift test` on the Mac in seconds — no
simulator needed. The app target is thin UI + `AVAudioEngine` glue.

### 1.1 Timing model (MorseTiming)
- Dit length `t = 1.2 / WPM_char` seconds. Dah = 3t, intra-char gap = t.
- Farnsworth (ARRL formula), with character speed `c` and effective speed `s ≤ c`:
  `ta = (60·c − 37.2·s) / (s·c)`; inter-char gap `= 3·ta/19`, word gap `= 7·ta/19`.
  When `s == c` this collapses to the standard 3t / 7t.
- Output: an array of `KeyEvent(on: Bool, durationSamples: Int)` at the audio sample rate,
  rounding with error-carry so long texts don't drift.

### 1.2 Audio (MorseSynth + app-side AudioEngine)
- **Sample-accurate synthesis**, no `Timer`/`DispatchQueue` keying (those jitter at 20+ WPM).
  An `AVAudioSourceNode` render block pulls samples from a `MorseSynth` that walks the
  key-event list.
- Tone: sine at configurable frequency (default 600 Hz, range 300–1200 Hz).
- Envelope: raised-cosine rise/fall, adjustable 1–15 ms (default 5 ms) → no key clicks.
- **HF-radio impairment chain** (each toggle + level), all driven by a *seeded* RNG so they
  are deterministic in tests:
  1. Band noise — white noise at configurable SNR (dB)
  2. QSB — slow fading (sinusoidal/random LFO 0.05–1 Hz, depth %)
  3. QRN — random static crashes (impulse bursts, rate per second)
  4. Receiver filter — band-pass around the tone (bandwidth 250–2700 Hz) applied to
     tone+noise, so it sounds like a CW/SSB receiver
  5. Distortion — soft clipping (tanh) drive
  6. Optional frequency drift/chirp (few Hz) — stretch goal
- `AVAudioSession` category `.playback` so it is audible with the ring/silent switch on;
  stop on `scenePhase == .background` (not `.inactive`, which also fires for Control Center)
  and on interruptions (phone call, Siri); pause when headphones are unplugged.

### 1.3 Persistence
- Settings: `@AppStorage` / UserDefaults (speed, Farnsworth, tone, envelope, impairments,
  last-used practice char set, group size).
- Practice history: **SwiftData** model `PracticeSession { date, charSet, count, groupSize,
  wpm, effectiveWpm, sentSequence, (later) receivedSequence, score }`. Device-only, user can
  delete individual sessions or all.

### 1.4 Screens (TabView on iPhone, NavigationSplitView sidebar on iPad)
1. **Learn** — grid of characters (sections: Letters / Numbers / Punctuation / Prosigns).
   Tap → plays it, big display `L  .-..` with drawn dot/dash glyphs; replay button.
2. **Practice** — setup form: character set (toggle chips + text field), total count, group
   size (default 5), countdown, then play. Controls: pause/resume/stop, progress. At the end:
   **Reveal** shows the sent characters in groups exactly as they'd appear on paper.
   Saved to history. History list → session detail.
3. **Text** — paste/type box or import `.txt`; normalizer report ("12 unsupported characters
   skipped"); play with current-character highlight, pause/resume, restart.
4. **Settings** — speed (char WPM 5–50, effective WPM ≤ char WPM), tone frequency, volume,
   envelope rise time, HF impairments section with a "Preview" button, reset to defaults,
   About/Privacy text.

---

## 2. Implementation phases

Each phase ends with its tests green and a short demo on simulator (iPhone 17 + iPad Air 11").

| Phase | Content | Exit criteria |
|---|---|---|
| **P0 Setup** | Xcode project (synchronized folders), local `MorseKit` package, test targets (Swift Testing), `.gitignore`, git init, `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption = NO` | `xcodebuild test` passes on empty tests for iPhone + iPad sim |
| **P1 MorseKit core** | Code table, normalizer, encoder, timing (incl. Farnsworth) | All §3.1 unit tests green |
| **P2 Synth** | Tone + envelope generator, impairment chain, seeded RNG | §3.2 signal tests green, incl. round-trip decode |
| **P3 Audio + Learn screen** | AVAudioEngine wrapper, audio session handling, Learn UI | Manual: tone plays, no clicks; UI test opens L and sees `.-..` |
| **P4 Settings** | Settings UI + persistence, preview playback | Settings survive relaunch (UI test) |
| **P5 Practice** | Generator, session player, reveal, SwiftData history | §3.1 generator tests + §3.3 UI flow |
| **P6 Text** | Paste/import, encoding detection, highlight-follow playback | Import of sample files (UTF-8, Latin-1, 1 MB) works |
| **P7 Polish** | iPad layout, Dynamic Type, VoiceOver, dark mode, app icon, launch screen | Accessibility audit (Xcode) clean |
| **P8 App Store prep** | Privacy policy page, screenshots, metadata, TestFlight | TestFlight build installed on real iPhone + iPad |
| **P9 (later) OCR** | Camera/photo capture → Vision handwriting recognition → alignment scoring | See §4 |

---

## 3. Verification plan

### 3.1 Unit tests — MorseKit (Swift Testing, `swift test`)
**Code table**
- Every supported character maps to the ITU code (table-driven test against a literal
  reference list); no two characters share a code; decode(encode(c)) == c for all.
- Prosigns encode without inter-character gap (AR = `.-.-.`).

**Normalizer**
- Lowercase → uppercase; diacritics folded (`é→E`, `ö→O`, `ß→SS`); smart quotes → `"`/`'`.
- Newlines/tabs/multiple spaces collapse into one word gap.
- Unsupported characters (emoji, `#`, CJK) are skipped and reported with count.
- Empty / whitespace-only input → empty sequence, no crash.

**Timing**
- 20 WPM → dit = 60 ms exactly; "PARIS " = 50 dit units = 3.0 s at 20 WPM (the definition).
- Farnsworth: c=20, s=10 → "PARIS " lasts 6.0 s; s=c reproduces standard timing.
- Sum of sample counts for a 10 000-character text deviates < 1 sample from ideal (no drift).
- Boundaries: 5 and 50 WPM; effective > char speed is clamped.

**Practice generator**
- With seed S, output is reproducible; length == requested count; only chosen chars appear.
- Distribution over 100 000 draws within ±2 % of uniform (chi-square test).
- Grouping: 23 chars, group 5 → `5,5,5,5,3`; single-character set works.

### 3.2 Signal tests — MorseSynth (offline rendering, no audio hardware)
- **Frequency**: render a dah at 600 Hz, Goertzel/FFT peak within ±2 Hz; repeat for 300/1200.
- **Envelope**: first and last samples of each element ≈ 0; rise from 10 %→90 % matches the
  configured ms (±0.2 ms); no discontinuity > threshold (click detector).
- **Amplitude**: peak never exceeds 1.0 even with distortion + noise + QRN (no clipping wrap).
- **Impairments deterministic**: same seed → bit-identical buffers; different seed → differ.
- **SNR**: measured tone/noise power ratio within ±1 dB of setting.
- **Filter**: noise power outside the passband attenuated ≥ 20 dB.
- **⭐ Round-trip test**: text → encoder → timing → synth → simple envelope-detector decoder
  → text. Must equal input for clean signal at 5–50 WPM with Farnsworth, and for moderate
  noise (e.g. SNR +10 dB). This single test verifies the whole pipeline end to end.

### 3.3 UI tests — XCUITest (iPhone 17 & iPad Air 11" simulators)
- Learn: tap `L` → shows `L` and pattern (accessibility label "dit dah dit dit"); all sections reachable.
- Settings: change WPM to 25, relaunch → still 25; effective WPM can't exceed char WPM.
- Practice: set chars `KMR`, count 10, group 5 → play (test hook: 50 WPM / skip mode) →
  reveal shows 2 groups of 5, only K/M/R → appears in history → delete it.
- Text: paste "CQ CQ DE TEST" → plays, highlight advances, stop works; import a bundled
  `.txt` fixture via launch argument.
- Launch arguments for tests: `-uiTesting` (in-memory SwiftData, fixed RNG seed, muted
  audio, accelerated playback) so UI tests are fast and deterministic.

### 3.4 Manual / device checklist (each release)
- [ ] Listen on real iPhone + iPad: no clicks at 3 ms rise, clean at 40 WPM
- [ ] Silent switch on → still audible; phone call interrupts & playback stops cleanly
- [ ] Leaving app stops audio; returning does not auto-resume unexpectedly
- [ ] Bluetooth headphones: latency acceptable, no crackle
- [ ] HF impairment presets subjectively sound like a weak HF signal (ask a ham to listen)
- [ ] Rotation, split view / Stage Manager on iPad, Dynamic Type XXL, VoiceOver labels
- [ ] Airplane mode: everything works (proves no network dependency)
- [ ] Network check: run with Charles/Proxyman or Xcode network instrument → **zero requests**

### 3.5 Privacy verification (CLAUDE.md requirement)
- No third-party SDKs; no `URLSession` usage — enforced by a CI grep check
  (`URLSession|NWConnection|Analytics` must not appear in sources).
- `PrivacyInfo.xcprivacy`: no tracking, no collected data; declares UserDefaults
  required-reason API (`CA92.1`).
- App Store privacy label: **"Data Not Collected"**. A minimal privacy-policy page is still
  required by App Store Connect (e.g. GitHub Pages: "this app collects no data").
- No paywall/IAP code or StoreKit entitlement.

### 3.6 Automation
- `project.yml` (XcodeGen) is the source of truth for the Xcode project; after editing it run
  `xcodegen generate`. Source folders are *synchronized folders*, so adding Swift files in
  Xcode or on disk needs no regeneration.
- `xcodebuild test -project MorseThanWords.xcodeproj -scheme MorseThanWords -destination 'platform=iOS Simulator,OS=26.0,name=iPhone 17'`
  and the same with `name=iPad Air 11-inch (M3)` — runs MorseKit, app unit and UI tests.
- `swift test` in `Packages/MorseKit` (fast, Mac-only, no simulator).
- `scripts/check-privacy.sh` — fails on networking / tracking / StoreKit APIs.
- Optional later: GitHub Actions on a macOS runner running the above.

---

## 4. Later phase: OCR comparison (design notes, not v1)
- Capture with `VisionKit` document camera (`VNDocumentCameraViewController`) or Photos picker.
- Recognize with Vision `RecognizeTextRequest` (iOS 18+ Swift API; fall back to
  `VNRecognizeTextRequest` on 17), `recognitionLevel = .accurate`, language correction **off**
  (random groups aren't words), custom candidate filtering to the practice char set.
- Show the recognized text in an **editable** field (handwriting OCR will make mistakes —
  user fixes them before scoring). This also gives a manual typing path for free.
- Scoring: Levenshtein / Needleman-Wunsch alignment of received vs. sent so one missed
  character doesn't shift everything; per-character accuracy, confusion matrix
  (e.g. "you confuse H/5 and S/H"), stored on the history record.
- Tests: alignment unit tests (insertion, deletion, substitution, transposition cases);
  OCR accuracy measured against a small set of photographed handwritten fixture sheets.
- Camera usage needs `NSCameraUsageDescription`; images processed on-device only, not stored.

---

## 5. Open items / to decide later
- Confirm "Morse Than Words" is still free in App Store Connect (reserve it early by
  creating the app record) and confirm the bundle ID; Apple Developer account
  ($99/yr — required even for free apps).
- Localization: English only for v1? (UI strings in String Catalog from the start so adding
  languages later is cheap.)
- Koch-method lessons and visual flash/haptics — candidates for v1.1.
