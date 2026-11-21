import CoreGraphics
import Foundation
// Prints "<id> <x> <y> <w> <h> <name>" for every on-screen layer-0 window of Mac DFU Studio, largest first.
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
var rows: [(Int, Double, Double, Double, Double, String)] = []
for w in list {
    guard let owner = w[kCGWindowOwnerName as String] as? String, owner == "Mac DFU Studio" || owner == "MacDFUDiagnostics" else { continue }
    guard (w[kCGWindowLayer as String] as? Int ?? -1) == 0 else { continue }
    let b = w[kCGWindowBounds as String] as? [String: Double] ?? [:]
    rows.append((w[kCGWindowNumber as String] as? Int ?? 0, b["X"] ?? 0, b["Y"] ?? 0, b["Width"] ?? 0, b["Height"] ?? 0, w[kCGWindowName as String] as? String ?? "-"))
}
for r in rows.sorted(by: { $0.3 * $0.4 > $1.3 * $1.4 }) { print(r.0, Int(r.1), Int(r.2), Int(r.3), Int(r.4), r.5) }
