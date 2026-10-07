import SwiftUI

/// An optional reference shelf for the selected calendar day. Its parent identity follows
/// the date and interface language so opening one day never opens the next day's prose.
struct SaintDescriptionsView: View {
  let feast: FeastDay
  let calendarID: String
  let language: String
  @State private var isExpanded = false

  private var descriptions: [FeastSaintDescription] {
    feast.saintDescriptions(calendarID: calendarID, language: language)
  }

  var body: some View {
    if !descriptions.isEmpty {
      DisclosureGroup(isExpanded: $isExpanded) {
        VStack(alignment: .leading, spacing: 20) {
          ForEach(Array(descriptions.enumerated()), id: \.offset) { index, description in
            VStack(alignment: .leading, spacing: 8) {
              if showsTitle(description) {
                Text(verbatim: description.title)
                  .font(.headline)
                  .accessibilityAddTraits(.isHeader)
              }
              Text(verbatim: description.text)
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("today.saintDescription.\(index)")
              if let credit = description.credit {
                Text(verbatim: credit)
                  .font(.caption).foregroundStyle(.secondary)
              }
              if let sourceURL = description.sourceURL {
                Link(UILanguage.text("readings.source", language: language, fallback: "Text source"),
                     destination: sourceURL)
                  .font(.caption)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(.top, 12)
        .textSelection(.enabled)
      } label: {
        Text(UILanguage.text("home.today.aboutSaints", language: language, fallback: "About the saints"))
          #if os(macOS)
          .font(.subheadline.weight(.medium))
          #else
          .font(.headline)
          #endif
          .accessibilityIdentifier("today.saintDescriptions")
      }
    }
  }

  private func showsTitle(_ description: FeastSaintDescription) -> Bool {
    #if os(macOS)
    return descriptions.count != 1 || description.title != feast.localizedTitle(language)
    #else
    return true
    #endif
  }
}
