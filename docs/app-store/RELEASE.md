# Releasing Morse Than Words

Everything that can be prepared in the repository is done. The steps below need your Apple and
GitHub accounts, so they are yours to run. Work through them in order.

## 1. Publish the support and privacy pages (GitHub Pages)

1. Create the GitHub repository `norberttak/morse-trainer` (public, so Pages and Issues are
   free and support requests can be filed) and push `main`.
2. Repository › Settings › Pages › Source: **Deploy from a branch**, branch `main`, folder `/docs`.
3. After a minute, check both URLs open:
   - https://norberttak.github.io/morse-trainer/ (support)
   - https://norberttak.github.io/morse-trainer/privacy.html (privacy policy)
4. Make sure Issues are enabled (the support page links to them).

If the repository name or owner differs, update the URLs in `docs/index.html`,
`docs/privacy.html` and `docs/app-store/metadata.md`.

## 2. Signing

1. Find your Team ID at developer.apple.com › Account › Membership details.
2. In `project.yml`, under the `MorseThanWords` target settings, replace the comment line with
   `DEVELOPMENT_TEAM: ABCDE12345` (your ID), then run `xcodegen generate`.
3. In Xcode › Settings › Accounts, make sure your Apple ID is signed in.

## 3. Create the app record in App Store Connect

appstoreconnect.apple.com › Apps › + › New App:
- Platform iOS, name **Morse Than Words**, primary language English (U.S.),
  bundle ID **com.norberttak.morsethanwords**, SKU **morsethanwords-ios**, full access.

Then fill in the fields from `docs/app-store/metadata.md` (app information, pricing = Free,
App Privacy = "Data Not Collected", age rating questionnaire = all "None").

## 4. Build and upload to TestFlight

One-time setup: register at least one device (connect your iPhone; the script registers paired
devices) and create a local **Apple Distribution** certificate (Xcode › Settings › Accounts ›
Manage Certificates › + › Apple Distribution).

```sh
./scripts/archive.sh
```

This runs the privacy and metadata checks, archives, exports and re-signs the app, and writes
`build/export/MorseThanWords.ipa`. The re-signing works around an Xcode bug: its distribution
signing encodes the "Á" in the certificate name differently from the certificate, which App Store
Connect rejects as an invalid signature (details in the script).

Upload the .ipa with Apple's **Transporter** app (Mac App Store): sign in with your Apple ID, drag
the file in, click **Deliver**. After processing (~15–30 min) the build appears under TestFlight.
Add yourself as an internal tester and install it with the TestFlight app on **your iPhone and
your iPad**.

## 5. Check on real devices (P8 exit criterion)

Use the manual checklist in PLAN.md §3.4: audio quality and no clicks, the silent switch,
a phone call interrupting playback, Bluetooth headphones, rotation and Split View on iPad,
largest text size, VoiceOver, and airplane mode.

## 6. Submit for review

1. Upload the screenshots from `docs/app-store/screenshots/iPhone17Pro/` (iPhone 6.3" display,
   1206 × 2622) and `docs/app-store/screenshots/iPadPro13inchM5/` (iPad 13" display), and the
   app preview `docs/app-store/preview/app-preview-iphone.mp4` (886 × 1920) under iPhone 6.3".
2. Select the TestFlight build on the version page, paste the review notes, and submit.

## Re-generating assets

- Screenshots: `./scripts/make-screenshots.sh` (or pass a simulator name for one device)
- App preview: `./scripts/make-app-preview.sh`
- App icon: `swift scripts/make-app-icon.swift`
- Metadata limits: `./scripts/check-metadata.py`
- Bump the build number (`CURRENT_PROJECT_VERSION` in `project.yml`) for every upload.
