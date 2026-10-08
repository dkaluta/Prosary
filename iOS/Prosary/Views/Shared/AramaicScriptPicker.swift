import SwiftUI

/// The same alphabet control serves prayers and Scripture. Its visible letters stay large
/// enough to distinguish, while accessibility and tooltips use the full localized names.
struct AramaicScriptPicker: View {
  @Binding var script: String
  var accessibilityIdentifier: String

  var body: some View {
    HStack(spacing: 6) {
      option("Syrc", glyph: "ܐ", font: FontRegistration.PostScriptName.notoSansSyriac,
             label: String(localized: "settings.script.syriac", defaultValue: "Syriac Script", bundle: UILanguage.bundle, locale: UILanguage.locale))
      option("Hebr", glyph: "א", font: FontRegistration.PostScriptName.notoSansHebrew,
             label: String(localized: "settings.script.hebrew", defaultValue: "Hebrew Script", bundle: UILanguage.bundle, locale: UILanguage.locale))
    }
    .fixedSize(horizontal: true, vertical: false)
    .frame(maxWidth: .infinity, alignment: .center)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(String(localized: "readings.script", defaultValue: "Aramaic Script", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .accessibilityIdentifier(accessibilityIdentifier)
  }

  @ViewBuilder
  private func option(_ code: String, glyph: String, font: String, label: String) -> some View {
    if script == code {
      button(code, glyph: glyph, font: font, label: label)
        .buttonStyle(.borderedProminent)
        .accessibilityAddTraits(.isSelected)
    } else {
      button(code, glyph: glyph, font: font, label: label)
        .buttonStyle(.bordered)
    }
  }

  private func button(_ code: String, glyph: String, font: String, label: String) -> some View {
    Button { script = code } label: {
      Text(verbatim: glyph)
        .font(.custom(font, size: 24, relativeTo: .title2))
        .frame(minWidth: 48, minHeight: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(label)
    .help(label)
    .accessibilityIdentifier("\(accessibilityIdentifier).\(code)")
  }
}
