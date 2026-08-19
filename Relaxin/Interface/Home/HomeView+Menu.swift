import Foundation

extension HomeView {
    private static let ownGoalStudioPicksURL = URL(string: "https://owngoal.dev")!

    var menuItems: [OptionListItem<MenuAction>] {
        screen.menuEntries(
            configuration: configuration,
            interfaceMode: runtime.interfaceMode,
            canExportKernelcache: runtime.interfaceMode.allowsFileExport
                && kernelcacheExportURL != nil,
            resourceBundle: runtime.resourceBundle
        ).map { entry in
            OptionListItem(id: entry.action, title: entry.title)
        }
    }

    var preferredMenuAction: MenuAction? {
        screen.preferredMenuAction(configuration: configuration)
    }

    var menuShareItems: [MenuAction: URL] {
        switch screen {
        case .maintenance:
            guard runtime.interfaceMode.allowsFileExport else { return [:] }
            var items: [MenuAction: URL] = logExportState.archiveURL.map {
                [.exportLogs: $0]
            } ?? [:]
            if let kernelcacheExportURL {
                items[.exportKernelcache] = kernelcacheExportURL
            }
            return items
        case .credits:
            guard runtime.interfaceMode.allowsExternalNavigation else {
                return [:]
            }
            return softwareLicenseURL.map { [.showSoftwareLicense: $0] } ?? [:]
        case .home, .advancedOptions, .jetsamMultiplier, .confirmation,
             .engine:
            return [:]
        }
    }

    var loadingMenuActions: Set<MenuAction> {
        guard runtime.interfaceMode.allowsFileExport else { return [] }
        return screen == .maintenance && logExportState.isPreparing
            ? [.exportLogs]
            : []
    }

    func performMenuAction(_ action: MenuAction) {
        switch action {
        case .jailbreak:
            guard !configuration.removeJailbreakEnabled else {
                screen = .confirmation(.removeJailbreak)
                return
            }
            startEngine()
        case .advancedOptions:
            screen = .advancedOptions
        case .maintenance:
            guard runtime.interfaceMode.showsMaintenance else { return }
            if runtime.interfaceMode.allowsFileExport {
                prepareLogExport()
            }
            screen = .maintenance
        case .credits:
            screen = .credits
        case .openOwnGoalStudioPicks:
            guard runtime.interfaceMode.allowsExternalNavigation else { return }
            openURL(Self.ownGoalStudioPicksURL)
        case .showSoftwareLicense:
            guard runtime.interfaceMode.allowsExternalNavigation else { return }
            showSoftwareLicenseUnavailable()
        case let .toggleOption(option):
            option.toggle(in: &configuration)
        case .jetsamMultiplier:
            screen = .jetsamMultiplier
        case let .setJetsamMultiplier(multiplier):
            configuration.jetsamMultiplier = multiplier
            screen = .advancedOptions
        case .resetRelaxin:
            resetRelaxin()
        case .exportLogs:
            guard runtime.interfaceMode.allowsFileExport else { return }
            prepareLogExport()
        case .exportKernelcache:
            guard runtime.interfaceMode.allowsFileExport else { return }
            showKernelcacheUnavailable()
        case let .confirm(action):
            screen = .confirmation(action)
        case .removeJailbreak:
            startEngine()
        case .back:
            if let destination = screen.backDestination {
                screen = destination
            }
        }
    }
}
