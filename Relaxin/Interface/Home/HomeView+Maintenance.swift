import Foundation

extension HomeView {
    enum LogExportState: Equatable {
        case idle
        case preparing(UUID)
        case ready(URL)

        var archiveURL: URL? {
            guard case let .ready(url) = self else { return nil }
            return url
        }

        var isPreparing: Bool {
            guard case .preparing = self else { return false }
            return true
        }
    }

    var softwareLicenseURL: URL? {
        runtime.resourceBundle.url(forResource: "Licenses", withExtension: "txt")
    }

    var kernelcacheExportURL: URL? {
        let stagedKernelcacheURL = runtime.dataDirectory.appendingPathComponent(
            "kernelcache",
            isDirectory: false
        )
        return FileManager.default.isReadableFile(atPath: stagedKernelcacheURL.path)
            ? stagedKernelcacheURL
            : nil
    }

    func prepareLogExport() {
        guard runtime.interfaceMode.allowsFileExport,
              !logExportState.isPreparing
        else {
            return
        }

        let request = UUID()
        logExportState = .preparing(request)
        Task {
            do {
                let url = try await AppLog.makeExportArchive(
                    in: runtime.temporaryDirectory
                )
                guard logExportState == .preparing(request) else {
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                logExportState = .ready(url)
            } catch {
                guard logExportState == .preparing(request) else { return }
                logExportState = .idle
                AppLog.error(Self.self, "log export failed: \(error.localizedDescription)")
                alert = Presentation.Alert(
                    title: String(
                        localized: "Export Failed",
                        bundle: runtime.resourceBundle
                    ),
                    message: error.localizedDescription
                )
            }
        }
    }

    func showSoftwareLicenseUnavailable() {
        guard runtime.interfaceMode.allowsExternalNavigation else { return }
        let message = String(
            localized: "The software license file is missing.",
            bundle: runtime.resourceBundle
        )
        AppLog.error(Self.self, message)
        alert = Presentation.Alert(
            title: String(
                localized: "Software License Unavailable",
                bundle: runtime.resourceBundle
            ),
            message: message
        )
    }

    func showKernelcacheUnavailable() {
        guard runtime.interfaceMode.allowsFileExport else { return }
        let message = String(
            localized: "The kernelcache is not readable.",
            bundle: runtime.resourceBundle
        )
        AppLog.error(Self.self, message)
        alert = Presentation.Alert(
            title: String(
                localized: "Export Failed",
                bundle: runtime.resourceBundle
            ),
            message: message
        )
    }

    func resetRelaxin() {
        logExportState = .idle
        do {
            try RelaxinReset.perform(runtime: runtime)
            configuration = JailbreakConfiguration(defaults: runtime.defaults)
            engineSession.reset()
            screen = .home
            alert = Presentation.Alert(
                title: String(
                    localized: "Relaxin Reset",
                    bundle: runtime.resourceBundle
                ),
                message: String(
                    localized: "Relaxin settings and caches were cleared.",
                    bundle: runtime.resourceBundle
                )
            )
        } catch {
            AppLog.error(Self.self, "reset failed: \(error.localizedDescription)")
            alert = Presentation.Alert(
                title: String(
                    localized: "Reset Failed",
                    bundle: runtime.resourceBundle
                ),
                message: error.localizedDescription
            )
        }
    }
}
