import SwiftUI
import WebKit
import AppKit

struct MarkdownWebView: NSViewRepresentable {
    let page: RenderedPage?
    let zoom: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        // Avoid a white flash before the page paints in dark mode.
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.pageZoom != zoom { webView.pageZoom = zoom }
        if let page { context.coordinator.load(page, in: webView) }
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private var loadedID: Int?
        private var currentPage: RenderedPage?
        private var pendingScrollY: Double?
        private var hasLoadedBefore = false

        func load(_ page: RenderedPage, in webView: WKWebView) {
            guard page.id != loadedID else { return }
            loadedID = page.id
            currentPage = page

            guard hasLoadedBefore else {
                hasLoadedBefore = true
                webView.loadHTMLString(page.html, baseURL: page.baseURL)
                return
            }
            // Live reload: remember the scroll position, reload, restore in didFinish.
            webView.evaluateJavaScript("window.scrollY") { [weak self, weak webView] result, _ in
                guard let self, let webView, self.loadedID == page.id else { return }
                self.pendingScrollY = (result as? NSNumber)?.doubleValue
                webView.loadHTMLString(page.html, baseURL: page.baseURL)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let y = pendingScrollY else { return }
            pendingScrollY = nil
            if y > 0 {
                webView.evaluateJavaScript("window.__restoreScroll && window.__restoreScroll(\(y))", completionHandler: nil)
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // The web content process was killed (memory pressure etc.): reload the last page.
            if let page = currentPage {
                webView.loadHTMLString(page.html, baseURL: page.baseURL)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Our own loadHTMLString (and sub-frame/resource loads) are not link clicks.
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)

            switch url.scheme?.lowercased() {
            case "http", "https", "mailto":
                NSWorkspace.shared.open(url)
            case "file":
                openRelativeFile(url)
            default:
                // In-page anchors are handled in viewer.js; anything else is ignored.
                break
            }
        }

        private func openRelativeFile(_ url: URL) {
            var clean = URLComponents(url: url, resolvingAgainstBaseURL: false)
            clean?.fragment = nil
            clean?.query = nil
            guard let target = clean?.url else { return }
            let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn", "mdwn"]
            guard markdownExtensions.contains(target.pathExtension.lowercased()),
                  FileManager.default.fileExists(atPath: target.path) else { return }
            // Open in this app (new window / existing window for that document).
            NSDocumentController.shared.openDocument(withContentsOf: target, display: true) { _, _, error in
                if error != nil {
                    // Sandbox may deny reading siblings of the current document; let Launch Services handle it.
                    NSWorkspace.shared.open(target)
                }
            }
        }
    }
}
