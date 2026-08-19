import Foundation
import RelaxinEngine

/// App-owned jailbreak options passed into `RLXEngine` as a manifest snapshot.
struct JailbreakConfiguration {
    private enum StorageKey {
        static let tweakInjectionEnabled = "tweakInjectionEnabled"
        static let appJITEnabled = "appJITEnabled"
        static let jetsamMultiplier = "jetsamMultiplier"
        static let removeJailbreakEnabled = "removeJailbreakEnabled"
        static let bootLogoEnabled = "bootLogoEnabled"
    }

    private let defaults: UserDefaults

    var tweakInjectionEnabled: Bool {
        didSet {
            defaults.set(
                tweakInjectionEnabled,
                forKey: StorageKey.tweakInjectionEnabled
            )
        }
    }

    var appJITEnabled: Bool {
        didSet {
            defaults.set(
                appJITEnabled,
                forKey: StorageKey.appJITEnabled
            )
        }
    }

    var jetsamMultiplier: JetsamMultiplier {
        didSet {
            defaults.set(
                jetsamMultiplier.rawValue,
                forKey: StorageKey.jetsamMultiplier
            )
        }
    }

    var bootLogoEnabled: Bool {
        didSet {
            defaults.set(
                bootLogoEnabled,
                forKey: StorageKey.bootLogoEnabled
            )
        }
    }

    var removeJailbreakEnabled: Bool {
        didSet {
            defaults.set(
                removeJailbreakEnabled,
                forKey: StorageKey.removeJailbreakEnabled
            )
        }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            StorageKey.tweakInjectionEnabled: true,
            StorageKey.appJITEnabled: true,
            StorageKey.jetsamMultiplier: JetsamMultiplier.three.rawValue,
            StorageKey.removeJailbreakEnabled: false,
            StorageKey.bootLogoEnabled: true,
        ])
        tweakInjectionEnabled = defaults.bool(
            forKey: StorageKey.tweakInjectionEnabled
        )
        appJITEnabled = defaults.bool(forKey: StorageKey.appJITEnabled)
        jetsamMultiplier = defaults
            .string(forKey: StorageKey.jetsamMultiplier)
            .flatMap(JetsamMultiplier.init(rawValue:))
            ?? .three
        removeJailbreakEnabled = defaults.bool(
            forKey: StorageKey.removeJailbreakEnabled
        )
        bootLogoEnabled = defaults.bool(
            forKey: StorageKey.bootLogoEnabled
        )
    }

    func manifest(for target: JailbreakTarget) throws -> [RLXEngineManifestKey: String] {
        var manifest = try target.confirmedManifest()
        manifest[.tweakInjectionEnabledKey] = tweakInjectionEnabled ? "true" : "false"
        manifest[.appJITEnabledKey] = appJITEnabled ? "true" : "false"
        manifest[.jetsamMultiplierKey] = jetsamMultiplier.rawValue
        manifest[.removeJailbreakEnabledKey] = removeJailbreakEnabled ? "true" : "false"
        manifest[.bootLogoEnabledKey] = bootLogoEnabled ? "true" : "false"
        return manifest
    }

    mutating func consumeRemoveJailbreakRequest() {
        guard removeJailbreakEnabled else { return }
        removeJailbreakEnabled = false
    }
}
