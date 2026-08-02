//
//  AudioPlaybackBar.swift
//  Prosary
//
//  The compact transport strip a prayer flow shows above its footer when the session's
//  devotion+language(+variant) has a narrated recording: chapter skip / play-pause controls,
//  the current chapter's title, and a seekable timeline. Pure presentation — all state lives
//  in AudioPlaybackController, and chapter→step syncing is the owning flow view's job.
//

import SwiftUI

struct AudioPlaybackBar: View {
  let controller: AudioPlaybackController
  let seasonColor: Color
  /// The track's chapter titles, already resolved by the owning flow (titleKey goes through
  /// the bundle content chain only the flow's context knows).
  let chapterTitles: [String]

  /// Non-nil while the user is dragging the timeline: the thumb shows this value and the seek
  /// happens once on release — seeking per drag-tick fights the playback ticker's writes and
  /// hammers the decoder with a seek storm.
  @State private var scrubTime: Double? = nil

  private var chapterCount: Int { controller.track?.chapters.count ?? 0 }

  var body: some View {
    HStack(spacing: 10) {
      Button { controller.previousChapter() } label: {
        Image(systemName: "backward.end.fill")
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .disabled(chapterCount < 2)
      .accessibilityLabel(String(localized: "prayerFlow.audio.previousChapter",
                                 defaultValue: "Previous chapter"))

      Button { controller.playPause() } label: {
        Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .font(.system(size: 34))
          .foregroundStyle(seasonColor)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(controller.isPlaying
                          ? String(localized: "prayerFlow.audio.pause", defaultValue: "Pause")
                          : String(localized: "prayerFlow.audio.play", defaultValue: "Play"))
      .accessibilityIdentifier("audioPlayPauseButton")

      Button { controller.nextChapter() } label: {
        Image(systemName: "forward.end.fill")
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .disabled(chapterCount < 2)
      .accessibilityLabel(String(localized: "prayerFlow.audio.nextChapter",
                                 defaultValue: "Next chapter"))

      VStack(alignment: .leading, spacing: 0) {
        if let index = controller.currentChapterIndex, chapterTitles.indices.contains(index) {
          Text(chapterTitles[index])
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        HStack(spacing: 8) {
          Slider(
            value: Binding(
              get: { scrubTime ?? controller.currentTime },
              set: { scrubTime = $0 }),
            in: 0...max(controller.duration, 0.01),
            onEditingChanged: { editing in
              guard !editing, let target = scrubTime else { return }
              controller.seek(to: target)
              scrubTime = nil
            }
          )
          .tint(seasonColor)
          .controlSize(.mini)
          .accessibilityLabel(String(localized: "prayerFlow.audio.position",
                                     defaultValue: "Playback position"))

          Text("\(Self.timestamp(controller.currentTime))/\(Self.timestamp(controller.duration))")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 12)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
  }

  private static func timestamp(_ seconds: Double) -> String {
    let whole = Int(seconds.rounded(.down))
    return String(format: "%d:%02d", whole / 60, whole % 60)
  }
}
