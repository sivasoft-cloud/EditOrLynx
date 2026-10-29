import SwiftUI

struct BatteryCompactView: View {
    @ObservedObject private var manager = BatteryManager.shared

    var body: some View {
        if manager.hasBattery {
            HStack(spacing: 6) {
                Image(systemName: manager.batteryIconName)
                    .font(.system(size: 14))
                    .foregroundColor(batteryColor)
                    .symbolEffect(.pulse, isActive: manager.isLowBattery)

                Text("\(manager.batteryLevel)%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
        } else {
            HStack(spacing: 5) {
                Circle()
                    .fill(Pal.accent)
                    .frame(width: 5, height: 5)
                Text("Edit.or.lynx")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }

    private var batteryColor: Color {
        if manager.isCharging { return .green }
        if manager.batteryLevel <= 10 { return .red }
        if manager.batteryLevel <= 20 { return .yellow }
        return .white
    }
}
