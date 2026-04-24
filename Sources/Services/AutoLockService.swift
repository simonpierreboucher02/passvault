import AppKit
import Foundation
import CoreGraphics

@MainActor
@Observable
final class AutoLockService {
    static let shared = AutoLockService()

    var lockTimeout: TimeInterval = 300
    private var idleTimer: Timer?
    var onLock: (() -> Void)?

    func start() {
        setupObservers()
        startIdleTimer()
    }

    func stop() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    func resetIdleTimer() {
        startIdleTimer()
    }

    private func setupObservers() {
        let distributedCenter = DistributedNotificationCenter.default()
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        distributedCenter.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.triggerLock() }
        }

        workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.triggerLock() }
        }

        distributedCenter.addObserver(
            forName: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.triggerLock() }
        }

        workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.triggerLock() }
        }
    }

    private func startIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let idleTime = CGEventSource.secondsSinceLastEventType(
                    .combinedSessionState,
                    eventType: CGEventType(rawValue: ~0)!
                )
                if idleTime >= self.lockTimeout {
                    self.triggerLock()
                }
            }
        }
    }

    private func triggerLock() {
        idleTimer?.invalidate()
        idleTimer = nil
        onLock?()
    }
}
