import SwiftData
import SwiftUI

@main
struct CaseLogApp: App {
    @State private var lock = AppLock()
    private let container: ModelContainer?
    private let storeError: String?

    init() {
        do {
            container = try SecureStore.makeContainer()
            storeError = nil
        } catch {
            container = nil
            storeError = error.localizedDescription
        }
        // A PDF left behind by a crash mid-share is removed on the next launch.
        ExportFiles.removeAll()
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .environment(lock)
                    .modelContainer(container)
            } else {
                ContentUnavailableView(
                    "Case log could not open",
                    systemImage: "exclamationmark.lock",
                    description: Text(storeError ?? "Unknown error")
                )
            }
        }
    }
}

struct RootView: View {
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @State private var passcodeSet = DeviceSecurity.isPasscodeSet

    var body: some View {
        ZStack {
            if !passcodeSet {
                ContentUnavailableView(
                    "Set a passcode to use Case Log",
                    systemImage: "lock.slash",
                    description: Text("Patient data is only encrypted when this iPhone has a passcode. Turn one on in Settings > Face ID & Passcode.")
                )
            } else if lock.isLocked {
                LockView()
            } else {
                CaseListView()
            }

            // Hides PHI in the app switcher and behind system prompts.
            if scenePhase != .active {
                PrivacyCover()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                lock.didEnterBackground()
                // Unsaved edits are written before the phone locks and the store becomes unreadable.
                if context.hasChanges {
                    AuditLog.record(.edit, detail: "Saved when the app went to the background", in: context)
                }
            case .active:
                passcodeSet = DeviceSecurity.isPasscodeSet
                lock.didBecomeActive()
            default:
                break
            }
        }
        .onAppear {
            // Save explicitly, so each save can be paired with an audit entry.
            context.autosaveEnabled = false
            Maintenance.purgeExpiredCases(in: context)
        }
    }
}

struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
        }
    }
}

struct LockView: View {
    @Environment(AppLock.self) private var lock
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAuthenticating = false
    @State private var didAutoPrompt = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Case Log is locked")
                .font(.title3.weight(.semibold))
            if let error = lock.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Unlock") { authenticate() }
                .buttonStyle(.borderedProminent)
                .disabled(isAuthenticating)
        }
        .padding()
        .onAppear { autoPrompt() }
        .onChange(of: scenePhase) { _, _ in autoPrompt() }
    }

    /// Shows Face ID once per lock. Cancelling it leaves the Unlock button,
    /// rather than prompting again in a loop.
    private func autoPrompt() {
        guard scenePhase == .active, !didAutoPrompt else { return }
        didAutoPrompt = true
        authenticate()
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task { @MainActor in
            let success = await lock.unlock()
            AuditLog.record(success ? .unlock : .unlockFailed, in: context)
            isAuthenticating = false
        }
    }
}
