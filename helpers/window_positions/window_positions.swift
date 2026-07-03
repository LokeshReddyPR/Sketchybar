// Prints a JSON array of on-screen window positions: [{"id":<cgWindowId>,"x":..,"y":..}, ...]
// aerospace's window-id equals the CoreGraphics window number, so spaces.lua can
// join these positions to aerospace windows and order the app icons left-to-right.
import CoreGraphics
import Foundation

let opts = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
var parts: [String] = []
if let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] {
    for w in list {
        // Only normal application windows (layer 0)
        let layer = w[kCGWindowLayer as String] as? Int ?? -1
        guard layer == 0 else { continue }
        guard let num = w[kCGWindowNumber as String] as? Int else { continue }
        guard let b = w[kCGWindowBounds as String] as? [String: Any] else { continue }
        let x = Int((b["X"] as? Double) ?? 0)
        let y = Int((b["Y"] as? Double) ?? 0)
        parts.append("{\"id\":\(num),\"x\":\(x),\"y\":\(y)}")
    }
}
print("[" + parts.joined(separator: ",") + "]")
