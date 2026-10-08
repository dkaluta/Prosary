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
              if description.showsTitle(beneath: feast.localizedTitle(language)) {
                Text(verbatim: description.title)
                  .font(.headline)
                  .accessibilityAddTraits(.isHeader)
              }
              if description.sections.isEmpty {
                prose(description.text)
                  .accessibilityIdentifier("today.saintDescription.\(index)")
              } else {
                ForEach(Array(description.sections.enumerated()), id: \.offset) { _, section in
                  VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: HebrewDisplayText.unpointed(section.title))
                      .font(.headline)
                      .accessibilityAddTraits(.isHeader)
                    prose(section.text)
                  }
                  .accessibilityIdentifier("today.saintDescription.\(index).section.\(section.id)")
                }
              }
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

  private func prose(_ text: String) -> some View {
    Text(verbatim: text)
      .font(.body)
      .lineSpacing(3)
      .fixedSize(horizontal: false, vertical: true)
  }

}
