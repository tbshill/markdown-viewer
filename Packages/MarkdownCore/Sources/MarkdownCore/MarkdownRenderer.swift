import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Converts GitHub Flavored Markdown to an HTML fragment using cmark-gfm.
public enum MarkdownRenderer {

    /// Registering the core extensions is idempotent but not thread-safe in C;
    /// a Swift `static let` gives us thread-safe one-time initialisation.
    private static let registerExtensions: Void = {
        cmark_gfm_core_extensions_ensure_registered()
    }()

    private static let extensionNames = ["table", "strikethrough", "autolink", "tagfilter", "tasklist"]

    /// Render `markdown` to an HTML fragment (no `<html>` wrapper).
    ///
    /// Raw HTML is passed through (CMARK_OPT_UNSAFE) so `<details>`, `<img>`, `<br>` work,
    /// but the `tagfilter` extension neutralises `<script>`, `<iframe>`, `<style>` etc., and
    /// `HTMLTemplate` adds a strict Content-Security-Policy as a second line of defence.
    public static func renderHTML(_ markdown: String) -> String {
        _ = registerExtensions

        let options: Int32 =
            Int32(CMARK_OPT_DEFAULT)
            | Int32(CMARK_OPT_FOOTNOTES)
            | Int32(CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE)
            | Int32(CMARK_OPT_VALIDATE_UTF8)
            | Int32(CMARK_OPT_UNSAFE)

        guard let parser = cmark_parser_new(options) else { return "" }
        // Declared first so it runs last: the extension list rendered below belongs to the parser.
        defer { cmark_parser_free(parser) }

        for name in extensionNames {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        var text = markdown
        text.withUTF8 { buffer in
            guard let base = buffer.baseAddress, buffer.count > 0 else { return }
            base.withMemoryRebound(to: CChar.self, capacity: buffer.count) { ptr in
                cmark_parser_feed(parser, ptr, buffer.count)
            }
        }

        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }

        let extensions = cmark_parser_get_syntax_extensions(parser)
        guard let cString = cmark_render_html(document, options, extensions) else { return "" }
        defer { free(cString) }

        return String(cString: cString)
    }
}
