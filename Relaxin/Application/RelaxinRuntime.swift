import Foundation
import RelaxinEngine

struct RelaxinRuntime {
    let interfaceMode: RelaxinInterfaceMode
    let environment: RLXRuntimeEnvironment
    let defaultsSuiteName: String?
    let additionalBootstrapPackageResourceNames: [String]

    static let native = RelaxinRuntime(
        interfaceMode: .full,
        environment: .default,
        defaultsSuiteName: nil,
        additionalBootstrapPackageResourceNames: []
    )

    var resourceBundle: Bundle {
        environment.resourceBundle
    }

    var dataDirectory: URL {
        environment.dataDirectoryURL
    }

    var cacheDirectory: URL {
        environment.cacheDirectoryURL
    }

    var temporaryDirectory: URL {
        environment.temporaryDirectoryURL
    }

    var defaults: UserDefaults {
        guard let defaultsSuiteName else { return .standard }
        return UserDefaults(suiteName: defaultsSuiteName)!
    }

    var persistentDomainIdentifier: String? {
        defaultsSuiteName ?? resourceBundle.bundleIdentifier
    }

    var postJailbreakEnvironment: PostJailbreakEnvironment {
        PostJailbreakEnvironment(
            interfaceMode: interfaceMode,
            resourceBundle: resourceBundle,
            defaults: defaults
        )
    }
}
