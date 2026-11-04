import Observation
import PedalboardCore
import SwiftUI

/// What one mic's mixer row shows, rebuilt from the `Pedal` after every
/// reconcile.
struct MicRow: Identifiable, Equatable {
    enum Mute: Equatable {
        /// Kept live: M is dark.
        case live
        /// In the muted group but the pedal is up: M is outlined.
        case armed
        /// Silenced right now: M is lit.
        case muted
        /// Not live, and nothing can silence it: M is disabled.
        case unsilenceable
    }

    let id: String
    let name: String
    let mute: Mute
    let isSoloed: Bool
    /// Always set, so every row is the same height while the menu is open.
    let subtitle: String
}

/// The rows the open menu draws. Buttons inside a menu don't close it, so
/// the rows must follow the pedal live rather than be built once.
@MainActor
@Observable
final class MixerModel {
    var rows: [MicRow] = []
    @ObservationIgnored var toggleMute: (String) -> Void = { _ in }
    @ObservationIgnored var solo: (String) -> Void = { _ in }
}

/// A mic in the menu, mixing-desk style: its name and state, then M (mute,
/// i.e. not live) and S (solo: only this mic live, pedal down).
struct MixerRowView: View {
    enum Metrics {
        static let width: CGFloat = 300
        static let buttonSize = CGSize(width: 22, height: 18)
        static let leading: CGFloat = 14
        static let trailing: CGFloat = 12
    }

    let id: String
    let model: MixerModel

    var body: some View {
        if let row = model.rows.first(where: { $0.id == id }) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(row.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                ChannelButton(
                    letter: "M", tint: .red, fill: muteFill(row.mute),
                    label: row.mute == .live ? "Mute \(row.name)" : "Keep \(row.name) live",
                    help: muteHelp(row.mute)
                ) { model.toggleMute(row.id) }
                .disabled(row.mute == .unsilenceable)
                ChannelButton(
                    letter: "S", tint: .yellow, fill: row.isSoloed ? .lit : .dark,
                    label: "Solo \(row.name)",
                    help: row.isSoloed ? "Soloed — click to unmute every mic" : "Hear only this mic: mute every other one"
                ) { model.solo(row.id) }
            }
            .padding(.leading, Metrics.leading)
            .padding(.trailing, Metrics.trailing)
            .padding(.vertical, 4)
            .frame(width: Metrics.width, alignment: .leading)
        }
    }

    private func muteFill(_ mute: MicRow.Mute) -> ChannelButton.Fill {
        switch mute {
        case .live, .unsilenceable: .dark
        case .armed: .outlined
        case .muted: .lit
        }
    }

    private func muteHelp(_ mute: MicRow.Mute) -> String {
        switch mute {
        case .live: "Live — click to mute with the others"
        case .armed: "Mutes when the pedal is on — click to keep it live"
        case .muted: "Muted — click to keep it live"
        case .unsilenceable: "This mic has no mute or volume control"
        }
    }
}

/// A small square mixer button: dark when off, lit in its colour when on.
struct ChannelButton: View {
    enum Fill { case dark, outlined, lit }

    let letter: String
    let tint: Color
    let fill: Fill
    let label: String
    let help: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(.caption.weight(.bold))
                .foregroundStyle(fill == .lit ? Color.black.opacity(0.8) : Color.secondary)
                .frame(width: MixerRowView.Metrics.buttonSize.width, height: MixerRowView.Metrics.buttonSize.height)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(fill == .lit ? AnyShapeStyle(tint) : AnyShapeStyle(.quaternary)))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(tint, lineWidth: fill == .outlined ? 1.5 : 0))
                .opacity(isEnabled ? 1 : 0.4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(label)
        .accessibilityAddTraits(fill == .lit ? .isSelected : [])
    }
}
