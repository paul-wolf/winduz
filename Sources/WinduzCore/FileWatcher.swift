import Foundation

/// Watches a file for any change (including atomic replacement) and calls the handler on the main queue.
public final class FileWatcher {
    private let url: URL
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private let handler: () -> Void

    public init(url: URL, handler: @escaping () -> Void) {
        self.url = url
        self.handler = handler
    }

    public func start() {
        arm()
    }

    public func stop() {
        source?.cancel()
        source = nil
    }

    private func arm() {
        source?.cancel()
        if !FileManager.default.fileExists(atPath: url.path) {
            try? Data("[]".utf8).write(to: url)
        }
        fd = open(url.path, O_EVTONLY)
        guard fd != -1 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            self.handler()
            let flags = src.data
            if flags.contains(.delete) || flags.contains(.rename) {
                self.arm()  // atomic rename replaced the inode; re-open
            }
        }
        src.setCancelHandler { [fd = self.fd] in
            if fd != -1 { close(fd) }
        }
        src.resume()
        source = src
    }
}
