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
    static let dsBackground = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(hex: 0x202940)
        }
        return .systemGroupedBackground
    })

    static let dsPlainBackground = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(hex: 0x202940)
        }
        return .systemBackground
    })

    static let dsSurface = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(hex: 0x4B4038)
        }
        return .secondarySystemBackground
    })

    static let dsGroupedSurface = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(hex: 0x4B4038)
        }
        return .secondarySystemGroupedBackground
    })

    static let dsElevatedSurface = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(hex: 0x4B4038, alpha: 0.92)
        }
        return .tertiarySystemBackground
    })

    static let dsElevatedGroupedSurface = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(hex: 0x4B4038, alpha: 0.92)
        }
        return .tertiarySystemGroupedBackground
    })

    static let dsMuted = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(hex: 0x9A8678)
        }
        return .secondaryLabel
    })

    static let dsAccent = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(hex: 0xCAAA98)
        }
        return .systemIndigo
    })
}
