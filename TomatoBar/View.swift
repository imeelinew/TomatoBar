import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

extension KeyboardShortcuts.Name {
    static let startStopTimer = Self("startStopTimer")
    static let toggleRain = Self("toggleRain",
                                 default: .init(.n, modifiers: [.option]))
}

private struct IntervalsView: View {
    @EnvironmentObject var timer: TBTimer
    private var minStr = NSLocalizedString("IntervalsView.min", comment: "min")

    var body: some View {
        VStack {
            Stepper(value: $timer.workIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalLength.label",
                                           comment: "Work interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.workIntervalLength))
                }
            }
            Stepper(value: $timer.shortRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.shortRestIntervalLength.label",
                                           comment: "Short rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.shortRestIntervalLength))
                }
            }
            Stepper(value: $timer.longRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.longRestIntervalLength.label",
                                           comment: "Long rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.longRestIntervalLength))
                }
            }
            .help(NSLocalizedString("IntervalsView.longRestIntervalLength.help",
                                    comment: "Long rest interval hint"))
            Stepper(value: $timer.workIntervalsInSet, in: 1 ... 10) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalsInSet.label",
                                           comment: "Work intervals in a set label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(timer.workIntervalsInSet)")
                }
            }
            .help(NSLocalizedString("IntervalsView.workIntervalsInSet.help",
                                    comment: "Work intervals in set hint"))
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

private struct SettingsView: View {
    @EnvironmentObject var timer: TBTimer
    @ObservedObject private var launchAtLogin = LaunchAtLogin.observable

    var body: some View {
        VStack {
            KeyboardShortcuts.Recorder(for: .startStopTimer) {
                Text(NSLocalizedString("SettingsView.shortcut.label",
                                       comment: "Shortcut label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle(isOn: $timer.stopAfterBreak) {
                Text(NSLocalizedString("SettingsView.stopAfterBreak.label",
                                       comment: "Stop after break label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Toggle(isOn: $timer.showTimerInMenuBar) {
                Text(NSLocalizedString("SettingsView.showTimerInMenuBar.label",
                                       comment: "Show timer in menu bar label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
                .onChange(of: timer.showTimerInMenuBar) { _ in
                    timer.updateTimeLeft()
                }
            Toggle(isOn: $launchAtLogin.isEnabled) {
                Text(NSLocalizedString("SettingsView.launchAtLogin.label",
                                       comment: "Launch at login label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

private struct VolumeSlider: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var volume: Double
    private let volumeRange = 0.0...2.0
    private let step = 0.1

    private func updateVolume(delta: Double) {
        let nextValue = ((volume + delta) * 10).rounded() / 10
        volume = min(max(nextValue, volumeRange.lowerBound), volumeRange.upperBound)
    }

    private func controlButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(buttonForegroundColor)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(buttonBackgroundColor)
                )
                .overlay(
                    Circle()
                        .stroke(buttonStrokeColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var buttonForegroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.82) : Color.black.opacity(0.68)
    }

    private var buttonBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var buttonStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
    }

    var body: some View {
        HStack(spacing: 10) {
            controlButton(symbol: "minus") {
                updateVolume(delta: -step)
            }
            .opacity(volume > volumeRange.lowerBound ? 1.0 : 0.4)
            .disabled(volume <= volumeRange.lowerBound)

            Text(String(format: "%.1f", volume))
                .font(.system(.body).monospacedDigit())
                .frame(width: 32)

            controlButton(symbol: "plus") {
                updateVolume(delta: step)
            }
            .opacity(volume < volumeRange.upperBound ? 1.0 : 0.4)
            .disabled(volume >= volumeRange.upperBound)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct SoundsView: View {
    @EnvironmentObject var player: TBPlayer

    private var columns = [
        GridItem(.flexible()),
        GridItem(.fixed(110))
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("SoundsView.isWindupEnabled.label",
                                   comment: "Windup label"))
            VolumeSlider(volume: $player.windupVolume)
            Text(NSLocalizedString("SoundsView.isDingEnabled.label",
                                   comment: "Ding label"))
            VolumeSlider(volume: $player.dingVolume)
            Text(NSLocalizedString("SoundsView.rainVolume.label",
                                   comment: "Rain volume label"))
            VolumeSlider(volume: $player.rainVolume)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        Spacer().frame(minHeight: 0)
    }
}

private struct FullWidthButtonLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundColor(Color.white)
            .font(.system(.body).monospacedDigit())
            .frame(maxWidth: .infinity)
    }
}

private struct FilledActionButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let isActive: Bool
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor)
                    .brightness(isActive ? -0.15 : 0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(isHovered ? 0.10 : 0))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.white.opacity(isHovered ? 0.22 : 0.08), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: Color.black.opacity(isHovered ? 0.22 : 0.12),
                    radius: isHovered ? 8 : 4,
                    y: isHovered ? 3 : 2)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
    }
}

private struct RainToggleButton: View {
    @EnvironmentObject var player: TBPlayer
    @State private var isHovered = false

    private var rainStartLabel = NSLocalizedString("TBPopoverView.rainStart.label",
                                                   comment: "Start rain label")
    private var rainStopLabel = NSLocalizedString("TBPopoverView.rainStop.label",
                                                  comment: "Stop rain label")

    var body: some View {
        Button {
            TBStatusItem.shared.performAfterClosingPopover {
                player.toggleRain()
            }
        } label: {
            FullWidthButtonLabel(text: player.isRainEnabled ? rainStopLabel : rainStartLabel)
        }
        .onHover { over in
            isHovered = over
        }
        .controlSize(.large)
        .buttonStyle(FilledActionButtonStyle(backgroundColor: .blue,
                                             isActive: player.isRainEnabled,
                                             isHovered: isHovered))
    }
}

private enum ChildView {
    case sounds, intervals, settings
}

struct TBPopoverView: View {
    @ObservedObject var timer = TBTimer()
    @State private var startButtonHovered = false
    @State private var activeChildView = ChildView.sounds

    private var startLabel = NSLocalizedString("TBPopoverView.start.label", comment: "Start label")
    private var stopLabel = NSLocalizedString("TBPopoverView.stop.label", comment: "Stop label")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                TBStatusItem.shared.performAfterClosingPopover {
                    timer.startStop()
                }
            } label: {
                FullWidthButtonLabel(
                    text: timer.timer != nil ?
                        (startButtonHovered ? stopLabel : timer.timeLeftString) :
                        startLabel
                )
            }
            .onHover { over in
                startButtonHovered = over
            }
            .controlSize(.large)
            .buttonStyle(FilledActionButtonStyle(backgroundColor: .accentColor,
                                                 isActive: timer.timer != nil,
                                                 isHovered: startButtonHovered))
            .keyboardShortcut(.defaultAction)

            RainToggleButton().environmentObject(timer.player)

            Picker("", selection: $activeChildView) {
                Text(NSLocalizedString("TBPopoverView.sounds.label",
                                       comment: "Sounds label")).tag(ChildView.sounds)
                Text(NSLocalizedString("TBPopoverView.intervals.label",
                                       comment: "Intervals label")).tag(ChildView.intervals)
                Text(NSLocalizedString("TBPopoverView.settings.label",
                                       comment: "Settings label")).tag(ChildView.settings)
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .pickerStyle(.segmented)

            GroupBox {
                switch activeChildView {
                case .intervals:
                    IntervalsView().environmentObject(timer)
                case .settings:
                    SettingsView().environmentObject(timer)
                case .sounds:
                    SoundsView().environmentObject(timer.player)
                }
            }

            Group {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel()
                } label: {
                    Text(NSLocalizedString("TBPopoverView.about.label",
                                           comment: "About label"))
                    Spacer()
                    Text("⌘ A").foregroundColor(Color.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("a")
                Button {
                    NSApplication.shared.terminate(self)
                } label: {
                    Text(NSLocalizedString("TBPopoverView.quit.label",
                                           comment: "Quit label"))
                    Spacer()
                    Text("⌘ Q").foregroundColor(Color.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
        }
        #if DEBUG
            /*
             After several hours of Googling and trying various StackOverflow
             recipes I still haven't figured a reliable way to auto resize
             popover to fit all it's contents (pull requests are welcome!).
             The following code block is used to determine the optimal
             geometry of the popover.
             */
            .overlay(
                GeometryReader { proxy in
                    debugSize(proxy: proxy)
                }
            )
        #endif
            /* Use values from GeometryReader */
//            .frame(width: 240, height: 276)
            .padding(12)
    }
}

#if DEBUG
    func debugSize(proxy: GeometryProxy) -> some View {
        print("Optimal popover size:", proxy.size)
        return Color.clear
    }
#endif
