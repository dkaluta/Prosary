import SwiftUI

#if !os(macOS)
struct AppearanceSettingsView: View {
  @AppStorage(AppColor.defaultsKey) private var storedColor = AppColor.blue.rawValue
  @ObservedObject private var iconController = AppIconController.shared

  var body: some View {
    Form {
      Section {
        ForEach(AppColor.allCases) { color in
          let isSelected = AppColor.resolved(storedColor) == color
          Button {
            storedColor = color.rawValue
          } label: {
            HStack(spacing: 16) {
              Image(color.previewAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .overlay {
                  RoundedRectangle(cornerRadius: 15)
                    .stroke(.secondary.opacity(0.25), lineWidth: 0.5)
                }
                .accessibilityHidden(true)
              Text(color.title).font(.body).foregroundStyle(.primary)
              Spacer(minLength: 12)
              if isSelected {
                Image(systemName: "checkmark")
                  .font(.body.weight(.semibold))
                  .foregroundStyle(.tint)
                  .accessibilityHidden(true)
              }
            }
            .frame(minHeight: 64)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("appColorOption-\(color.rawValue)")
          .accessibilityLabel(color.title)
          .accessibilityAddTraits(isSelected ? .isSelected : [])
          .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
          .alignmentGuide(.listRowSeparatorLeading) { dimensions in dimensions[.leading] + 80 }
        }
      } footer: {
        #if os(visionOS)
        Text(String(localized: "settings.appColor.visionFooter", defaultValue: "Changes the accent color. The app icon stays blue on visionOS.", bundle: UILanguage.bundle, locale: UILanguage.locale))
        #else
        Text(String(localized: "settings.appColor.footer", defaultValue: "Changes the accent color and app icon.", bundle: UILanguage.bundle, locale: UILanguage.locale))
        #endif
      }
    }
    .formStyle(.grouped)
    .navigationTitle(String(localized: "settings.appearanceHeader", defaultValue: "Appearance", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .navigationBarTitleDisplayMode(.inline)
    .alert(String(localized: "settings.appColor.iconError", defaultValue: "Could Not Change App Icon", bundle: UILanguage.bundle, locale: UILanguage.locale),
           isPresented: Binding(get: { iconController.errorMessage != nil }, set: { if !$0 { iconController.errorMessage = nil } })) {
      Button("common.ok") { iconController.errorMessage = nil }
    } message: { Text(iconController.errorMessage ?? "") }
  }
}
#endif
