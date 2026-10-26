import SwiftUI

struct DocumentView: View {
    let document: MarkdownDocument
    let fileURL: URL?

    @StateObject private var model = DocumentViewModel()
    @AppStorage("pageZoom") private var zoom: Double = 1.0

    private static let zoomRange: ClosedRange<Double> = 0.5...3.0

    var body: some View {
        MarkdownWebView(page: model.page, zoom: CGFloat(zoom))
            .frame(minWidth: 480, minHeight: 360)
            .focusedSceneValue(\.documentActions, actions)
            .onAppear { model.start(text: document.text, fileURL: fileURL) }
            .onDisappear { model.stop() }
    }

    private var actions: DocumentActions {
        DocumentActions(
            zoomIn: { zoom = min(Self.zoomRange.upperBound, (zoom + 0.1).rounded(toPlaces: 1)) },
            zoomOut: { zoom = max(Self.zoomRange.lowerBound, (zoom - 0.1).rounded(toPlaces: 1)) },
            resetZoom: { zoom = 1.0 },
            reload: { model.reload() }
        )
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}
