import AVFoundation
import Observation
import os

/// Reads sourced prayer text with an installed system voice. Never asks the synthesizer to
/// choose a default voice: unsupported prayer languages remain silent.
@MainActor
@Observable
final class PrayerSpeechController: NSObject, AVSpeechSynthesizerDelegate {
  private(set) var isSpeaking = false
  private let synthesizer = AVSpeechSynthesizer()
  private var activeUtterance: AVSpeechUtterance?
  private var activeToken: UUID?
  // Delegate callbacks can arrive after a new utterance starts. Capture an immutable,
  // Sendable lifetime token before hopping actors, without retaining AVSpeechUtterance
  // across that boundary or relying on a potentially reused object address.
  nonisolated private let utteranceTokens = OSAllocatedUnfairLock(initialState: [ObjectIdentifier: UUID]())

  override init() {
    super.init()
    synthesizer.delegate = self
  }

  static func baseLanguage(_ code: String) -> String {
    let base = code.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map(String.init) ?? ""
    return base == "iw" ? "he" : base == "fil" ? "tl" : base
  }

  static func voiceMatches(_ voiceLanguage: String, prayerLanguage: String) -> Bool {
    let prayer = baseLanguage(prayerLanguage)
    return !prayer.isEmpty && baseLanguage(voiceLanguage) == prayer
  }

  static func normalizeHebrewSpeech(_ text: String) -> String {
    let diacritics = "[\\u0591-\\u05bd\\u05bf-\\u05c2\\u05c4\\u05c5\\u05c7]*"
    let divine = "(?:י\(diacritics)ה\(diacritics)ו\(diacritics)ה\(diacritics)|ה\(diacritics)[׳\\u0027]|י\(diacritics)י\(diacritics))"
    let adonai = "א\(diacritics)ד\(diacritics)נָ?\(diacritics)[יי]\(diacritics)"
    let prefix = "([בלמכשו]\(diacritics))"
    let boundary = "(?:^|[^\\u0591-\\u05bd\\u05bf-\\u05c2\\u05c4-\\u05c5\\u05c7\\u05d0-\\u05ea])"
    let lookahead = "(?=$|[^\\u0591-\\u05bd\\u05bf-\\u05c2\\u05c4-\\u05c5\\u05c7\\u05d0-\\u05ea])"

    var result = text

    let elohimPattern = "(\(boundary))(\\S*\(adonai)\\S*)(\\s+)\(prefix)?\(divine)\(lookahead)"
    if let regex = try? NSRegularExpression(pattern: elohimPattern) {
      let ns = result as NSString
      let matches = regex.matches(in: result, range: NSRange(location: 0, length: ns.length)).reversed()
      for match in matches {
        let pre = ns.substring(with: match.range(at: 1))
        let adonaiWord = ns.substring(with: match.range(at: 2))
        let between = ns.substring(with: match.range(at: 3))
        var p = ""
        if match.range(at: 4).location != NSNotFound {
          let rawPrefix = ns.substring(with: match.range(at: 4))
          if let first = rawPrefix.unicodeScalars.first {
            switch first {
            case "ו": p = "וֵ"
            case "ל": p = "לֵ"
            case "ב": p = "בֵּ"
            case "מ": p = "מֵ"
            default: p = String(first)
            }
          }
        }
        let elohim = p.isEmpty ? "אֱלֹהִים" : "\(p)אלֹהִים"
        let replacement = "\(pre)\(adonaiWord)\(between)\(elohim)"
        result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
      }
    }

    let divinePattern = "(\(boundary))\(prefix)?\(divine)\(lookahead)"
    if let regex = try? NSRegularExpression(pattern: divinePattern) {
      let ns = result as NSString
      let matches = regex.matches(in: result, range: NSRange(location: 0, length: ns.length)).reversed()
      for match in matches {
        let pre = ns.substring(with: match.range(at: 1))
        var word = "אֲדֹנָי"
        if match.range(at: 2).location != NSNotFound {
          let rawPrefix = ns.substring(with: match.range(at: 2))
          if let first = rawPrefix.unicodeScalars.first {
            switch first {
            case "ל": word = "לַאדֹנָי"
            case "ב": word = "בַּאדֹנָי"
            case "ו": word = "וַאדֹנָי"
            case "מ": word = "מֵאדֹנָי"
            case "כ": word = "כַּאדֹנָי"
            case "ש": word = "שֶׁאֲדֹנָי"
            default: word = "\(first)אֲדֹנָי"
            }
          }
        }
        let replacement = "\(pre)\(word)"
        result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
      }
    }

    return result
  }

  static func spokenText(_ text: String, languageCode: String? = nil) -> String {
    // The prayer body format uses ** only for the response's weight, not as spoken text.
    var body = text.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    let isHebrew = languageCode.map { baseLanguage($0) == "he" } ?? body.unicodeScalars.contains { ("\u{0590}"..."\u{05FF}").contains($0) }
    if isHebrew {
      body = normalizeHebrewSpeech(body)
    }
    return body
  }

  private func voice(for languageCode: String) -> AVSpeechSynthesisVoice? {
    let voices = AVSpeechSynthesisVoice.speechVoices().filter {
      Self.voiceMatches($0.language, prayerLanguage: languageCode)
    }
    let deviceLanguage = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    return voices.first { $0.language.caseInsensitiveCompare(deviceLanguage) == .orderedSame }
      ?? voices.sorted { $0.quality.rawValue > $1.quality.rawValue }.first
  }

  func canSpeak(languageCode: String?) -> Bool {
    guard let languageCode else { return false }
    return voice(for: languageCode) != nil
  }

  @discardableResult
  func speak(_ text: String, languageCode: String?) -> Bool {
    stop()
    guard let languageCode, let voice = voice(for: languageCode) else { return false }
    let body = Self.spokenText(text, languageCode: languageCode)
    guard !body.isEmpty else { return false }
    #if os(iOS) || os(visionOS)
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch { return false }
    #endif
    let utterance = AVSpeechUtterance(string: body)
    utterance.voice = voice
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    activeUtterance = utterance
    let token = UUID()
    activeToken = token
    let utteranceID = ObjectIdentifier(utterance)
    utteranceTokens.withLock { $0[utteranceID] = token }
    isSpeaking = true
    synthesizer.speak(utterance)
    return true
  }

  func stop(deactivateSession: Bool = true) {
    let wasSpeaking = isSpeaking
    if let activeUtterance {
      let utteranceID = ObjectIdentifier(activeUtterance)
      _ = utteranceTokens.withLock { $0.removeValue(forKey: utteranceID) }
    }
    activeUtterance = nil
    activeToken = nil
    synthesizer.stopSpeaking(at: .immediate)
    isSpeaking = false
    if wasSpeaking && deactivateSession { releaseAudioSession() }
  }

  private func releaseAudioSession() {
    #if os(iOS) || os(visionOS)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    #endif
  }

  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    let utteranceID = ObjectIdentifier(utterance)
    guard let token = utteranceTokens.withLock({ $0.removeValue(forKey: utteranceID) }) else { return }
    Task { @MainActor in
      guard self.activeToken == token else { return }
      self.activeUtterance = nil
      self.activeToken = nil
      self.isSpeaking = false
      self.releaseAudioSession()
    }
  }

  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    let utteranceID = ObjectIdentifier(utterance)
    guard let token = utteranceTokens.withLock({ $0.removeValue(forKey: utteranceID) }) else { return }
    Task { @MainActor in
      guard self.activeToken == token else { return }
      self.activeUtterance = nil
      self.activeToken = nil
      self.isSpeaking = false
      self.releaseAudioSession()
    }
  }
}
