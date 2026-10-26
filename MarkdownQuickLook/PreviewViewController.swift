import Cocoa
import Quartz
import WebKit
import MarkdownCore

final class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {

    private var webView: WKWebView!
    private var loadContinuation: CheckedContinuation<Void, Never>?

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let size = NSSize(width: 900, height: 1000)
        let web = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: configuration)
        web.autoresizingMask = [.width, .height]
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")
        webView = web
        view = web
        preferredContentSize = size
    }

    func preparePreviewOfFile(at url: URL) async throws {
        _ = view // make sure loadView() has run

        let base = url.deletingLastPathComponent()
        let title = url.lastPathComponent

        // Read + parse + render off the main thread.
        let html = try await Task.detached(priority: .userInitiated) { () throws -> String in
            let data = try Data(contentsOf: url)
            let markdown = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""
            return HTMLTemplate.render(markdown: markdown, title: title, baseURL: base)
        }.value

        await loadAndWait(html: html, baseURL: base)
    }

    // MARK: Loading

    /// Returns once the page finished loading (or after ~2 s), so Quick Look never shows a blank pane.
    private func loadAndWait(html: String, baseURL: URL) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            finishPendingLoad() // never leak a previous continuation
            loadContinuation = continuation
            webView.loadHTMLString(html, baseURL: baseURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.finishPendingLoad()
            }
        }
    }

    private func finishPendingLoad() {
        guard let continuation = loadContinuation else { return }
        loadContinuation = nil
        continuation.resume()
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishPendingLoad()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishPendingLoad()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishPendingLoad()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Allow our own loadHTMLString; block every link click. In-page anchors are handled in viewer.js.
        if navigationAction.navigationType == .linkActivated {
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
