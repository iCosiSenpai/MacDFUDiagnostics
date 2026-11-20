import Foundation
import IOKit

/// Tells the app the moment something is plugged in or pulled out, instead of asking every few seconds.
///
/// IOKit delivers a notification when a USB device or a disk appears or goes away; the callback only
/// reports *that* something changed, and the engine rescans. Idle cost is zero.
final class HardwareWatcher: @unchecked Sendable {
    enum Change: Sendable {
        case usb
        case disk
    }

    private let port: IONotificationPortRef
    private let queue = DispatchQueue(label: "MacDFUStudio.HardwareWatcher", qos: .utility)
    private var iterators: [io_iterator_t] = []
    private var contexts: [Unmanaged<Context>] = []

    /// What a notification carries back: which kind of change, and where to report it.
    private final class Context {
        let change: Change
        let handler: @Sendable (Change) -> Void

        init(change: Change, handler: @escaping @Sendable (Change) -> Void) {
            self.change = change
            self.handler = handler
        }
    }

    init(onChange: @escaping @Sendable (Change) -> Void) {
        port = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(port, queue)

        watch(className: "IOUSBHostDevice", change: .usb, handler: onChange)
        watch(className: "IOMedia", change: .disk, handler: onChange)
    }

    deinit {
        iterators.forEach { IOObjectRelease($0) }
        IONotificationPortDestroy(port)
        contexts.forEach { $0.release() }
    }

    private func watch(className: String, change: Change, handler: @escaping @Sendable (Change) -> Void) {
        for notification in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            guard let matching = IOServiceMatching(className) else { continue }
            let context = Unmanaged.passRetained(Context(change: change, handler: handler))
            contexts.append(context)

            let callback: IOServiceMatchingCallback = { refcon, iterator in
                HardwareWatcher.drain(iterator)
                guard let refcon else { return }
                let context = Unmanaged<Context>.fromOpaque(refcon).takeUnretainedValue()
                context.handler(context.change)
            }

            var iterator: io_iterator_t = 0
            let status = IOServiceAddMatchingNotification(port, notification, matching, callback, context.toOpaque(), &iterator)
            guard status == KERN_SUCCESS else { continue }
            // A notification only re-arms once its iterator has been emptied — including the first time.
            HardwareWatcher.drain(iterator)
            iterators.append(iterator)
        }
    }

    private static func drain(_ iterator: io_iterator_t) {
        while case let object = IOIteratorNext(iterator), object != 0 {
            IOObjectRelease(object)
        }
    }
}
