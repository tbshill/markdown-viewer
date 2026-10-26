import XCTest
@testable import MarkdownCore

final class MarkdownRendererTests: XCTestCase {

    func testTable() {
        let html = MarkdownRenderer.renderHTML("""
        | a | b |
        |:--|--:|
        | 1 | 2 |
        """)
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<th"))
        XCTAssertTrue(html.contains("<td"))
    }

    func testTaskList() {
        let html = MarkdownRenderer.renderHTML("- [x] done\n- [ ] todo\n")
        XCTAssertEqual(html.components(separatedBy: "type=\"checkbox\"").count - 1, 2)
        XCTAssertTrue(html.contains("checked"))
    }

    func testStrikethrough() {
        XCTAssertTrue(MarkdownRenderer.renderHTML("~~gone~~ and ~one~").contains("<del>gone</del>"))
    }

    func testAutolink() {
        let html = MarkdownRenderer.renderHTML("Visit https://example.com/path and www.example.org now")
        XCTAssertTrue(html.contains("<a href=\"https://example.com/path\">"))
        XCTAssertTrue(html.contains("href=\"http://www.example.org\""))
    }

    func testFootnotes() {
        let html = MarkdownRenderer.renderHTML("Text[^1]\n\n[^1]: The note.\n")
        XCTAssertTrue(html.contains("footnote"))
        XCTAssertTrue(html.contains("The note."))
    }

    func testFencedCodeLanguageClass() {
        let html = MarkdownRenderer.renderHTML("```swift\nlet x = 1\n```\n")
        XCTAssertTrue(html.contains("<pre><code class=\"language-swift\">"))
    }

    func testMermaidFenceEmitsLanguageClass() {
        let html = MarkdownRenderer.renderHTML("```mermaid\ngraph TD; A-->B\n```\n")
        XCTAssertTrue(html.contains("class=\"language-mermaid\""))
    }

    func testTagfilterBlocksScript() {
        let html = MarkdownRenderer.renderHTML("<script>alert(1)</script>\n\nhello <iframe src=x></iframe>")
        XCTAssertFalse(html.contains("<script"))
        XCTAssertFalse(html.contains("<iframe"))
        XCTAssertTrue(html.contains("&lt;script"))
    }

    func testRawHTMLAllowed() {
        let html = MarkdownRenderer.renderHTML("<details><summary>More</summary>\n\nhidden\n\n</details>")
        XCTAssertTrue(html.contains("<details>"))
    }

    func testEmptyInput() {
        XCTAssertEqual(MarkdownRenderer.renderHTML(""), "")
    }

    func testUnicode() {
        XCTAssertTrue(MarkdownRenderer.renderHTML("# Héllo 世界 🎉").contains("Héllo 世界 🎉"))
    }

    // MARK: Template

    func testMermaidInlinedOnlyWhenNeeded() {
        let plain = HTMLTemplate.render(markdown: "# hi\n\n```swift\nlet a = 1\n```\n", title: "t", baseURL: nil)
        let withMermaid = HTMLTemplate.render(markdown: "```mermaid\ngraph TD; A-->B\n```\n", title: "t", baseURL: nil)
        XCTAssertLessThan(plain.utf8.count, 500_000)
        XCTAssertGreaterThan(withMermaid.utf8.count, 1_000_000)
    }

    func testTemplateHasCSPAndEscapesTitle() {
        let page = HTMLTemplate.render(markdown: "x", title: "<b>&", baseURL: nil)
        XCTAssertTrue(page.contains("Content-Security-Policy"))
        XCTAssertTrue(page.contains("<title>&lt;b&gt;&amp;</title>"))
        XCTAssertTrue(page.contains("window.__restoreScroll"))
    }

    // MARK: Performance

    func testRenderLargeDocumentPerformance() {
        let section = """
        ## Section

        Some *emphasis*, **strong**, `code`, a [link](https://example.com) and ~~strike~~.

        | A | B | C |
        |---|:-:|--:|
        | 1 | 2 | 3 |

        - [x] item
        - [ ] item

        ```swift
        func f(_ x: Int) -> Int { x * 2 }
        ```


        """
        var doc = ""
        while doc.utf8.count < 5_000_000 { doc += section }

        // Manual timing (not `measure`): on Linux XCTest fails measure blocks whose
        // relative deviation exceeds 10%, which makes this test flaky.
        let start = Date()
        let htmlCount = MarkdownRenderer.renderHTML(doc).utf8.count
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(htmlCount, 5_000_000)
        XCTAssertLessThan(elapsed, 10, "rendering 5 MB took \(elapsed)s")
    }
}
