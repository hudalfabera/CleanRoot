//
//  WebViewRepresentable.swift
//  CleanRoot
//


import SwiftUI
import WebKit
import Combine

struct WebViewRepresentable: NSViewRepresentable {

    @EnvironmentObject var appState: AppState

    // Default landing URL. Once login is detected, the coordinator
    // auto-navigates to `likesURL`.
    static let homeURL  = URL(string: "https://www.instagram.com/")!
    static let likesURL = URL(string: "https://www.instagram.com/your_activity/interactions/likes/")!

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    // MARK: - NSView lifecycle

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Persistent data store so cookies + login survive relaunches.
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Modern way to enable JS (replaces the deprecated javaScriptEnabled).
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pagePrefs

        // ─────────────────────────────────────────────────────────────────
        // User scripts
        //
        // IMPORTANT: We do NOT use MutationObserver here.
        // Earlier versions of these scripts observed document.head/documentElement
        // and re-applied changes on every mutation. Instagram's React app mutates
        // the head constantly (lazy-loaded styles/links), which created an
        // infinite feedback loop that crashed the page render — the symptom was
        // "login page flashes in then disappears, leaving only the footer".
        //
        // Each script below runs ONCE at the appropriate injection time and exits.
        // ─────────────────────────────────────────────────────────────────

        // Tells Instagram we have a wide viewport so it picks the desktop layout
        // even in compact windows. Runs at document-start, before React boots.
        let viewportScript = WKUserScript(
            source: """
            (function() {
                let meta = document.querySelector('meta[name="viewport"]');
                if (!meta) {
                    meta = document.createElement('meta');
                    meta.name = 'viewport';
                    document.head && document.head.appendChild(meta);
                }
                meta.setAttribute('content', 'width=1440, initial-scale=1');
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )

        // Instagram's left nav is position:fixed and clips its bottom items on
        // compact viewports. This CSS forces it to scroll internally instead.
        // Injected once at document-end, after the DOM is parsed.
        let navFixScript = WKUserScript(
            source: """
            (function() {
                if (document.getElementById('cleanroot-nav-fix')) return;
                const css = `
                    nav[role="navigation"],
                    div[role="navigation"] {
                        overflow-y: auto !important;
                        max-height: 100vh !important;
                    }
                `;
                const style = document.createElement('style');
                style.id = 'cleanroot-nav-fix';
                style.textContent = css;
                (document.head || document.documentElement).appendChild(style);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )

        // Polls the DOM a few times to detect a logged-in session. Only reports
        // back to Swift on a POSITIVE signal, then never again — this avoids
        // spamming the bridge and prevents accidental re-navigation loops.
        let loginDetectorScript = WKUserScript(
            source: """
            (function() {
                let reportedOnce = false;
                const detect = () => {
                    if (reportedOnce) return;
                    try {
                        const hasProfileLink  = !!document.querySelector('a[href^="/"][role="link"] img');
                        const hasCreateButton = !!document.querySelector('svg[aria-label="New post"], svg[aria-label="Create"]');
                        const hasLoginForm    = !!document.querySelector('input[name="username"], input[name="email"]');

                        const loggedIn = (hasProfileLink || hasCreateButton) && !hasLoginForm;
                        if (!loggedIn) return;

                        reportedOnce = true;
                        window.webkit.messageHandlers.cleanrootBridge.postMessage({
                            kind: "loginState",
                            loggedIn: true
                        });
                    } catch (e) { /* swallow — page may still be hydrating */ }
                };
                // Generous spacing so Instagram's SPA has time to hydrate
                setTimeout(detect, 2500);
                setTimeout(detect, 5000);
                setTimeout(detect, 9000);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )

        // Register scripts + the JS↔Swift message handler.
        let userContent = WKUserContentController()
        userContent.addUserScript(viewportScript)
        userContent.addUserScript(navFixScript)
        userContent.addUserScript(loginDetectorScript)

        // Defensive: SwiftUI may call makeNSView multiple times (layout
        // invalidation, view identity changes). Removing first avoids the
        // "handler already exists" exception on the second call.
        userContent.removeScriptMessageHandler(forName: Coordinator.bridgeName)
        userContent.add(context.coordinator, name: Coordinator.bridgeName)
        config.userContentController = userContent

        // Build the actual web view.
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        // Enable Safari Web Inspector for debugging (right-click → Inspect).
        // Requires macOS 13.3+. Safe to keep on in development builds.
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }

        // Real Safari UA so Instagram doesn't treat us like an embedded WebView
        // (which would otherwise nag for the native app).
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15"

        // NOTE: pageZoom is intentionally left at the default (1.0) for now.
        // We can re-introduce a zoom < 1.0 later for small-screen polish, but
        // only after confirming the page renders correctly first.

        // Hand the web view to the coordinator and wire up Combine bindings.
        context.coordinator.webView = webView
        context.coordinator.bindCommands()

        // Initial load — Instagram's home page. If the user is already logged
        // in, the detector script above will fire and the coordinator will
        // navigate to the Likes page automatically.
        webView.load(URLRequest(url: Self.homeURL))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No-op: commands flow through Combine, not view updates.
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        // Cleanly detach the script message handler. Without this, the
        // coordinator would be retained by WKUserContentController and we'd
        // leak it on every view tear-down.
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.bridgeName)
        coordinator.cancellables.removeAll()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

        // Channel name used by both Swift (this class) and JS
        // (window.webkit.messageHandlers.cleanrootBridge). They must match exactly.
        static let bridgeName = "cleanrootBridge"

        private let appState: AppState
        weak var webView: WKWebView?
        var cancellables = Set<AnyCancellable>()

        init(appState: AppState) {
            self.appState = appState
        }

        // MARK: Combine bindings — react to user actions from the sidebar

        func bindCommands() {
            appState.startSignal
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.injectUnlikerScript() }
                .store(in: &cancellables)

            appState.stopSignal
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.requestStop() }
                .store(in: &cancellables)

            appState.goToLikesSignal
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.navigateToLikes() }
                .store(in: &cancellables)
        }

        // MARK: JS injection

        // Loads unliker.js from the app bundle and evaluates it inside the
        // current page. The script then drives Instagram's DOM until completion
        // (or until the stop flag is set).
        private func injectUnlikerScript() {
            guard let webView else { return }

            guard
                let url = Bundle.main.url(forResource: "unliker", withExtension: "js"),
                let source = try? String(contentsOf: url, encoding: .utf8)
            else {
                Task { @MainActor in
                    self.appState.appendLog("Could not load unliker.js from bundle.", level: .error)
                    self.appState.reportRunFinished(reason: "error")
                }
                return
            }

            webView.evaluateJavaScript(source) { [weak self] _, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor in
                        self.appState.appendLog("JS injection failed: \(error.localizedDescription)", level: .error)
                        self.appState.reportRunFinished(reason: "error")
                    }
                }
            }
        }

        // Cooperative stop: flips a global JS flag that the unliker script
        // polls at every safe checkpoint. Never interrupts a deletion mid-flight.
        private func requestStop() {
            guard let webView else { return }
            webView.evaluateJavaScript("window.__cleanrootShouldStop = true;", completionHandler: nil)
        }

        // Navigates to the Likes page, closing any open Instagram modal first
        // (e.g. a post-detail overlay) so the underlying navigation actually shows.
        private func navigateToLikes() {
            guard let webView else { return }
            let dismissModalsJS = """
            (function() {
                const closeButtons = document.querySelectorAll('[aria-label="Close"]');
                closeButtons.forEach(btn => {
                    const dialog = btn.closest('[role="dialog"]');
                    if (dialog) btn.click();
                });
            })();
            """
            webView.evaluateJavaScript(dismissModalsJS) { [weak self] _, _ in
                guard let self, let webView = self.webView else { return }
                webView.load(URLRequest(url: WebViewRepresentable.likesURL))
            }
        }

        // MARK: WKScriptMessageHandler — messages coming from JS

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == Self.bridgeName else { return }

            // Expected payload kinds:
            //   { kind: "log", level: "...", message: "..." }
            //   { kind: "finished", reason: "completed" | "stopped" | "error" }
            //   { kind: "loginState", loggedIn: true }
            guard
                let dict = message.body as? [String: Any],
                let kind = dict["kind"] as? String
            else { return }

            switch kind {
            case "log":
                let text  = (dict["message"] as? String) ?? ""
                let level = (dict["level"]   as? String) ?? "info"
                Task { @MainActor in
                    self.appState.appendLog(text, levelRaw: level)
                }

            case "finished":
                let reason = (dict["reason"] as? String) ?? "completed"
                Task { @MainActor in
                    self.appState.reportRunFinished(reason: reason)
                }

            case "loginState":
                let loggedIn = (dict["loggedIn"] as? Bool) ?? false
                Task { @MainActor in
                    // AppState's flag guarantees we only auto-navigate once
                    // per session, even if the detector fires multiple times.
                    let shouldNavigate = self.appState.reportLoginState(loggedIn)
                    if shouldNavigate, let webView = self.webView {
                        // Tiny delay so the page is fully settled before we
                        // trigger another navigation.
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        webView.load(URLRequest(url: WebViewRepresentable.likesURL))
                    }
                }

            default:
                break
            }
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Page finished loading — let the UI flip its status pill to Ready.
            Task { @MainActor in
                self.appState.setPageReady(true)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                self.appState.appendLog("Navigation failed: \(error.localizedDescription)", level: .warning)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                self.appState.appendLog("Provisional navigation failed: \(error.localizedDescription)", level: .warning)
            }
        }
    }
}
