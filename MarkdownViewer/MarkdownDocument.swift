import SwiftUI
import UniformTypeIdentifiers

/// Read-only markdown document. Rendering reads the file again from disk (for live reload),
/// so `text` is only the initial snapshot / fallback for documents without a file URL.
struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType(importedAs: "net.daringfireball.markdown"), .plainText]
    }

    // Viewer only: never offered for saving.
    static var writableContentTypes: [UTType] { [] }

    var text: String

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = MarkdownDocument.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }

    /// UTF-8 (BOM tolerated), falling back to ISO Latin-1 which never fails.
    static func decode(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) { return s }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }
}
