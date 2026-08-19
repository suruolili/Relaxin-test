import Foundation
import RelaxinEngine

/// Immutable device identity and compatibility profile confirmed before an engine run.
struct JailbreakTarget {
    /// Manifest contract only; Rocket derives PPL/SPTM from the exact kernelcache.
    enum RuntimeProfile: String {
        case pplDMAA12 = "ppl-dma-a12"
        case pplGFXA13 = "ppl-gfx-a13"
        case pplGFXA14M1 = "ppl-gfx-a14-m1"
        case gfxA15M2 = "gfx-a15-m2"
        case gfxA16 = "gfx-a16"
        case sptmGFXA17 = "sptm-gfx-a17"

        init?(cpuFamily: UInt32) {
            switch cpuFamily {
            case 0x07D3_4B9F:
                self = .pplDMAA12
            case 0x4625_04D2:
                self = .pplGFXA13
            case 0x1B58_8BB3:
                self = .pplGFXA14M1
            case 0xDA33_D83D:
                self = .gfxA15M2
            case 0x8765_EDEA:
                self = .gfxA16
            case 0x2876_F5B5:
                self = .sptmGFXA17
            default:
                return nil
            }
        }

        var soc: String {
            switch self {
            case .pplDMAA12:
                "A12"
            case .pplGFXA13:
                "A13"
            case .pplGFXA14M1:
                "A14/M1"
            case .gfxA15M2:
                "A15/M2"
            case .gfxA16:
                "A16"
            case .sptmGFXA17:
                "A17"
            }
        }
    }

    enum ConfirmationError: Error {
        case simulator
        case missingDeviceIdentifier
        case missingBuild
        case missingCPUFamily
        case unsupportedOS(String)
        case unsupportedSoC(UInt32)

        func localizedDescription(in resourceBundle: Bundle) -> String {
            switch self {
            case .simulator:
                String(
                    localized: "The jailbreak target must be a physical iPhone or iPad.",
                    bundle: resourceBundle
                )
            case .missingDeviceIdentifier:
                String(
                    localized: "The exact device identifier could not be read.",
                    bundle: resourceBundle
                )
            case .missingBuild:
                String(
                    localized: "The exact iOS build number could not be read.",
                    bundle: resourceBundle
                )
            case .missingCPUFamily:
                String(
                    localized: "The device CPU family could not be read.",
                    bundle: resourceBundle
                )
            case let .unsupportedOS(version):
                String(
                    format: String(
                        localized: "iOS %@ does not have a supported runtime profile.",
                        bundle: resourceBundle
                    ),
                    version
                )
            case let .unsupportedSoC(cpuFamily):
                String(
                    format: String(
                        localized: "CPU family %@ does not have a supported runtime profile.",
                        bundle: resourceBundle
                    ),
                    Self.hex(cpuFamily)
                )
            }
        }

        private static func hex(_ value: UInt32) -> String {
            String(format: "0x%08X", value)
        }
    }

    static let current = JailbreakTarget(
        deviceIdentifier: DeviceInfo.modelIdentifier,
        cpuFamily: DeviceInfo.cpuFamily,
        osVersion: DeviceInfo.osVersion,
        osBuild: DeviceInfo.osBuild,
        isSimulator: {
            #if targetEnvironment(simulator)
                true
            #else
                false
            #endif
        }()
    )

    let deviceIdentifier: String
    let cpuFamily: UInt32?
    let osVersion: String
    let osBuild: String?
    let isSimulator: Bool

    var runtimeProfile: RuntimeProfile? {
        cpuFamily.flatMap(RuntimeProfile.init(cpuFamily:))
    }

    var socDescription: String {
        guard let cpuFamily else { return "unavailable" }
        let family = Self.hex(cpuFamily)
        guard let runtimeProfile else { return family }
        return "\(runtimeProfile.soc) (\(family))"
    }

    var buildDescription: String {
        osBuild ?? "unavailable"
    }

    var profileDescription: String {
        runtimeProfile?.rawValue ?? "unavailable"
    }

    var logDescription: String {
        "device=\(deviceIdentifier) soc=\(socDescription) ios=\(osVersion) build=\(buildDescription) profile=\(profileDescription)"
    }

    func confirmedManifest() throws -> [RLXEngineManifestKey: String] {
        if isSimulator {
            throw ConfirmationError.simulator
        }
        guard !deviceIdentifier.isEmpty else {
            throw ConfirmationError.missingDeviceIdentifier
        }
        guard Self.isSupportedOSVersion(osVersion) else {
            throw ConfirmationError.unsupportedOS(osVersion)
        }
        guard let cpuFamily else {
            throw ConfirmationError.missingCPUFamily
        }
        guard let runtimeProfile else {
            throw ConfirmationError.unsupportedSoC(cpuFamily)
        }
        guard let osBuild, !osBuild.isEmpty else {
            throw ConfirmationError.missingBuild
        }

        return [
            .targetDeviceIdentifierKey: deviceIdentifier,
            .targetSoCKey: runtimeProfile.soc,
            .targetCPUFamilyKey: Self.hex(cpuFamily),
            .targetOSVersionKey: osVersion,
            .targetOSBuildKey: osBuild,
            .runtimeProfileKey: runtimeProfile.rawValue,
        ]
    }

    private static func isSupportedOSVersion(_ version: String) -> Bool {
        let components = version.split(separator: ".", omittingEmptySubsequences: false)
        guard (2 ... 3).contains(components.count),
              let major = Int(components[0]),
              let minor = Int(components[1])
        else {
            return false
        }
        let patch = components.count == 3 ? Int(components[2]) : 0
        guard let patch else { return false }
        guard major == 16 || major == 17 else { return false }
        if major == 16 {
            return minor > 5 || (minor == 5 && patch >= 1)
        }
        return minor < 3 || (minor == 3 && patch <= 1)
    }

    private static func hex(_ value: UInt32) -> String {
        String(format: "0x%08X", value)
    }
}
