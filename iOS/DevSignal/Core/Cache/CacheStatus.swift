import Foundation
import SwiftUI

enum CacheStatus: Equatable {
    case live
    case cached(Date)
    case stale(Date)

    var bannerText: String? {
        switch self {
        case .live:             return nil
        case .cached(let date): return "Offline — showing data from \(date.shortRelative)"
        case .stale(let date):  return "Stale data from \(date.shortRelative). Connect to refresh."
        }
    }

    var bannerColor: Color {
        switch self {
        case .live:    return .clear
        case .cached:  return .orange
        case .stale:   return .red
        }
    }
}

private extension Date {
    var shortRelative: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: self, relativeTo: Date())
    }
}
