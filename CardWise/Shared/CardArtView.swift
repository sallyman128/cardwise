import SwiftUI

/// A small rendering of a card in its issuer's color.
struct CardArtView: View {
    enum Size {
        case small, medium, large

        var width: CGFloat {
            switch self {
            case .small: 52
            case .medium: 96
            case .large: 300
            }
        }
    }

    let name: String
    let issuer: String
    let colorHex: String
    var size: Size = .small

    private var base: Color { Color(hex: colorHex) }
    private var foreground: Color { Color(hex: colorHex).isLight ? .black.opacity(0.8) : .white }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size == .large ? 16 : size.width * 0.09, style: .continuous)
        shape
            .fill(
                LinearGradient(
                    colors: [base.mix(with: .white, by: 0.12), base, base.mix(with: .black, by: 0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
            .overlay(alignment: .topLeading) {
                if size == .large {
                    Text(issuer.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(foreground.opacity(0.8))
                        .padding(16)
                }
            }
            .overlay(alignment: .leading) {
                if size != .small {
                    RoundedRectangle(cornerRadius: size == .large ? 5 : 2)
                        .fill(LinearGradient(colors: [.yellow.opacity(0.9), .orange.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                        .frame(width: size.width * 0.13, height: size.width * 0.1)
                        .padding(.leading, size.width * 0.08)
                        .opacity(0.85)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if size == .large {
                    Text(name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(foreground)
                        .padding(16)
                }
            }
            .frame(width: size.width, height: size.width * 0.63)
            .shadow(color: .black.opacity(size == .large ? 0.25 : 0.12), radius: size == .large ? 12 : 2, y: size == .large ? 6 : 1)
            .accessibilityHidden(true)
    }
}

extension CardArtView {
    init(_ card: CardRewards, size: Size = .small) {
        self.init(name: card.name, issuer: card.issuer, colorHex: card.colorHex, size: size)
    }

    init(_ card: UserCard, size: Size = .small) {
        self.init(name: card.displayName, issuer: card.issuer, colorHex: card.colorHex, size: size)
    }

    init(_ card: CatalogCard, size: Size = .small) {
        self.init(name: card.name, issuer: card.issuer, colorHex: card.color, size: size)
    }
}

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
