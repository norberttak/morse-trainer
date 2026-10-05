#!/bin/sh
# Fails if networking, analytics, tracking or purchase APIs appear in the app sources.
# The app must not collect user data and must not have a paywall (see CLAUDE.md).
set -eu
cd "$(dirname "$0")/.."

pattern='URLSession|NWConnection|NSURLConnection|CFNetwork|import Network|ASIdentifierManager|AppTrackingTransparency|import StoreKit|Analytics|Crashlytics|Firebase'

if grep -rnE "$pattern" --include='*.swift' MorseThanWords Packages/MorseKit/Sources; then
    echo "error: forbidden networking/tracking/paywall API found (see above)" >&2
    exit 1
fi
echo "privacy check passed"
