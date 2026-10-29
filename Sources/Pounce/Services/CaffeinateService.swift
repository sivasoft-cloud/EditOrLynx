import AppKit
import Foundation
import IOKit.pwr_mgt
import Combine

/// Prevents display and system sleep with 1 click, keeps long renders & downloads alive,
/// and configures lock screen dynamic widget controls.
@MainActor
public final class CaffeinateService: ObservableObject {
    public static let shared = CaffeinateService()

    public enum DurationOption: String, CaseIterable, Identifiable {
        case indefinite = "Indefinite (∞)"
        case oneHour = "1 Hour"
        case twoHours = "2 Hours"
        case fiveHours = "5 Hours"
        case whileTasksActive = "While Tasks Active"

        public var id: String { rawValue }

        public var seconds: TimeInterval? {
            switch self {
            case .indefinite: return nil
            case .oneHour: return 3600
            case .twoHours: return 7200
            case .fiveHours: return 18000
            case .whileTasksActive: return nil
            }
        }
    }

    @Published public private(set) var isActive: Bool = false
    @Published public var selectedDuration: DurationOption = .indefinite
    @Published public private(set) var remainingSeconds: TimeInterval = 0

    // Lock screen widget toggles
    @Published public var lockScreenNowPlaying: Bool = true
    @Published public var lockScreenTasksAndRenders: Bool = true
    @Published public var lockScreenWeather: Bool = true
    @Published public var lockScreenSports: Bool = false

    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?

    private init() {}

    public func toggle() {
        if isActive {
            deactivate()
        } else {
            activate(duration: selectedDuration)
        }
    }

    public func activate(duration: DurationOption) {
        selectedDuration = duration
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }

        let reason = "Edit.or.lynx Caffeinate: Keeping Mac awake for downloads and render tasks" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        if result == kIOReturnSuccess {
            isActive = true
            timer?.invalidate()
            timer = nil

            if let secs = duration.seconds {
                remainingSeconds = secs
                let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] t in
                    Task { @MainActor in
                        guard let self else { return }
                        if self.remainingSeconds > 1 {
                            self.remainingSeconds -= 1
                        } else {
                            self.deactivate()
                        }
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                self.timer = timer
            } else {
                remainingSeconds = 0
            }
        }
    }

    public func deactivate() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingSeconds = 0
    }

    public var statusText: String {
        if !isActive { return "Sleep Allowed" }
        if let _ = selectedDuration.seconds, remainingSeconds > 0 {
            let m = Int(remainingSeconds) / 60
            let s = Int(remainingSeconds) % 60
            return String(format: "Awake for %02d:%02d", m, s)
        }
        return "Always Awake (Caffeinated)"
    }
}
