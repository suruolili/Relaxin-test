import Combine
import Foundation
import RelaxinEngine
import UIKit

@MainActor
private final class EngineBackgroundTaskLease {
    private(set) var didExpire = false
    private var identifier = UIBackgroundTaskIdentifier.invalid

    static func acquire() -> EngineBackgroundTaskLease? {
        let lease = EngineBackgroundTaskLease()
        lease.identifier = UIApplication.shared.beginBackgroundTask(
            withName: "com.aapl.relaxin.engine",
            expirationHandler: { [weak lease] in
                lease?.expire()
            }
        )
        return lease.identifier == .invalid ? nil : lease
    }

    func end() {
        guard identifier != .invalid else { return }
        let identifier = identifier
        self.identifier = .invalid
        UIApplication.shared.endBackgroundTask(identifier)
    }

    private func expire() {
        didExpire = true
        AppLog.error(EngineSession.self, "engine background task expired")
        end()
    }
}

private enum EngineBackgroundTaskFailure: Int {
    case unavailable = 1
    case expired

    func error(in resourceBundle: Bundle) -> NSError {
        let failureReason: String
        let recoverySuggestion: String
        let diagnostic: String
        switch self {
        case .unavailable:
            failureReason = String(
                localized: "iOS did not grant the required background execution assertion.",
                bundle: resourceBundle
            )
            recoverySuggestion = String(
                localized: "Close Relaxin, reopen it, and try again.",
                bundle: resourceBundle
            )
            diagnostic = "stage=engine_start\nbackground_task=unavailable\nexploit_started=false"
        case .expired:
            failureReason = String(
                localized: "The background execution assertion expired before the engine returned.",
                bundle: resourceBundle
            )
            recoverySuggestion = String(
                localized: "Reboot the device before trying again.",
                bundle: resourceBundle
            )
            diagnostic = "stage=engine_run\nbackground_task=expired\nkernel_state_may_be_dirty=true"
        }
        return NSError(
            domain: "com.aapl.relaxin.background-task",
            code: rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: String(
                    localized: "The engine could not remain active in the background.",
                    bundle: resourceBundle
                ),
                NSLocalizedFailureReasonErrorKey: failureReason,
                NSLocalizedRecoverySuggestionErrorKey: recoverySuggestion,
                RLXEngineErrorUserInfoKey.diagnosticKey.rawValue: diagnostic,
            ]
        )
    }
}

@MainActor
final class EngineSession: ObservableObject {
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var output: [TerminalOutputLine] = []
    let runtime: RelaxinRuntime
    let postJailbreakSession: PostJailbreakSession
    private let engine: RLXEngine

    init(runtime: RelaxinRuntime) {
        self.runtime = runtime
        let engine = RLXEngine(
            runtimeEnvironment: runtime.environment,
            additionalBootstrapPackageResourceNames:
            runtime.additionalBootstrapPackageResourceNames
        )
        self.engine = engine
        postJailbreakSession = PostJailbreakSession(
            environment: runtime.postJailbreakEnvironment,
            controller: engine.postJailbreakController,
            reinstallSileo: { outputHandler in
                try await engine.perform(
                    action: .reinstallSileo,
                    arguments: nil,
                    output: outputHandler
                )
            }
        )
    }

    func reset() {
        guard case .idle = phase else { return }
        output.removeAll(keepingCapacity: true)
        postJailbreakSession.refreshAvailability()
    }

    func start(
        manifest: [RLXEngineManifestKey: String],
        after initialDelay: Duration = .zero,
        onSuccess: @escaping () -> Void = {}
    ) {
        guard case .idle = phase else { return }
        output.removeAll(keepingCapacity: true)
        phase = .running
        let wasIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        Task { [self] in
            defer {
                UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
            }
            try? await Task.sleep(for: initialDelay)
            guard let backgroundTask = EngineBackgroundTaskLease.acquire() else {
                recordFailure(
                    EngineBackgroundTaskFailure.unavailable.error(
                        in: runtime.resourceBundle
                    )
                )
                return
            }
            defer {
                backgroundTask.end()
            }
            do {
                AppLog.setEngineOutputHandler { [weak self] message in
                    Task { @MainActor [weak self] in
                        self?.recordEngineOutput(message)
                    }
                }
                defer {
                    AppLog.setEngineOutputHandler(nil)
                }
                try await engine.run(manifest: manifest) { update in
                    self.recordTaskUpdate(update)
                }
                guard !backgroundTask.didExpire else {
                    throw EngineBackgroundTaskFailure.expired.error(
                        in: runtime.resourceBundle
                    )
                }
                postJailbreakSession.refreshAvailability()
                phase = .finished
                onSuccess()
            } catch {
                recordFailure(error)
            }
        }
    }

    func recordTaskUpdate(_ update: RLXEngineTaskUpdate) {
        let taskIdentifier = Int(update.stage.rawValue)
        if let index = output.firstIndex(where: { $0.taskIdentifier == taskIdentifier }) {
            output[index] = .task(update, details: output[index].details)
        } else {
            output.append(.task(update))
        }
    }

    func recordEngineOutput(_ message: String) {
        guard case .running = phase,
              let index = output.lastIndex(where: { $0.status == .running })
        else {
            return
        }

        let line = output[index]
        if let position = line.position,
           let count = line.count,
           message == "[\(position)/\(count)] \(line.label)"
        {
            return
        }
        output[index] = line.appendingDetails(from: message)
    }

    func recordFailure(_ error: Error) {
        let error = error as NSError
        let failure = Failure(report: makeFailureReport(for: error))
        phase = .failed(failure)
        AppLog.error(Self.self, failure.report)
    }
}
