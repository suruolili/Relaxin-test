import RelaxinEngine
import SwiftUI
import UIKit

extension HomeView {
    func startEngine() {
        guard screen != .engine, case .idle = engineSession.phase else { return }

        var manifest: [RLXEngineManifestKey: String]
        do {
            manifest = try configuration.manifest(for: .current)
            manifest[.bootLogoDarkAppearanceKey] =
                bootLogoUsesDarkAppearance ? "true" : "false"
        } catch {
            let message = if let confirmationError = error as? JailbreakTarget.ConfirmationError {
                confirmationError.localizedDescription(in: runtime.resourceBundle)
            } else {
                error.localizedDescription
            }
            AppLog.error(Self.self, "target confirmation failed: \(message)")
            alert = Presentation.Alert(
                title: String(
                    localized: "Unsupported Target",
                    bundle: runtime.resourceBundle
                ),
                message: message
            )
            return
        }
        let removesJailbreak = configuration.removeJailbreakEnabled
        configuration.consumeRemoveJailbreakRequest()

        let runEngine = {
            engineSession.start(manifest: manifest) {
                guard removesJailbreak else { return }
                alert = .jailbreakRemovalComplete(in: runtime.resourceBundle)
            }
        }

        AppLog.info(Self.self, "target confirmed \(JailbreakTarget.current.logDescription)")
        if #available(iOS 17.0, *) {
            withAnimation(.spring(duration: 0.5, bounce: 0, blendDuration: 0.25)) {
                screen = .engine
            } completion: {
                runEngine()
            }
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 1, blendDuration: 0.25)) {
                screen = .engine
            }
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                runEngine()
            }
        }
    }

    func suspendApplication() {
        UIApplication.shared.perform(NSSelectorFromString("suspend"))
    }
}
