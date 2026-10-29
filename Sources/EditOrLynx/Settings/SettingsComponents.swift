import SwiftUI
import AppKit

public struct SettingsGroup<Content: View>: View {
    public var title: String?
    public let content: Content

    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.leading, 6)
            }

            VStack(spacing: 0) {
                content
            }
            .background(AppTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.stroke, lineWidth: 1)
            )
        }
        .padding(.bottom, 14)
    }
}

public struct SWDivider: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(AppTheme.divider)
            .frame(height: 1)
            .padding(.horizontal, 14)
    }
}

public struct SWToggleRow: View {
    public var title: String
    public var subtitle: String?
    @Binding public var isOn: Bool

    public init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

public struct SWSliderRow: View {
    public var title: String
    public var subtitle: String?
    @Binding public var value: Double
    public var range: ClosedRange<Double>
    public var step: Double?
    public var valueLabel: String

    public init(title: String, subtitle: String? = nil, value: Binding<Double>, range: ClosedRange<Double>, step: Double? = nil, valueLabel: String) {
        self.title = title
        self.subtitle = subtitle
        self._value = value
        self.range = range
        self.step = step
        self.valueLabel = valueLabel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)
            }
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let s = step {
                Slider(value: $value, in: range, step: s)
            } else {
                Slider(value: $value, in: range)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

public struct SWMenuRow<T: Hashable>: View {
    public var title: String
    public var subtitle: String?
    @Binding public var selection: T
    public var options: [(T, String)]

    public init(title: String, subtitle: String? = nil, selection: Binding<T>, options: [(T, String)]) {
        self.title = title
        self.subtitle = subtitle
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.0) { opt in
                    Text(opt.1).tag(opt.0)
                }
            }
            .labelsHidden()
            .frame(width: 170)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

public struct SWButtonRow: View {
    public var title: String
    public var subtitle: String?
    public var buttonTitle: String
    public var icon: String?
    public var action: () -> Void

    public init(title: String, subtitle: String? = nil, buttonTitle: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            Button(action: action) {
                HStack(spacing: 4) {
                    if let icon = icon {
                        Image(systemName: icon)
                    }
                    Text(buttonTitle)
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
