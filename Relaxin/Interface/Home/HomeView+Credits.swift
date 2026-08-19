import Foundation

enum RelaxinCredits {
    private struct Entry {
        let name: String
        let destination: URL?
        let role: String

        private func roleText(startingAt column: Int) -> String {
            guard !role.isEmpty else { return "" }
            let spacing = max(0, column - name.count)
            return String(repeating: " ", count: spacing) + "(\(role))"
        }

        func characterCount(roleColumn: Int) -> Int {
            name.count + roleText(startingAt: roleColumn).count
        }

        init(
            _ name: String,
            destination: URL? = nil,
            secondary: String = ""
        ) {
            self.name = name
            self.destination = destination
            role = secondary
        }

        /// Applies terminal styling after truncation so SwiftTerm always receives complete ANSI sequences.
        func terminalLine(
            visibleCharacterCount: Int,
            roleColumn: Int,
            linksEnabled: Bool
        ) -> String {
            let roleText = roleText(startingAt: roleColumn)
            let visibleName = String(name.prefix(visibleCharacterCount))
            let visibleRoleCount = max(0, visibleCharacterCount - name.count)
            let visibleRole = String(roleText.prefix(visibleRoleCount))
            var line = TerminalStyle.accent(visibleName)
            if linksEnabled, let destination {
                line = TerminalStyle.hyperlink(
                    line,
                    destination: destination
                )
            }
            guard !visibleRole.isEmpty else { return line }
            return line + TerminalStyle.dim(visibleRole)
        }
    }

    private static let title = "An OwnGoal Studio Project with AI"
    private static let minimumRoleSpacing = 2

    private static let entries = [
        Entry(""),
        Entry(
            "@Lakr233",
            destination: URL(string: "https://x.com/Lakr233")!,
            secondary: "SPTM, GPU Magic, UI"
        ),
        Entry(
            "@0x88FFA357",
            destination: URL(string: "https://x.com/0x88FFA357")!,
            secondary: "SPTM/PPL, CI"
        ),
        Entry(
            "@82Flex",
            destination: URL(string: "https://x.com/82Flex")!,
            secondary: "RootHide, PPL/TXM"
        ),
        Entry(
            "@roothideDev",
            destination: URL(string: "https://x.com/roothideDev")!,
            secondary: "RootHide, TXM"
        ),
        Entry(
            "@pattern_F_",
            destination: URL(string: "https://x.com/pattern_F_")!,
            secondary: "Exploits"
        ),
        Entry(""),
        Entry(
            "GPT‑5.6",
            destination: URL(string: "https://openai.com/index/previewing-gpt-5-6-sol/")!
        ),
        Entry(
            "Kimi-K3",
            destination: URL(string: "https://www.kimi.com/blog/kimi-k3")!
        ),
        Entry(""),
        Entry(
            "@opa334dev",
            destination: URL(string: "https://x.com/opa334dev")!,
            secondary: "Dopamine"
        ),
        Entry(
            "@Fayezheng_",
            destination: URL(string: "https://x.com/Fayezheng_")!
        ),
        Entry(
            "@AkiNazuki",
            destination: URL(string: "https://x.com/AkiNazuki")!
        ),
        Entry(
            "@EEEEYHN",
            destination: URL(string: "https://x.com/EEEEYHN")!
        ),
        Entry(
            "@huamidev",
            destination: URL(string: "https://x.com/huami_1214")!
        ),
    ]

    private static let roleColumn =
        (entries.map(\.name.count).max() ?? 0) + minimumRoleSpacing

    static let characterCount = title.count + entries.reduce(0) { count, entry in
        count + entry.characterCount(roleColumn: roleColumn)
    }

    static func accessibleLinks(linksEnabled: Bool) -> [TerminalPresenter.AccessibleLink] {
        guard linksEnabled else { return [] }
        return entries.compactMap { entry in
            entry.destination.map {
                TerminalPresenter.AccessibleLink(
                    label: entry.name,
                    destination: $0
                )
            }
        }
    }

    static func terminalLines(
        visibleCharacterCount: Int,
        linksEnabled: Bool
    ) -> [String] {
        var remainingCharacterCount = min(
            max(0, visibleCharacterCount),
            characterCount
        )
        guard remainingCharacterCount > 0 else { return [] }

        let visibleTitleCharacterCount = min(
            remainingCharacterCount,
            title.count
        )
        let visibleTitle = String(title.prefix(visibleTitleCharacterCount))
        var lines = [TerminalStyle.bold(visibleTitle)]
        remainingCharacterCount -= visibleTitleCharacterCount

        for entry in entries {
            let characterCount = entry.characterCount(roleColumn: roleColumn)
            if characterCount == 0 {
                guard remainingCharacterCount > 0 else { break }
                lines.append("")
                continue
            }

            guard remainingCharacterCount > 0 else { break }
            let entryCharacterCount = min(
                remainingCharacterCount,
                characterCount
            )
            lines.append(
                entry.terminalLine(
                    visibleCharacterCount: entryCharacterCount,
                    roleColumn: roleColumn,
                    linksEnabled: linksEnabled
                )
            )
            remainingCharacterCount -= entryCharacterCount
        }

        return lines
    }
}
