import SwiftUI
import StoreKit

/// v1.2: the occasional, opt-out-able tip reminder. Deliberately gentle —
/// shown at most once every 60 days (and never in the first 2 weeks, never
/// after a tip). Offers the three tips inline, a "Maybe later" (asks again
/// after the interval), and a "Don't ask again" that silences it forever.
/// Gating lives in `IAPManager.tipReminderEligible`; this view is just the
/// presentation. Ported from S-Tier Eats' TipReminderView.
struct TipReminderView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(HapticsManager.self) private var haptics
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Spacer(minLength: 8)
                Image(systemName: "sparkles")
                    .resizable().scaledToFit()
                    .frame(width: 78, height: 78)
                    .foregroundStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .top, endPoint: .bottom))
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 12) {
                    Text("Enjoying Cosmica?")
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("It's free and built by one person. If it's earned a spot in your day, a small tip keeps it going — no pressure, and I won't ask often.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                HStack(spacing: 10) {
                    ForEach(Array(iap.tipProducts.enumerated()), id: \.element.id) { idx, product in
                        Button {
                            Task {
                                let ok = await iap.purchaseTip(product)
                                if ok { haptics.upgrade() }
                                dismiss()
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text(["Small", "Medium", "Generous"][min(idx, 2)])
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(product.displayPrice)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(iap.purchaseInFlight)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 4) {
                    Button("Maybe later") { dismiss() }
                        .font(.headline)
                        .padding(.vertical, 6)
                    Button("Don't ask again") {
                        iap.stopTipReminders()
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.large])
    }
}
