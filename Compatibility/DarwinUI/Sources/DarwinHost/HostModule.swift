import DynamicRuntime
import RuntimeABI

/// A module of contract implementations, such as `DarwinBluetooth`.
///
/// The host registers a module only when the app uses one of its contracts
/// (`RTContracts`), so the guest can't resolve contracts it didn't declare
/// (`HostRuntime.md` §4, §9).
public protocol HostModule {

    /// The contracts and callback interfaces this module registers.
    static var contracts: [ContractDescriptor] { get }

    /// Registers the implementations and callback interfaces.
    static func register(in registrar: some ContractRegistrar)

    /// What answers `Permissions` for the capabilities this module's
    /// frameworks gate. Made once, when the host starts.
    static func permissionProviders() -> [Capability: any PermissionProvider]
}

public extension HostModule {

    static func permissionProviders() -> [Capability: any PermissionProvider] {
        [:]
    }

    /// Whether the app uses any of this module's contracts.
    static func isUsed(by contracts: Set<String>) -> Bool {
        Self.contracts.contains { contracts.contains($0.name) }
    }
}

/// One capability's authorization, over its framework's API
/// (`CBManager.authorization`, `CLLocationManager`, …).
///
/// Called on the main thread. `status` never prompts.
public protocol PermissionProvider: AnyObject {

    func status() -> PermissionStatus

    /// Asks the user if they haven't decided, and calls `completion` once, on
    /// the main thread, with the result. When there's nothing to ask, calls
    /// it at once.
    func request(_ completion: @escaping (PermissionStatus) -> Void)
}

/// A capability every device has, such as `network`.
public final class GrantedPermission: PermissionProvider {

    public init() { }

    public func status() -> PermissionStatus {
        .granted
    }

    public func request(_ completion: @escaping (PermissionStatus) -> Void) {
        completion(.granted)
    }
}

/// A capability this device or platform lacks, such as NFC on macOS.
public final class UnavailablePermission: PermissionProvider {

    public init() { }

    public func status() -> PermissionStatus {
        .unavailable
    }

    public func request(_ completion: @escaping (PermissionStatus) -> Void) {
        completion(.unavailable)
    }
}
