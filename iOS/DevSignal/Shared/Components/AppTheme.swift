import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Color {
    static let dsBackground = Color(uiColor: .systemGroupedBackground)
    static let dsPlainBackground = Color(uiColor: .systemBackground)
    static let dsSurface = Color(uiColor: .secondarySystemBackground)
    static let dsGroupedSurface = Color(uiColor: .secondarySystemGroupedBackground)
    static let dsElevatedSurface = Color(uiColor: .tertiarySystemBackground)
    static let dsElevatedGroupedSurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let dsMuted = Color(uiColor: .secondaryLabel)
    static let dsAccent = Color(uiColor: .systemIndigo)
}
