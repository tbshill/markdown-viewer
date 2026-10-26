import Foundation

/// Watches a single path for modification, deletion or replacement.
///
/// Editors commonly save atomically (write temp file, rename over the original), which
/// invalidates the watched file descriptor. On `.delete`/`.rename` we therefore close the
/// descriptor and re-open the path (retrying briefly until the new file appears).
final class FileWatcher: @unchecked Sendable {
    private let url: URL
    private let queue = DispatchQueue(label: "com.tbshill.MarkdownViewer.FileWatcher")
    private let onChange: @Sendable () -> Void

    // All mutable state below is only touched on `queue`.
    private var source: DispatchSourceFileSystemObject?
    private var debounceItem: DispatchWorkItem?
    private var stopped = false

    init(url: URL, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    func start() {
        queue.async { [self] in
            stopped = false
            attach(retries: 0)
        }
    }

    func stop() {
        queue.async { [self] in
            stopped = true
            debounceItem?.cancel()
            debounceItem = nil
            source?.cancel()
            source = nil
        }
    }

    deinit {
        // `stop()` may not have run; cancelling the source closes the descriptor.
        source?.cancel()
    }

    private func attach(retries: Int) {
        guard !stopped else { return }
        let fd = Darwin.open(url.path, O_EVTONLY)
        if fd < 0 {
            if retries < 20 {
                queue.asyncAfter(deadline: .now() + 0.25) { [self] in attach(retries: retries + 1) }
            }
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename, .attrib, .link],
            queue: queue
        )
        src.setEventHandler { [weak self, weak src] in
            guard let self, let src else { return }
            let flags = src.data
            self.scheduleNotify()
            if !flags.isDisjoint(with: [.delete, .rename, .link]) {
                // The inode we watch is gone: drop it and watch whatever now lives at the path.
                src.cancel()
                self.source = nil
                self.queue.asyncAfter(deadline: .now() + 0.05) { self.attach(retries: 0) }
            }
        }
        src.setCancelHandler { Darwin.close(fd) }
        source = src
        src.resume()
    }

    private func scheduleNotify() {
        debounceItem?.cancel()
        let item = DispatchWorkItem { [onChange] in onChange() }
        debounceItem = item
        queue.asyncAfter(deadline: .now() + 0.12, execute: item)
    }
}
