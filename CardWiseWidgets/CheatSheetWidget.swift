import SwiftUI
import WidgetKit

@main
struct CardWiseWidgets: WidgetBundle {
    var body: some Widget {
        CheatSheetWidget()
    }
}

struct CheatSheetEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has saved one, i.e. before the user adds cards.
    let sheet: CheatSheet?
}

struct CheatSheetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheatSheetEntry {
        CheatSheetEntry(date: .now, sheet: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheatSheetEntry) -> Void) {
        completion(CheatSheetEntry(date: .now, sheet: CheatSheet.load() ?? .placeholder))
    }

    /// The sheet only changes when the app republishes it, which reloads the timeline.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CheatSheetEntry>) -> Void) {
        completion(Timeline(entries: [CheatSheetEntry(date: .now, sheet: CheatSheet.load())], policy: .never))
    }
}

struct CheatSheetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CheatSheet", provider: CheatSheetProvider()) { entry in
            CheatSheetWidgetView(sheet: entry.sheet)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Best Card")
        .description("Your best card for each kind of purchase.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct CheatSheetWidgetView: View {
    let sheet: CheatSheet?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let sheet, !sheet.rows.isEmpty {
            switch family {
            case .accessoryRectangular: LockScreenView(rows: Array(sheet.rows.prefix(3)))
            case .systemSmall: SmallView(rows: Array(sheet.rows.prefix(4)))
            case .systemMedium: MediumView(rows: sheet.rows)
            default: LargeView(sheet: sheet)
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "creditcard")
                    .font(.title3)
                Text("Add your cards in CardWise")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Families

/// Lock Screen: three lines, monochrome.
private struct LockScreenView: View {
    let rows: [CheatSheet.Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(rows) { row in
                HStack(spacing: 4) {
                    Image(systemName: row.symbol)
                        .frame(width: 14)
                    Text(row.cardName)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text(row.rate)
                        .fontWeight(.semibold)
                }
                .font(.caption)
            }
        }
    }
}

private struct SmallView: View {
    let rows: [CheatSheet.Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    Image(systemName: row.symbol)
                        .font(.caption)
                        .foregroundStyle(Color(hex: row.colorHex))
                        .frame(width: 16)
                    Text(row.cardName)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Text(row.rate)
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
            }
        }
    }
}

private struct MediumView: View {
    let rows: [CheatSheet.Row]

    var body: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    Image(systemName: row.symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.title)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(row.cardName)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer(minLength: 0)
                    Text(row.rate)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color(hex: row.colorHex).isLight ? .black : .white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: row.colorHex), in: .capsule)
                }
            }
        }
    }
}

private struct LargeView: View {
    let sheet: CheatSheet

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Best Card")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Label(sheet.goalTitle, systemImage: "target")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.bottom, 4)

            ForEach(Array(sheet.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider() }
                HStack(spacing: 8) {
                    Image(systemName: row.symbol)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(row.title)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(width: 96, alignment: .leading)
                    Text(row.cardName)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    CardChip(colorHex: row.colorHex, width: 24)
                    Text(row.rate)
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .frame(minWidth: 26, alignment: .trailing)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

/// A tiny card in the card's color.
private struct CardChip: View {
    let colorHex: String
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
            .fill(Color(hex: colorHex).gradient)
            .frame(width: width, height: width * 0.63)
    }
}

#Preview(as: .systemMedium) {
    CheatSheetWidget()
} timeline: {
    CheatSheetEntry(date: .now, sheet: .placeholder)
}
