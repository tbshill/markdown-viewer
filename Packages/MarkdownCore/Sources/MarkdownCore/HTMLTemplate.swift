import Foundation

/// Builds a self-contained HTML page around rendered markdown.
public enum HTMLTemplate {

    // MARK: Bundled resources (read once)

    private static let css: String = loadResource("markdown", "css")
    private static let viewerJS: String = loadResource("viewer", "js")
    private static let highlightJS: String = loadResource("highlight.min", "js", isScript: true)
    /// ~2.5 MB; only touched (and therefore only read from disk) when a document needs it.
    private static let mermaidJS: String = loadResource("mermaid.min", "js", isScript: true)

    private static func loadResource(_ name: String, _ ext: String, isScript: Bool = false) -> String {
        guard
            let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            assertionFailure("Missing bundled resource \(name).\(ext)")
            return ""
        }
        guard isScript || ext == "js" else { return text }
        // Make the script safe to inline inside <script>…</script>.
        return text
            .replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
            .replacingOccurrences(of: "<!--", with: "<\\!--")
    }

    // MARK: API

    /// Markdown -> full HTML document.
    public static func render(markdown: String, title: String, baseURL: URL?) -> String {
        page(body: MarkdownRenderer.renderHTML(markdown), title: title, baseURL: baseURL)
    }

    /// Wrap an HTML fragment in a full document with inlined CSS/JS.
    /// `baseURL` is accepted for API symmetry; callers pass it to `loadHTMLString(_:baseURL:)`.
    public static func page(body: String, title: String, baseURL: URL?) -> String {
        _ = baseURL
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let needsMermaid = containsBytes(body, "class=\"language-mermaid\"")
        let needsHighlight = containsBytes(body, "class=\"language-")

        let csp = [
            "default-src 'none'",
            "script-src 'nonce-\(nonce)'",
            "style-src 'unsafe-inline'",
            "img-src file: data: blob: https: http:",
            "font-src data:",
            "media-src file: https: http:",
            "connect-src 'none'",
            "frame-src 'none'",
            "object-src 'none'",
            "base-uri 'none'",
            "form-action 'none'",
        ].joined(separator: "; ")

        var html = String()
        html.reserveCapacity(body.utf8.count + css.utf8.count + 16_384
            + (needsHighlight ? highlightJS.utf8.count : 0)
            + (needsMermaid ? mermaidJS.utf8.count : 0))

        html += "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n"
        html += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        html += "<meta name=\"color-scheme\" content=\"light dark\">\n"
        html += "<meta http-equiv=\"Content-Security-Policy\" content=\"\(csp)\">\n"
        html += "<title>\(escape(title))</title>\n"
        html += "<style>\n\(css)\n</style>\n</head>\n<body>\n<article class=\"markdown-body\">\n"
        html += body
        html += "\n</article>\n"
        if needsHighlight {
            html += "<script nonce=\"\(nonce)\">\(highlightJS)</script>\n"
        }
        if needsMermaid {
            html += "<script nonce=\"\(nonce)\">\(mermaidJS)</script>\n"
        }
        html += "<script nonce=\"\(nonce)\">\(viewerJS)</script>\n"
        html += "</body>\n</html>\n"
        return html
    }

    // MARK: Helpers

    private static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
        }
        return out
    }

    /// Fast byte search that avoids Foundation's bridging of multi-megabyte strings.
    private static func containsBytes(_ haystack: String, _ needle: String) -> Bool {
        var h = haystack
        var n = needle
        return h.withUTF8 { hb in
            n.withUTF8 { nb in
                guard let hp = hb.baseAddress, let np = nb.baseAddress,
                      nb.count > 0, hb.count >= nb.count else { return false }
                return memmem(hp, hb.count, np, nb.count) != nil
            }
        }
    }
}
