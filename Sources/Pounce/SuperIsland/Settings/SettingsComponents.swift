import SwiftUI
import AppKit

// MARK: - Notchy Color Palette
public enum NotchyTheme {
    public static let bg            = Color(white: 0.110) // #1C1C1C window background
    public static let cardBg        = Color(white: 0.155) // #282828 card background
    public static let sidebarSel    = Color(white: 0.200) // #333333 active sidebar pill
    public static let border        = Color(white: 1.0, opacity: 0.08)
    public static let divider       = Color(white: 1.0, opacity: 0.08)
    public static let textSec       = Color(white: 0.65)
    public static let textPrimary   = Color.white
    public static let textSecondary = Color(white: 0.65)
    public static let textTertiary  = Color(white: 0.45)
    public static let accent        = Color.cyan
}

// MARK: - SettingsGroup (Card)

public struct SettingsGroup<Content: View>: View {
    public var title: String?
    @ViewBuilder public var content: Content

    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchyTheme.textSec)
                    .textCase(.uppercase)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(NotchyTheme.cardBg)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(NotchyTheme.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - SWDivider

public struct SWDivider: View {
    public var leadingPadding: CGFloat = 16

    public init(leadingPadding: CGFloat = 16) {
        self.leadingPadding = leadingPadding
    }

    public var body: some View {
        Rectangle()
            .fill(NotchyTheme.divider)
            .frame(height: 0.5)
            .padding(.leading, leadingPadding)
    }
}

// MARK: - SWToggleRow

public struct SWToggleRow: View {
    public let title: String
    public var subtitle: String? = nil
    @Binding public var isOn: Bool

    public init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    public init(title: String, description: String?, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = description
        self._isOn = isOn
    }

    public var body: some View {
        HStack(alignment: subtitle != nil ? .top : .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(NotchyTheme.textSec)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

// MARK: - SWSliderRow

public struct SWSliderRow: View {
    public let title: String
    public var subtitle: String? = nil
    @Binding public var value: Double
    public var range: ClosedRange<Double>
    public var step: Double
    public var format: (Double) -> String

    public init(
        title: String,
        subtitle: String? = nil,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1.0,
        format: @escaping (Double) -> String = { "\(Int($0))" }
    ) {
        self.title = title
        self.subtitle = subtitle
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    public var body: some View {
        HStack(alignment: subtitle != nil ? .top : .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(NotchyTheme.textSec)
                }
            }
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                Slider(value: $value, in: range, step: step)
                    .frame(width: 140)

                Text(format(value))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(minWidth: 44, alignment: .trailing)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color(white: 0.22))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

// MARK: - SWMenuRow

public struct SWMenuRow<T: Hashable>: View {
    public let title: String
    public var subtitle: String? = nil
    @Binding public var selection: T
    public let options: [(tag: T, label: String)]

    public init(
        title: String,
        subtitle: String? = nil,
        selection: Binding<T>,
        options: [(tag: T, label: String)]
    ) {
        self.title = title
        self.subtitle = subtitle
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(alignment: subtitle != nil ? .top : .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(NotchyTheme.textSec)
                }
            }
            Spacer(minLength: 12)
            Picker("", selection: $selection) {
                ForEach(0..<options.count, id: \.self) { idx in
                    Text(options[idx].label).tag(options[idx].tag)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(minWidth: 130)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - SWButtonRow

public struct SWButtonRow: View {
    public let title: String
    public var subtitle: String? = nil
    public let buttonTitle: String
    public var buttonIcon: String? = nil
    public var isDestructive: Bool = false
    public let action: () -> Void

    public init(
        title: String,
        subtitle: String? = nil,
        buttonTitle: String,
        buttonIcon: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.buttonIcon = buttonIcon
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        HStack(alignment: subtitle != nil ? .top : .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(NotchyTheme.textSec)
                }
            }
            Spacer(minLength: 12)
            Button(action: action) {
                HStack(spacing: 5) {
                    if let icon = buttonIcon {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text(buttonTitle)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(isDestructive ? .red : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isDestructive ? Color.red.opacity(0.15) : Color(white: 0.22))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - SWInfoRow

public struct SWInfoRow: View {
    public let title: String
    public let value: String
    public var icon: String? = nil

    public init(title: String, value: String, icon: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(NotchyTheme.textSec)
                }
                Text(value)
                    .font(.system(size: 12))
                    .foregroundColor(NotchyTheme.textSec)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

// MARK: - SWNoteRow

public struct SWNoteRow: View {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(NotchyTheme.textSec)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
