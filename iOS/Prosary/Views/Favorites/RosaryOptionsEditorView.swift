//
//  RosaryOptionsEditorView.swift
//  Prosary
//
//  The Rosary-specific options, split out of FavoriteEditorView into their own pushed screen
//  (a "submenu") rather than 4 inline sections in the main editor — those 4 sections made the
//  Rosary editor much longer than every other kind's, for options most sessions never touch.
//  Edits the binding directly; the parent FavoriteEditorView's own Save button persists them,
//  this screen has no save/cancel of its own.
//

import SwiftUI

struct RosaryOptionsEditorView: View {
  @Binding var rosary: RosaryOptions

  var body: some View {
    Form {
      Section("favoriteEditor.whichMysteries") {
        Picker("favoriteEditor.mysteriesPicker", selection: $rosary.mysterySelectionMode) {
          ForEach(MysterySelectionMode.allCases) { mode in
            Text(mode.displayName).tag(mode)
          }
        }
        if rosary.mysterySelectionMode == .specific || rosary.mysterySelectionMode == .singleMystery {
          Picker("favoriteEditor.specificSet", selection: $rosary.specificMysteryGroup) {
            ForEach(MysteryGroup.allCases) { group in
              Text(group.displayName).tag(group)
            }
          }
        }
        if rosary.mysterySelectionMode == .singleMystery {
          Picker("favoriteEditor.specificMystery", selection: $rosary.specificMysteryOrder) {
            ForEach(MysteryCatalog.forGroup(rosary.specificMysteryGroup)) { mystery in
              Text(MysteryTranslations.get(languageCode: "en", imageKey: mystery.imageKey).title).tag(mystery.order)
            }
          }
        }
      }

      Section("favoriteEditor.openingDecadePrayers") {
        Toggle("favoriteEditor.apostlesCreed", isOn: $rosary.includeApostlesCreed)
        Toggle("favoriteEditor.openingPrayers", isOn: $rosary.includeOpeningPrayers)
        Toggle("favoriteEditor.fatimaPrayer", isOn: $rosary.includeFatimaPrayer)
        Picker("favoriteEditor.eternalRest", selection: $rosary.eternalRestForDeceased) {
          ForEach(EternalRestPlacement.allCases) { option in
            Text(option.displayName).tag(option)
          }
        }
      }

      Section {
        Toggle("favoriteEditor.presenterMode", isOn: $rosary.presenterMode)
      } header: {
        Text("favoriteEditor.presenterModeHeader")
      } footer: {
        Text("favoriteEditor.presenterModeFooter")
      }

      Section("favoriteEditor.closingPrayers") {
        Picker("favoriteEditor.marianAntiphon", selection: $rosary.marianAntiphon) {
          ForEach(MarianAntiphonOption.allCases) { option in
            Text(option.displayName).tag(option)
          }
        }
        Toggle("favoriteEditor.stMichaelPrayer", isOn: $rosary.includeStMichaelPrayer)
        Toggle("favoriteEditor.finalSignOfCross", isOn: $rosary.includeFinalSignOfCross)
      }
    }
    .formStyle(.grouped)
    .navigationTitle("favoriteEditor.rosaryOptionsTitle")
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}

#Preview {
  @Previewable @State var rosary = RosaryOptions()
  NavigationStack {
    RosaryOptionsEditorView(rosary: $rosary)
  }
}
