import SwiftUI

/// v4.0 — the moment a run first passes 1.8e308, the number that used to be the
/// end of the game. Fires once (the engine sets `showOmniverseDoor` when
/// `omniverseDoorOpen` flips) and points the player at the Omniverse.
struct OmniverseDoorView: View {
    @Environment(GameEngine.self) var engine
    @Environment(HapticsManager.self) var haptics
    @Environment(\.dismiss) var dismiss

    @State private var shown = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 0.25, green: 0.18, blue: 0.04), .black],
                           center: .center, startRadius: 10, endRadius: 520)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "circle.hexagonpath.fill")
                    .font(.system(size: 96, weight: .ultraLight))
                    .foregroundStyle(LinearGradient(colors: [OmniverseView.gold, OmniverseView.teal],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                    .rotationEffect(.degrees(shown ? 0 : -90))
                    .scaleEffect(shown ? 1 : 0.4)
                Text("BEYOND THE CEILING")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .kerning(3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("1.8e308 was where the numbers used to stop. Yours just kept going.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                Text("The Omniverse is open. Collapse it to turn the Multiverse into Echoes: each one multiplies everything you earn, and they thin the veil that slows growth out here.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                Spacer()
                Button {
                    haptics.purchase()
                    dismiss()
                } label: {
                    Text("Into the Omniverse")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(LinearGradient(colors: [OmniverseView.gold, OmniverseView.teal],
                                                   startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            haptics.bigBang()
            withAnimation(.spring(response: 1.1, dampingFraction: 0.7)) { shown = true }
        }
        .onDisappear { engine.acknowledgeOmniverseDoor() }
    }
}
