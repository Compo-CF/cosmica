import StoreKit

/// Gate for developer-only tools (currently: Developer Restore in Settings).
///
/// Two locks, both required:
///   1. `buildFlag` — a compile-time switch. Turn ON only for a personal
///      TestFlight build that is NEVER submitted for review. It MUST be `false`
///      in any build attached to an App Store submission (App Review installs
///      run in the sandbox environment, so lock 2 alone would not hide it there).
///   2. The install environment — tools only appear for TestFlight / Xcode
///      installs (StoreKit `AppTransaction.environment != .production`). App
///      Store installs never see them, even if lock 1 were left on by mistake.
enum DevTools {
    /// Flip to `false` before archiving any build you will submit to App Review.
    static let buildFlag = false

    static func isAvailable() async -> Bool {
        guard buildFlag else { return false }
        #if DEBUG
        return true
        #else
        guard let result = try? await AppTransaction.shared else { return false }
        switch result {
        case .verified(let transaction), .unverified(let transaction, _):
            return transaction.environment != .production
        }
        #endif
    }
}
