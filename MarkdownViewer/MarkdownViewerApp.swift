import SwiftUI

@main
struct MarkdownViewerApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            DocumentView(document: file.document, fileURL: file.fileURL)
        }
        .commands {
            ViewCommands()
        }
    }
}

/// Actions the focused document window exposes to the menu bar.
struct DocumentActions {
    var zoomIn: () -> Void
    var zoomOut: () -> Void
    var resetZoom: () -> Void
    var reload: () -> Void
}

struct DocumentActionsKey: FocusedValueKey {
    typealias Value = DocumentActions
}

extension FocusedValues {
    var documentActions: DocumentActions? {
        get { self[DocumentActionsKey.self] }
        set { self[DocumentActionsKey.self] = newValue }
    }
}

struct ViewCommands: Commands {
    @FocusedValue(\.documentActions) private var actions

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()
            Button("Zoom In") { actions?.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(actions == nil)
            Button("Zoom Out") { actions?.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(actions == nil)
            Button("Actual Size") { actions?.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(actions == nil)
            Divider()
            Button("Reload") { actions?.reload() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(actions == nil)
        }
    }
}
