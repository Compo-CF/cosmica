import Foundation
import WidgetKit

/// v3.0.3 — publishes the current save to the widget. Called whenever the app
/// stops being on screen (the moment offline accrual starts) and whenever a
/// background iCloud sync swaps in a different save.
enum WidgetSnapshotWriter {
    static func publish(_ state: GameState) {
        let snapshot = WidgetSnapshot(state: state)
        guard snapshot != WidgetSnapshot.load() else { return }   // nothing changed
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WidgetSnapshot {
    /// Built from the same inputs `GameEngine.applyOffline` uses, evaluated now.
    init(state: GameState) {
        let adMult = state.adBoostMultiplier
        let eventMult = state.eventStardustMultiplier
        let transient = adMult * eventMult
        let rate = state.stardustPerSecond
        self.init(
            savedAt: state.lastSeen,
            baseRate: transient > 0 ? rate / transient : rate,
            adBoostMultiplier: adMult,
            adBoostExpiresAt: adMult > 1 ? state.adBoostExpiresAt : nil,
            eventMultiplier: eventMult,
            eventExpiresAt: state.activeEvent != nil ? state.activeEventExpiresAt : nil,
            offlineCap: OfflineAccrual.baseCap
                + CosmicTree.offlineCapBonus(state.cosmicSkillLevels)
                + state.wonderOfflineCapBonus,
            cosmicShards: state.cosmicShards,
            prestigeCount: state.prestigeCount,
            cosmosCount: state.cosmosCount,
            tierTitle: state.currentTier.title,
            tierSymbol: state.currentTier.symbol,
            lastDailyClaim: state.lastDailyClaim
        )
    }
}
