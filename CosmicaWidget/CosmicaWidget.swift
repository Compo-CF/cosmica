import SwiftUI
import WidgetKit

// v3.0.3 — Cosmica widgets.
//
// The app publishes a `WidgetSnapshot` to the shared App Group when it leaves
// the screen. Everything shown here is projected from that snapshot with the
// game's own offline-accrual math, so the widget needs no network and no
// refresh budget: one timeline covers the next 24 hours.

@main
struct CosmicaWidgetBundle: WidgetBundle {
    var body: some Widget {
        CosmicaHomeWidget()
        CosmicaLockWidget()
    }
}

/// Tapping any Cosmica widget lands on the Observatory (handled in CosmicaApp.onOpenURL).
private let observatoryURL = URL(string: "cosmica://observatory")

// MARK: - Widgets

struct CosmicaHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.homeKind, provider: CosmicaProvider()) { entry in
            CosmicaHomeView(entry: entry)
                .containerBackground(for: .widget) { SpaceBackground() }
                .widgetURL(observatoryURL)
        }
        .configurationDisplayName("Stardust Waiting")
        .description("Watch your stardust pile up while you're away, and see when offline earnings fill up.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CosmicaLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.lockKind, provider: CosmicaProvider()) { entry in
            CosmicaLockView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(observatoryURL)
        }
        .configurationDisplayName("Stardust Waiting")
        .description("Your waiting stardust and offline fill, right on the Lock Screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

// MARK: - Timeline

struct CosmicaEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct CosmicaProvider: TimelineProvider {
    func placeholder(in context: Context) -> CosmicaEntry {
        CosmicaEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (CosmicaEntry) -> Void) {
        let snap = WidgetSnapshot.load() ?? (context.isPreview ? .preview : nil)
        completion(CosmicaEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CosmicaEntry>) -> Void) {
        let now = Date()
        guard let snap = WidgetSnapshot.load() else {
            // Nothing published yet (app not opened since updating). The app
            // reloads us the first time it backgrounds.
            completion(Timeline(entries: [CosmicaEntry(date: now, snapshot: nil)], policy: .never))
            return
        }
        let entries = snap.timelineDates(from: now).map { CosmicaEntry(date: $0, snapshot: snap) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(86_400))))
    }
}

// MARK: - Home screen

struct CosmicaHomeView: View {
    let entry: CosmicaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snap = entry.snapshot, snap.baseRate > 0 {
            switch family {
            case .systemMedium:
                HStack(spacing: 14) {
                    WaitingColumn(snap: snap, date: entry.date)
                    Divider().overlay(Color.white.opacity(0.15))
                    StatsColumn(snap: snap, date: entry.date)
                }
            default:
                WaitingColumn(snap: snap, date: entry.date)
            }
        } else {
            EmptyStateView(hasSave: entry.snapshot != nil)
        }
    }
}

/// Headline: stardust waiting + how long until the offline window fills.
private struct WaitingColumn: View {
    let snap: WidgetSnapshot
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("COSMICA", systemImage: "sparkles")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))

            Spacer(minLength: 0)

            Text("+\(Formatter.short(snap.waiting(at: date))) ✦")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("waiting for you")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Spacer(minLength: 0)

            FillBar(snap: snap, date: date)
            FillLabel(snap: snap, date: date)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatsColumn: View {
    let snap: WidgetSnapshot
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(snap.tierTitle, systemImage: snap.tierSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("◈ \(Formatter.short(snap.cosmicShards)) shards")
            Text("\(snap.prestigeCount) Big Bang\(snap.prestigeCount == 1 ? "" : "s")")
            if snap.cosmosCount > 0 {
                Text("\(snap.cosmosCount) True Cosmos")
            }
            Spacer(minLength: 0)
            if snap.dailyRewardReady(at: date) {
                Label("Daily reward ready", systemImage: "gift.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Progress through the offline window. The timer-interval form animates on its
/// own between timeline entries.
private struct FillBar: View {
    let snap: WidgetSnapshot
    let date: Date

    var body: some View {
        Group {
            if snap.isFull(at: date) || snap.fullAt <= snap.savedAt {
                ProgressView(value: 1.0)
            } else {
                ProgressView(timerInterval: snap.savedAt...snap.fullAt, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            }
        }
        .tint(.purple)
    }
}

/// "Full in 3 hr, 12 min" (live-updating) or "Full · open to collect".
private struct FillLabel: View {
    let snap: WidgetSnapshot
    let date: Date

    var body: some View {
        if snap.isFull(at: date) {
            Text("Full · open to collect")
        } else {
            Text("Full in \(Text(snap.fullAt, style: .relative))")
        }
    }
}

private struct EmptyStateView: View {
    /// A save exists but nothing is producing yet.
    let hasSave: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("COSMICA", systemImage: "sparkles")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: 0)
            Text(hasSave ? "Buy a generator to start earning while you're away."
                         : "Open Cosmica to start tracking your stardust.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SpaceBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.03, blue: 0.12), Color(red: 0.17, green: 0.07, blue: 0.33)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Lock Screen

struct CosmicaLockView: View {
    let entry: CosmicaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let snap = entry.snapshot.flatMap { $0.baseRate > 0 ? $0 : nil }
        switch family {
        case .accessoryCircular:
            circular(snap)
        case .accessoryInline:
            inline(snap)
        default:
            rectangular(snap)
        }
    }

    @ViewBuilder
    private func rectangular(_ snap: WidgetSnapshot?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("Cosmica", systemImage: "sparkles")
                .font(.headline)
                .widgetAccentable()
            if let snap {
                Text("+\(Formatter.short(snap.waiting(at: entry.date))) ✦ waiting")
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                FillLabel(snap: snap, date: entry.date)
                    .font(.caption)
                    .lineLimit(1)
            } else {
                Text("Open to start tracking")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func circular(_ snap: WidgetSnapshot?) -> some View {
        if let snap {
            Gauge(value: snap.fillFraction(at: entry.date)) {
                Image(systemName: "sparkles")
            } currentValueLabel: {
                Text(Formatter.short(snap.waiting(at: entry.date)))
                    .minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "sparkles")
                    .font(.title2)
            }
        }
    }

    @ViewBuilder
    private func inline(_ snap: WidgetSnapshot?) -> some View {
        if let snap {
            let amount = Formatter.short(snap.waiting(at: entry.date))
            Label(snap.isFull(at: entry.date) ? "+\(amount) ✦ · full" : "+\(amount) ✦ waiting",
                  systemImage: "sparkles")
        } else {
            Label("Open Cosmica", systemImage: "sparkles")
        }
    }
}

// MARK: - Preview data

extension WidgetSnapshot {
    /// Widget gallery / placeholder data: 3h into an 8h window.
    static var preview: WidgetSnapshot {
        WidgetSnapshot(
            savedAt: Date().addingTimeInterval(-3 * 3600),
            baseRate: 4.2e13,
            adBoostMultiplier: 1,
            adBoostExpiresAt: nil,
            eventMultiplier: 1,
            eventExpiresAt: nil,
            offlineCap: OfflineAccrual.baseCap,
            cosmicShards: 1_250,
            prestigeCount: 14,
            cosmosCount: 1,
            tierTitle: "Cosmologist",
            tierSymbol: "globe.europe.africa.fill",
            lastDailyClaim: nil
        )
    }
}
