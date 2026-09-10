#if os(macOS)
import SwiftUI

struct MacPrayerRemovalConfirmation: ViewModifier {
  @Binding var request: MacPrayerRemovalRequest?
  let onRemove: (MacPrayerRemovalRequest) -> Void

  func body(content: Content) -> some View {
    content.alert(request?.title ?? "", isPresented: Binding(
      get: { request != nil }, set: { if !$0 { request = nil } }), presenting: request
    ) { value in
      Button(value.actionTitle, role: .destructive) { onRemove(value) }
      Button("favoriteEditor.cancel", role: .cancel) { request = nil }
    } message: { value in Text(value.message) }
  }
}
#endif
