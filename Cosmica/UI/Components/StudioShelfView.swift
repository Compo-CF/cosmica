import SwiftUI

/// v3.5 — Horizontal "More from After Hours Dev Studio" shelf.
///
/// Reads from the injected `StudioShelfProvider` and renders one card per game.
/// Taps present `AppStoreProductSheet` so the user stays in Cosmica. Impressions
/// and taps are counted by `ShopStats` with per-game event keys, so each card's
/// conversion can be read from the same CloudKit pipeline as the Shop items.
///
/// Flexibility notes:
/// - No game list is hard-coded here. All content comes from the provider.
/// - Icon art loads over HTTPS via `AsyncImage`, so adding a new game is one
///   PNG push + one JSON commit — no app rebuild.
struct StudioShelfView: View {
    @Environment(StudioShelfProvider.self) private var provider

    @State private var selectedGame: StudioGame?

    private var stats: ShopStats { ShopStats.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if provider.games.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(provider.games) { game in
                            card(game)
                                .onAppear { stats.record("studio.impression.\(game.id)") }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .onAppear {
            stats.record("studio.shelf.open")
            Task { await provider.refresh() }
        }
        .sheet(item: $selectedGame) { game in
            AppStoreProductSheet(appStoreID: game.appStoreID)
                .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("More from After Hours Dev Studio")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    // MARK: - Card

    @ViewBuilder
    private func card(_ game: StudioGame) -> some View {
        Button {
            stats.record("studio.tap.\(game.id)")
            selectedGame = game
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                icon(game)
                Text(game.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(game.tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(12)
            .frame(width: 180, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func icon(_ game: StudioGame) -> some View {
        AsyncImage(url: game.iconURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholderIcon
            case .empty:
                placeholderIcon
                    .overlay(ProgressView().controlSize(.small))
            @unknown default:
                placeholderIcon
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.white.opacity(0.08))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
            Text("New games coming soon.")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, minHeight: 72)
    }
}
