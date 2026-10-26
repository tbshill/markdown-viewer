import SwiftUI
import MarkdownCore

struct RenderedPage: Equatable {
    let id: Int
    let html: String
    let baseURL: URL?
}

@MainActor
final class DocumentViewModel: ObservableObject {
    @Published private(set) var page: RenderedPage?

    private var fileURL: URL?
    private var fallbackText = ""
    private var title = ""
    private var watcher: FileWatcher?
    private var renderTask: Task<Void, Never>?
    private var generation = 0

    func start(text: String, fileURL: URL?) {
        stop()
        self.fallbackText = text
        self.fileURL = fileURL
        self.title = fileURL?.lastPathComponent ?? "Markdown"
        if let fileURL {
            let w = FileWatcher(url: fileURL) { [weak self] in
                Task { @MainActor in self?.reload() }
            }
            w.start()
            watcher = w
        }
        reload()
    }

    func stop() {
        watcher?.stop()
        watcher = nil
        renderTask?.cancel()
        renderTask = nil
    }

    func reload() {
        generation += 1
        let gen = generation
        renderTask?.cancel()

        let url = fileURL
        let fallback = fallbackText
        let title = self.title
        let base = url?.deletingLastPathComponent()

        renderTask = Task { [weak self] in
            // Parse + render + template off the main thread.
            let html: String? = await Task.detached(priority: .userInitiated) { () -> String? in
                let markdown: String
                if let url {
                    // A failed read (e.g. mid-save) keeps the current page; the watcher will fire again.
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    markdown = MarkdownDocument.decode(data)
                } else {
                    markdown = fallback
                }
                return HTMLTemplate.render(markdown: markdown, title: title, baseURL: base)
            }.value

            guard let self, !Task.isCancelled, gen == self.generation, let html else { return }
            self.page = RenderedPage(id: gen, html: html, baseURL: base)
        }
    }
}
