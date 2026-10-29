import AppKit
import AVFoundation
import EventKit
import Speech
import SwiftUI
import UserNotifications

struct ModuleSettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var nowPlayingManager = NowPlayingManager.shared
    @ObservedObject private var shelf = ShelfStore.shared
    @ObservedObject private var teleprompter = TeleprompterManager.shared
    @State private var teleprompterPermissionRefresh = 0
    @State private var didAutoRequestTeleprompterPermissions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            SettingSectionLabel(title: "Downloader & Productivity")
            SettingGroup {
                SettingToggleRow(title: "4K Studio Downloader", isOn: $appState.downloadsEnabled)
                SettingRowDivider()
                SettingToggleRow(title: "Smart Clipboard & Link Monitor", isOn: $appState.clipboardEnabled)
            }

            SettingSectionLabel(title: "Media & HUD")
            SettingGroup {
                SettingToggleRow(title: "Now Playing", isOn: $appState.nowPlayingEnabled)
                if appState.nowPlayingEnabled {
                    SettingRowDivider()
                    SettingToggleRow(
                        title: "Browser media detection",
                        description: "Use macOS automation to detect media in allowed browsers.",
                        isOn: $nowPlayingManager.browserDetectionEnabled
                    )
                    if nowPlayingManager.browserDetectionEnabled {
                        browserMediaRows
                    }
                }
                SettingRowDivider()
                SettingToggleRow(title: "Volume HUD", isOn: $appState.volumeHUDEnabled)
            }

            SettingSectionLabel(title: "Home")
            SettingGroup {
                homeSlotRow(title: "Left slot", selection: $appState.homeLeadingPanelRaw)
                SettingRowDivider()
                homeSlotRow(title: "Center slot", selection: $appState.homeCenterPanelRaw)
                SettingRowDivider()
                homeSlotRow(title: "Right slot", selection: $appState.homeTrailingPanelRaw)
            }

            SettingSectionLabel(title: "System")
            SettingGroup {
                SettingToggleRow(title: "Battery", isOn: $appState.batteryEnabled)
                SettingRowDivider()
                SettingToggleRow(title: "Shelf", isOn: $appState.shelfEnabled)
                SettingRowDivider()
                SettingToggleRow(title: "Auto-open Shelf on Drop", isOn: $appState.shelfAutoOpenOnDrop)
                SettingRowDivider()
                shelfRetentionRow
                SettingRowDivider()
                SettingToggleRow(title: "Connectivity", isOn: $appState.connectivityEnabled)
            }

            SettingSectionLabel(title: "Notifications")
            SettingGroup {
                SettingToggleRow(title: "Notifications", isOn: notificationsEnabledBinding)
                if appState.notificationsEnabled {
                    SettingRowDivider()
                    notificationPermissionRow
                    SettingRowDivider()
                    SettingToggleRow(
                        title: "Show previews",
                        description: "Display sender and message text when available.",
                        isOn: notificationPreviewsBinding
                    )
                    SettingRowDivider()
                    notificationRetentionRow
                    ForEach(NotificationFeedSource.allCases) { source in
                        SettingRowDivider()
                        SettingToggleRow(
                            title: source.title,
                            description: source.description,
                            isOn: notificationSourceBinding(for: source)
                        )
                    }
                }
            }

            SettingSectionLabel(title: "Productivity")
            SettingGroup {
                SettingToggleRow(title: "Teleprompter", isOn: teleprompterEnabledBinding)
                    .dataAnnotationID("teleprompter-module-toggle")
                if appState.teleprompterEnabled {
                    SettingRowDivider()
                    teleprompterPermissionRow
                    SettingRowDivider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mode")
                                .font(.system(size: 13))
                            Text(teleprompter.listeningMode.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer(minLength: 12)
                        Picker("", selection: $teleprompter.listeningMode) {
                            ForEach(TeleprompterListeningMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 190)
                        .dataAnnotationID("teleprompter-listening-mode-control")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    SettingRowDivider()
                    HStack {
                        Text("Script")
                            .font(.system(size: 13))
                        Spacer(minLength: 8)
                        Button("Edit Script…") {
                            TeleprompterScriptEditorWindowController.show()
                        }
                        .font(.system(size: 12))
                        .dataAnnotationID("teleprompter-edit-script-button")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            notificationManager.checkPermission()
            refreshTeleprompterPermissionState()
            autoRequestTeleprompterPermissionsIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            notificationManager.checkPermission()
            refreshTeleprompterPermissionState()
        }
        .onChange(of: teleprompter.listeningMode) { _, mode in
            refreshTeleprompterPermissionState()
            if mode == .wordTracking {
                autoRequestTeleprompterPermissionsIfNeeded()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                refreshTeleprompterPermissionState()
            }
        }
        .onChange(of: appState.teleprompterEnabled) { _, enabled in
            if enabled {
                autoRequestTeleprompterPermissionsIfNeeded()
            }
        }
    }

    private var teleprompterPermissionRow: some View {
        let _ = teleprompterPermissionRefresh
        let ready = PermissionsManager.shared.checkMicrophone()
            && PermissionsManager.shared.checkSpeechRecognition()

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Word Tracking permissions")
                    .font(.system(size: 13))
                Text(teleprompterPermissionDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if ready {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            } else {
                Button(teleprompterPermissionButtonTitle) {
                    requestTeleprompterPermissions()
                }
                .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .dataAnnotationID("teleprompter-speech-status")
    }

    private var teleprompterPermissionDescription: String {
        let microphoneStatus = PermissionsManager.shared.microphoneAuthorizationStatus()
        let speechStatus = PermissionsManager.shared.speechRecognitionAuthorizationStatus()
        let microphone = microphoneStatus == .authorized
        let speech = speechStatus == .authorized

        if microphoneStatus == .denied || microphoneStatus == .restricted ||
            speechStatus == .denied || speechStatus == .restricted {
            return "Access was denied or restricted. Open System Settings to enable Word Tracking."
        }

        switch (microphone, speech) {
        case (true, true):
            return "Microphone and Speech Recognition are ready for Word Tracking."
        case (false, true):
            return "Microphone access will be requested when Word Tracking is enabled."
        case (true, false):
            return "Speech Recognition access will be requested when Word Tracking is enabled."
        case (false, false):
            return "Microphone and Speech Recognition access are requested when Teleprompter is enabled."
        }
    }

    private var teleprompterPermissionButtonTitle: String {
        let microphone = PermissionsManager.shared.microphoneAuthorizationStatus()
        let speech = PermissionsManager.shared.speechRecognitionAuthorizationStatus()
        if microphone == .denied || microphone == .restricted ||
            speech == .denied || speech == .restricted {
            return "Open Settings"
        }
        return "Grant Access"
    }

    private var notificationPermissionRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Permission")
                    .font(.system(size: 13))
                Text(notificationPermissionDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(notificationPermissionButtonTitle) {
                handleNotificationPermissionAction()
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var teleprompterEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.teleprompterEnabled },
            set: { enabled in
                appState.teleprompterEnabled = enabled
                if enabled {
                    requestTeleprompterPermissions()
                } else {
                    teleprompter.pause()
                }
            }
        )
    }

    private func requestTeleprompterPermissions() {
        didAutoRequestTeleprompterPermissions = true
        PermissionsManager.shared.requestTeleprompterWordTrackingAccess { _ in
            refreshTeleprompterPermissionState()
        }
        refreshTeleprompterPermissionState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            refreshTeleprompterPermissionState()
        }
    }

    private func autoRequestTeleprompterPermissionsIfNeeded() {
        guard appState.teleprompterEnabled else { return }
        guard !didAutoRequestTeleprompterPermissions else { return }

        let permissions = PermissionsManager.shared
        let microphone = permissions.microphoneAuthorizationStatus()
        let speech = permissions.speechRecognitionAuthorizationStatus()
        guard microphone == .notDetermined || speech == .notDetermined else {
            refreshTeleprompterPermissionState()
            return
        }

        requestTeleprompterPermissions()
    }

    private func refreshTeleprompterPermissionState() {
        teleprompterPermissionRefresh += 1
    }

    private var notificationRetentionRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Retained items")
                    .font(.system(size: 13))
                Text("How many feed items stay available in the island.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 12)
            StepperField(
                value: notificationMaxRetainedBinding,
                step: 1,
                range: 1...50
            ) { "\(Int($0))" }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var notificationPreviewsBinding: Binding<Bool> {
        Binding(
            get: { appState.notificationPreviewsEnabled },
            set: { newValue in
                appState.notificationPreviewsEnabled = newValue
                NotificationManager.shared.applyFeedPreferences()
            }
        )
    }

    private var notificationMaxRetainedBinding: Binding<Double> {
        Binding(
            get: { appState.notificationMaxRetainedItems },
            set: { newValue in
                appState.notificationMaxRetainedItems = newValue
                NotificationManager.shared.applyFeedPreferences()
            }
        )
    }

    private var notificationsEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.notificationsEnabled },
            set: { newValue in
                appState.notificationsEnabled = newValue
                guard newValue else {
                    NotificationManager.shared.clearAll()
                    return
                }

                NotificationManager.shared.checkPermission()
                if NotificationManager.shared.authorizationStatus == .notDetermined {
                    NotificationManager.shared.requestPermission()
                }
            }
        )
    }

    private func notificationSourceBinding(for source: NotificationFeedSource) -> Binding<Bool> {
        Binding(
            get: { appState.isNotificationSourceEnabled(source) },
            set: { newValue in
                appState.setNotificationSource(source, enabled: newValue)
                NotificationManager.shared.applyFeedPreferences()
            }
        )
    }

    private var notificationPermissionDescription: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "Allowed. Edit.or.lynx can send its own notifications and extension alerts."
        case .denied:
            return "Denied. Open System Settings to allow Edit.or.lynx notifications."
        case .notDetermined:
            return "Not requested. Allow this when you want Edit.or.lynx or extensions to send macOS notifications."
        case .provisional, .ephemeral:
            return "Allowed with limited delivery."
        @unknown default:
            return "Unknown. Check macOS notification settings."
        }
    }

    private var notificationPermissionButtonTitle: String {
        switch notificationManager.authorizationStatus {
        case .notDetermined:
            return "Request"
        default:
            return "Open Settings"
        }
    }

    private func handleNotificationPermissionAction() {
        switch notificationManager.authorizationStatus {
        case .notDetermined:
            notificationManager.requestPermission()
        default:
            notificationManager.openNotificationSettings()
        }
    }

    private var shelfRetentionRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shelf retention")
                    .font(.system(size: 13))
                Text("Pinned items are kept")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            Picker("", selection: $shelf.retentionDays) {
                ForEach(ShelfRetentionOption.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 120)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func homeSlotRow(title: String, selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer(minLength: 12)
            Picker("", selection: selection) {
                ForEach(HomePanel.allCases) { panel in
                    Label(panel.title, systemImage: panel.iconName)
                        .tag(panel.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 150)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var browserMediaRows: some View {
        ForEach(nowPlayingManager.browserTargets) { browser in
            SettingRowDivider()
            browserToggleRow(browser)
        }
        SettingRowDivider()
        browserDetectionTestRow
    }

    private func browserToggleRow(_ browser: NowPlayingBrowserTarget) -> some View {
        SettingToggleRow(
            title: browser.displayName,
            description: "Allow Edit.or.lynx to look for media in this browser.",
            isOn: browserBinding(for: browser.id)
        )
    }

    private var browserDetectionTestRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Detection test")
                    .font(.system(size: 13))
                Text(browserDetectionMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 6) {
                Button("Test") {
                    nowPlayingManager.testBrowserDetection()
                }
                .font(.system(size: 12))
                Button("Open Settings") {
                    nowPlayingManager.openAutomationSettings()
                }
                .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func browserBinding(for browserID: String) -> Binding<Bool> {
        Binding(
            get: { nowPlayingManager.isBrowserAllowed(browserID) },
            set: { nowPlayingManager.setBrowser(browserID, allowed: $0) }
        )
    }

    private var browserDetectionMessage: String {
        if !nowPlayingManager.browserDetectionTestMessage.isEmpty {
            return nowPlayingManager.browserDetectionTestMessage
        }
        return "Requires Automation permission and JavaScript from Apple Events in the browser."
    }
}
