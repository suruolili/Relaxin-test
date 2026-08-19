import Foundation

enum RelaxinTerminalContent {
    static func home(
        isJailbroken: Bool,
        resourceBundle: Bundle
    ) -> String {
        var lines = baseLines(
            isJailbroken: isJailbroken,
            resourceBundle: resourceBundle
        )
        lines.append("")
        lines.append(
            TerminalStyle.dim(
                String(
                    localized: "Tap options below to start...",
                    bundle: resourceBundle
                )
            ) + " "
        )
        lines.append("")
        return TerminalStyle.clearAndHome + TerminalStyle.hideCursor + lines.joined(separator: "\r\n")
    }

    static func running(
        output: [TerminalOutputLine],
        isJailbroken: Bool,
        terminalWidth: Int,
        resourceBundle: Bundle
    ) -> String {
        var lines = baseLines(
            isJailbroken: isJailbroken,
            resourceBundle: resourceBundle
        )
        lines.append("")
        lines.append(TerminalStyle.accent("❯") + " relaxin do")
        lines.append("")
        lines.append(contentsOf: output.flatMap {
            render($0, width: terminalWidth)
        })
        lines.append("")
        return TerminalStyle.clearAndHome + TerminalStyle.hideCursor + lines.joined(separator: "\r\n")
    }

    static func command(
        command: String,
        output: [TerminalOutputLine],
        isJailbroken: Bool,
        terminalWidth: Int,
        resourceBundle: Bundle
    ) -> String {
        var lines = baseLines(
            isJailbroken: isJailbroken,
            resourceBundle: resourceBundle
        )
        lines.append("")
        lines.append(TerminalStyle.accent(">") + " \(command)")
        if !output.isEmpty {
            lines.append("")
            lines.append(contentsOf: output.flatMap {
                render($0, width: terminalWidth)
            })
        }
        return TerminalStyle.clearAndHome
            + TerminalStyle.hideCursor
            + lines.joined(separator: "\r\n")
    }

    /// Credits omits the Relaxin banner and command header.
    static func credits(
        visibleCharacterCount: Int,
        linksEnabled: Bool
    ) -> String {
        let cursorVisibility = visibleCharacterCount < RelaxinCredits.characterCount
            ? TerminalStyle.showCursor
            : TerminalStyle.hideCursor
        return TerminalStyle.clearAndHome
            + cursorVisibility
            + RelaxinCredits.terminalLines(
                visibleCharacterCount: visibleCharacterCount,
                linksEnabled: linksEnabled
            ).joined(separator: "\r\n")
    }

    static func unavailable(resourceBundle: Bundle) -> String {
        var lines = baseLines(
            isJailbroken: false,
            resourceBundle: resourceBundle
        )
        lines.append("")
        lines.append(
            TerminalStyle.danger(
                String(
                    localized: "Relaxin Lite requires an active RootHide jailbreak.",
                    bundle: resourceBundle
                )
            )
        )
        lines.append("")
        return TerminalStyle.clearAndHome
            + TerminalStyle.hideCursor
            + lines.joined(separator: "\r\n")
    }
}
