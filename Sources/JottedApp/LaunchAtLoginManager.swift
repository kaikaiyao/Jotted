import Foundation
import ServiceManagement

/// A small seam around `SMAppService` so the preference/state logic can be
/// exercised without registering the real application as a login item.
@MainActor
protocol LaunchAtLoginServiceProviding: AnyObject {
    var status: SMAppService.Status { get }

    func register() throws
    func unregister() throws
}

@MainActor
private final class MainAppLaunchAtLoginService: LaunchAtLoginServiceProviding {
    private let service = SMAppService.mainApp

    var status: SMAppService.Status {
        service.status
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}

/// Owns the user's launch-at-login preference and reflects the corresponding
/// Service Management state.
///
/// Construction never registers or unregisters anything. The application must
/// explicitly call `synchronize()` at an appropriate point during a normal,
/// packaged app launch. Snapshot, smoke-test, XCTest, and `swift run` processes
/// are intentionally prevented from touching the real login-item registration.
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let preferenceKey = "JottedLaunchAtLoginEnabled"

    /// The user's desired setting. This defaults to `true` for new installs.
    @Published private(set) var enabled: Bool

    /// The actual registration/authorization state reported by macOS.
    @Published private(set) var status: SMAppService.Status = .notRegistered

    /// The latest actionable registration error, if any. A pending approval is
    /// represented separately by `needsApproval` so the UI can localize it.
    @Published private(set) var message: String?

    var needsApproval: Bool {
        status == .requiresApproval
    }

    private let defaults: UserDefaults
    private let service: any LaunchAtLoginServiceProviding
    private let permitsServiceChanges: Bool

    init(
        defaults: UserDefaults = .standard,
        service: (any LaunchAtLoginServiceProviding)? = nil,
        permitsServiceChanges: Bool? = nil
    ) {
        self.defaults = defaults
        self.service = service ?? MainAppLaunchAtLoginService()
        self.permitsServiceChanges = permitsServiceChanges
            ?? Self.isPackagedInteractiveLaunch

        defaults.register(defaults: [Self.preferenceKey: true])
        enabled = defaults.bool(forKey: Self.preferenceKey)

        if self.permitsServiceChanges {
            status = self.service.status
        }
    }

    /// Changes the saved preference. Pass `synchronize: false` when the caller
    /// wants to defer the system change until a later explicit synchronization.
    func setEnabled(_ newValue: Bool, synchronize shouldSynchronize: Bool = true) {
        guard enabled != newValue else {
            if shouldSynchronize {
                synchronize()
            }
            return
        }

        enabled = newValue
        defaults.set(newValue, forKey: Self.preferenceKey)

        if shouldSynchronize {
            synchronize()
        }
    }

    /// Reconciles the saved preference with the main app's login-item state.
    /// This method is deliberately a no-op outside a packaged interactive app.
    func synchronize() {
        guard permitsServiceChanges else { return }

        message = nil
        let currentStatus = service.status
        status = currentStatus

        do {
            if enabled {
                switch currentStatus {
                case .notRegistered, .notFound:
                    try service.register()
                case .enabled, .requiresApproval:
                    break
                @unknown default:
                    break
                }
            } else {
                switch currentStatus {
                case .enabled, .requiresApproval:
                    try service.unregister()
                case .notRegistered, .notFound:
                    break
                @unknown default:
                    break
                }
            }
        } catch {
            message = error.localizedDescription
        }

        status = service.status
    }

    /// Refreshes the system state without changing registration.
    func refresh() {
        guard permitsServiceChanges else { return }
        message = nil
        status = service.status
    }

    /// Opens macOS System Settings at General > Login Items.
    func openSystemLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static var isPackagedInteractiveLaunch: Bool {
        let processInfo = ProcessInfo.processInfo
        let arguments = processInfo.arguments

        let isSnapshotOrSmokeTest = arguments.contains { argument in
            argument == "--smoke-test" || argument.hasPrefix("--snapshot-")
        }
        let isRunningTests = processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
        let bundleIsApplication = Bundle.main.bundleURL.pathExtension.lowercased() == "app"
        let executableIsInsideApp = Bundle.main.executableURL?.path.contains("/Contents/MacOS/") == true

        return !isSnapshotOrSmokeTest
            && !isRunningTests
            && bundleIsApplication
            && executableIsInsideApp
    }
}
