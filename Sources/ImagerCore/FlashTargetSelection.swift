import Foundation

public struct FlashTargetSelection: Equatable {
    public private(set) var devices: [SDCard] = []
    private var revision = UUID()
    private var selection: String?

    public var selectedID: String? {
        get { selection }
        set {
            let valid = devices.contains { $0.id == newValue } ? newValue : nil
            if valid != selection { revision = UUID() }
            selection = valid
        }
    }

    public init() {}

    public mutating func replaceDevices(_ observed: [SDCard]) {
        guard observed != devices else { return }
        devices = observed
        selection = nil
        revision = UUID()
    }

    public func confirmed(using confirm: (SDCard) -> Bool) -> SDCard? {
        guard let target = devices.first(where: { $0.id == selection }), confirm(target) else { return nil }
        return target
    }
}
