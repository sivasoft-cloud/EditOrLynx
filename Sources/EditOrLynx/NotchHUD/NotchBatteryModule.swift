import SwiftUI
import IOKit.ps

public struct NotchBatteryModule: View {
    @State private var batteryLevel: Int = 100
    @State private var isCharging: Bool = false

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCharging ? "battery.100.bolt" : (batteryLevel < 20 ? "battery.25" : "battery.100"))
                .font(.system(size: 26))
                .foregroundColor(batteryLevel < 20 ? .red : (isCharging ? .green : Color.accentColor))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(batteryLevel)% Battery")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(isCharging ? "Charging on AC Power" : "Running on Battery")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .onAppear {
            refreshBattery()
        }
    }

    private func refreshBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else { continue }
            if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                self.batteryLevel = Int((Double(cur) / Double(max)) * 100)
            }
            if let isCharging = desc[kIOPSIsChargingKey] as? Bool {
                self.isCharging = isCharging
            }
        }
    }
}
