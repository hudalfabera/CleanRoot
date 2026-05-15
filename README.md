# CleanRoot

A native macOS app to mass-unlike your Instagram likes.  
Opens Instagram in an embedded browser, lets you log in normally, and clicks through your liked posts in batches.

Built with SwiftUI and WKWebView. No API tokens, no third-party services — everything runs locally on your Mac.

## Why

Instagram doesn't offer a bulk-unlike feature. The Likes page only lets you select 25 posts at a time, and there's no way to automate it cleanly. CleanRoot fills that gap.

## Requirements

- macOS 14 or later
- Xcode 15+ (to build from source)

## Build from source

```bash
git clone https://github.com/hudalfabera/CleanRoot.git
cd CleanRoot
open CleanRoot.xcodeproj
```

In Xcode press ⌘R.

## How it works

1. The app loads `instagram.com` inside a WKWebView.
2. You log in manually (cookies persist between launches).
3. Once login is detected, the app navigates to *Your Activity → Likes*.
4. Pressing **Start Unliking** injects a JavaScript script that:
   - Locates the *Select* button by text (English, German, Turkish supported).
   - Selects up to 10 posts per batch with randomized delays (500–1200ms).
   - Triggers Instagram's *Unlike* confirmation modal.
   - Detects rate-limit dialogs and waits with exponential backoff.
5. The script reports progress back to Swift via a `WKScriptMessageHandler` bridge. The sidebar shows a live activity log and a counter.

## Project structure

CleanRoot/
├── Models/
│   └── LogEntry.swift            # Typed log entry
├── ViewModels/
│   └── AppState.swift            # Single source of truth
├── Views/
│   ├── ContentView.swift
│   ├── Sidebar/                  # Sidebar UI
│   └── WebView/
│       └── WebViewRepresentable.swift  # WKWebView + JS bridge
└── Resources/
└── unliker.js                # DOM automation script

## Disclaimer

This is an unofficial tool provided **for educational and personal-use purposes only**. Automating actions on Instagram may violate their [Terms of Use](https://help.instagram.com/581066165581870), and heavy use can result in account restrictions or suspension.

**Use entirely at your own risk.** The author accepts no responsibility for any consequences arising from the use of this software.

This project is **not affiliated with, endorsed by, or sponsored by** Meta Platforms, Inc. or Instagram.

Please read [DISCLAIMER.md](DISCLAIMER.md) before using.

## License

MIT — see [LICENSE](LICENSE).

---

Made by [Hüdalfa Bera](https://github.com/hudalfabera).
