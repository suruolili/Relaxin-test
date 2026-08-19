import Foundation

extension HomeView {
    enum Presentation {
        struct Alert: Identifiable {
            enum Kind {
                case notice
                case jailbreakRemovalComplete
            }

            let title: String
            let message: String
            var kind = Kind.notice

            var id: String {
                "\(kind)\0\(title)\0\(message)"
            }

            static func jailbreakRemovalComplete(in resourceBundle: Bundle) -> Alert {
                Alert(
                    title: String(
                        localized: "Jailbreak Removal Complete",
                        bundle: resourceBundle
                    ),
                    message: String(
                        localized: "Jailbreak removal is complete. Tap OK to close Relaxin.",
                        bundle: resourceBundle
                    ),
                    kind: .jailbreakRemovalComplete
                )
            }
        }
    }
}
