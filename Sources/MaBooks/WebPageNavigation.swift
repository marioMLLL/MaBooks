import Foundation
import AppKit

enum WebPageNavigation {
    static let script: String = {
        guard let url = Bundle.module.url(forResource: "WebPageNavigation", withExtension: "js"),
              let script = try? String(contentsOf: url, encoding: .utf8) else {
            preconditionFailure("Missing bundled WebPageNavigation.js")
        }
        return script.replacingOccurrences(of: "__DOUBLE_CLICK_DELAY__", with: String(Int(NSEvent.doubleClickInterval * 1000) + 20))
    }()
}
