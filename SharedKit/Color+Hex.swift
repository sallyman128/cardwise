import SwiftUI

extension Color {
    /// Accepts "#RRGGBB". Falls back to gray.
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(digits, radix: 16) ?? 0x808080
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Whether dark text reads better on this color.
    var isLight: Bool {
        let resolved = resolve(in: EnvironmentValues())
        let luminance = 0.2126 * Double(resolved.red) + 0.7152 * Double(resolved.green) + 0.0722 * Double(resolved.blue)
        return luminance > 0.45  // resolved components are linear sRGB
    }
}
