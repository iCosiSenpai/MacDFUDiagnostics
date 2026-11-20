import Foundation

/// Runs command-line tools. Every tool is launched by absolute path with an argument array — nothing
/// here goes through a shell, so no argument is ever re-parsed.
enum ProcessRunner {
    struct Result: Sendable {
        let status: Int32
        let output: String

        var succeeded: Bool { status == 0 }
    }

    /// Blocking waits live on their own queue so they never occupy a Swift concurrency thread.
    private static let queue = DispatchQueue(label: "MacDFUStudio.ProcessRunner", qos: .userInitiated, attributes: .concurrent)

    /// Runs a tool to completion and returns its combined output.
    static func run(_ executable: String, _ arguments: [String]) async -> Result {
        await withCheckedContinuation { continuation in
            queue.async {
                let process = Process()
                process.executableURL = URL(filePath: executable)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                process.standardInput = FileHandle.nullDevice
                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: Result(status: process.terminationStatus, output: text))
                } catch {
                    continuation.resume(returning: Result(status: -1, output: error.localizedDescription))
                }
            }
        }
    }

    /// POSIX single-quoting, for the one place a shell is unavoidable (the administrator prompt).
    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// A long-running tool whose output is wanted line by line while it runs, and which can be stopped.
final class StreamingProcess: @unchecked Sendable {
    private let process = Process()
    private let lock = NSLock()
    private var pending = Data()
    private var didStart = false
    private var outputClosed = false
    private var exitStatus: Int32 = -1

    /// Launches the tool and suspends until it has exited *and* its output has been read to the end.
    /// `onLine` is called, in order, for every complete line; a carriage return ends a line too, since
    /// progress output rewrites itself in place.
    func run(_ executable: String, _ arguments: [String], onLine: @escaping @Sendable (String) -> Void) async -> Int32 {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int32, Never>) in
            let pipe = Pipe()
            let reader = pipe.fileHandleForReading
            process.executableURL = URL(filePath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            process.standardInput = FileHandle.nullDevice

            // Two things have to happen before the caller continues: the tool exits, and the last of
            // its output is delivered. They arrive on different queues in either order.
            let finished = DispatchGroup()
            finished.enter() // output
            finished.enter() // exit

            let closeOutput: @Sendable () -> Void = { [weak self] in
                guard let self else { return }
                let firstTime = self.lock.withLock {
                    defer { self.outputClosed = true }
                    return !self.outputClosed
                }
                guard firstTime else { return }
                reader.readabilityHandler = nil
                self.consume(Data(), flush: true).forEach(onLine)
                finished.leave()
            }

            reader.readabilityHandler = { [weak self] handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    closeOutput() // end of file
                } else {
                    self?.consume(chunk, flush: false).forEach(onLine)
                }
            }

            process.terminationHandler = { [weak self] exited in
                self?.lock.withLock { self?.exitStatus = exited.terminationStatus }
                finished.leave()
                // A child the tool left behind can keep the pipe open; do not wait on it forever.
                DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: closeOutput)
            }

            // The status is recorded by the termination handler: asking a process that never launched
            // for its status raises an exception.
            finished.notify(queue: .global()) { [self] in
                continuation.resume(returning: lock.withLock { exitStatus })
            }

            do {
                try process.run()
                lock.withLock { didStart = true }
            } catch {
                process.terminationHandler = nil
                onLine(error.localizedDescription)
                closeOutput()
                finished.leave()
            }
        }
    }

    /// Asks the tool to stop (SIGTERM). Safe to call at any time, from any thread.
    func stop() {
        let started = lock.withLock { didStart }
        if started, process.isRunning {
            process.terminate()
        }
    }

    /// Appends a chunk and returns the lines it completed. A chunk can end mid-line, so the remainder
    /// is held until the rest arrives.
    private func consume(_ chunk: Data, flush: Bool) -> [String] {
        lock.withLock {
            pending.append(chunk)
            var lines: [String] = []
            while let end = pending.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
                let line = pending[pending.startIndex..<end]
                pending.removeSubrange(pending.startIndex...end)
                if !line.isEmpty { lines.append(String(decoding: line, as: UTF8.self)) }
            }
            if flush, !pending.isEmpty {
                lines.append(String(decoding: pending, as: UTF8.self))
                pending.removeAll()
            }
            return lines
        }
    }
}
