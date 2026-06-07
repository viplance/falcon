import Foundation

// File-based logger. Writes to ~/Library/Logs/FalconShot/falconshot.log
// so you can follow output without Xcode: tail -f ~/Library/Logs/FalconShot/falconshot.log
// Rolls the file at ~200 KB, keeping the newest ~100 KB.
enum Log {

    private static let queue = DispatchQueue(label: "enotix.FalconShot.log")

    static let fileURL: URL = {
        // FileManager.urls(for:in:) respects the App Sandbox and returns a path
        // inside ~/Library/Containers/enotix.FalconShot/Data/Library/Logs —
        // writable without extra entitlements.
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let dir = library.appendingPathComponent("Logs/FalconShot", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("falconshot.log")
    }()

    static func info(_ message: String)  { write("INFO ", message) }
    static func debug(_ message: String) { write("DEBUG", message) }
    static func error(_ message: String) { write("ERROR", message) }

    private static func write(_ level: String, _ message: String) {
        let line = "[\(timestamp())] \(level)  \(message)\n"
        print(line, terminator: "")
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try? data.write(to: fileURL)
                return
            }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
            trim()
        }
    }

    private static func trim() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? UInt64, size > 200_000,
              let data = try? Data(contentsOf: fileURL) else { return }
        try? data.suffix(100_000).write(to: fileURL)
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
