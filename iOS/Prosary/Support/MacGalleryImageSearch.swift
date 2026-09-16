#if os(macOS)
import Foundation

/// Wikimedia's documented search generator and imageinfo metadata, without an API key.
/// https://www.mediawiki.org/wiki/API:Search
/// https://www.mediawiki.org/wiki/API:Imageinfo
/// https://www.mediawiki.org/wiki/Extension:CommonsMetadata
nonisolated struct MacGalleryImageSearch: Sendable {
  struct Result: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let thumbnailURL: URL
    let imageURL: URL
    let sourceURL: URL
    let author: String
    let license: String
    let licenseURL: URL?

    var attribution: MacPrayerGalleryImageStore.Attribution {
      .init(title: title, author: author, license: license, sourceURL: sourceURL, licenseURL: licenseURL)
    }
  }

  enum Failure: Error, LocalizedError {
    case searchFailed, downloadFailed
    var errorDescription: String? {
      switch self {
      case .searchFailed: String(localized: "macGallery.image.searchFailed", defaultValue: "Image search could not be completed. Try again.", bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      case .downloadFailed: String(localized: "macGallery.image.downloadFailed", defaultValue: "This image could not be downloaded. Try another image.", bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      }
    }
  }

  private let session: URLSession
  private let maximumDownloadBytes: Int
  init(session: URLSession = .shared, maximumDownloadBytes: Int = MacPrayerGalleryImageStore.maximumInputBytes) {
    self.session = session
    self.maximumDownloadBytes = min(MacPrayerGalleryImageStore.maximumInputBytes, max(1, maximumDownloadBytes))
  }

  func search(_ query: String) async throws -> [Result] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    try Task.checkCancellation()
    var url = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
    url.queryItems = [
      "action": "query", "format": "json", "formatversion": "2", "generator": "search",
      "gsrsearch": String(trimmed.prefix(200)) + " filetype:bitmap", "gsrnamespace": "6", "gsrlimit": "12",
      "prop": "imageinfo", "iiprop": "url|mime|extmetadata", "iiurlwidth": "1024",
      "iiextmetadatafilter": "Artist|LicenseShortName|LicenseUrl", "iiextmetadatalanguage": "en"
    ].sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
    let data = try await fetch(url.url!, limit: 2 * 1024 * 1024, hosts: ["commons.wikimedia.org"],
      mimeTypes: ["application/json"], failure: .searchFailed)
    return try Self.results(from: data)
  }

  func download(_ result: Result) async throws -> Data {
    guard Self.safeURL(result.imageURL, hosts: ["upload.wikimedia.org"]) else { throw Failure.downloadFailed }
    return try await fetch(result.imageURL, limit: maximumDownloadBytes,
      hosts: ["upload.wikimedia.org"], mimeTypes: Self.rasterMIMEs, failure: .downloadFailed)
  }

  func thumbnailData(_ result: Result) async throws -> Data {
    try await fetch(result.thumbnailURL, limit: min(maximumDownloadBytes, 4 * 1024 * 1024),
      hosts: ["upload.wikimedia.org"], mimeTypes: Self.rasterMIMEs, failure: .downloadFailed)
  }

  private static let rasterMIMEs: Set<String> = ["image/jpeg", "image/png", "image/gif", "image/webp", "image/tiff", "image/bmp"]

  private func fetch(_ url: URL, limit: Int, hosts: Set<String>, mimeTypes: Set<String>, failure: Failure) async throws -> Data {
    try Task.checkCancellation()
    guard Self.safeURL(url, hosts: hosts) else { throw failure }
    var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 25)
    request.setValue("Prosary/1.0 (https://prosary.app)", forHTTPHeaderField: "User-Agent")
    request.setValue(mimeTypes.sorted().joined(separator: ", "), forHTTPHeaderField: "Accept")
    let (bytes, response) = try await session.bytes(for: request, delegate: RedirectPolicy(hosts: hosts))
    defer { bytes.task.cancel() }
    guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode),
          let finalURL = response.url, Self.safeURL(finalURL, hosts: hosts),
          let mime = response.mimeType?.lowercased(), mimeTypes.contains(mime) else { throw failure }
    guard response.expectedContentLength <= limit else { throw MacPrayerGalleryImageStore.Failure.imageTooLarge }
    var data = Data()
    data.reserveCapacity(min(limit, max(0, Int(response.expectedContentLength))))
    for try await byte in bytes {
      try Task.checkCancellation()
      guard data.count < limit else { throw MacPrayerGalleryImageStore.Failure.imageTooLarge }
      data.append(byte)
    }
    guard !data.isEmpty else { throw failure }
    return data
  }

  static func results(from data: Data) throws -> [Result] {
    guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any], payload["error"] == nil else { throw Failure.searchFailed }
    guard let query = payload["query"] as? [String: Any] else { return [] }
    guard let pages = query["pages"] as? [[String: Any]] else { throw Failure.searchFailed }
    return pages.sorted { ($0["index"] as? Int ?? .max) < ($1["index"] as? Int ?? .max) }.prefix(12).compactMap { page in
      guard let id = page["pageid"] as? Int, id > 0,
            let title = page["title"] as? String,
            let info = (page["imageinfo"] as? [[String: Any]])?.first,
            let mime = info["mime"] as? String, rasterMIMEs.contains(mime),
            let source = parsedURL(info["descriptionurl"] as? String, hosts: ["commons.wikimedia.org"]),
            let thumbnail = parsedURL(info["thumburl"] as? String, hosts: ["upload.wikimedia.org"]) else { return nil }
      let metadata = info["extmetadata"] as? [String: [String: Any]] ?? [:]
      let licenseURL = parsedURL(metadata["LicenseUrl"]?["value"] as? String, hosts: nil)
      return Result(id: id, title: plainText(title.hasPrefix("File:") ? String(title.dropFirst(5)) : title),
        thumbnailURL: thumbnail, imageURL: thumbnail, sourceURL: source,
        author: plainText(metadata["Artist"]?["value"] as? String ?? ""),
        license: plainText(metadata["LicenseShortName"]?["value"] as? String ?? ""), licenseURL: licenseURL)
    }
  }

  private static func parsedURL(_ value: String?, hosts: Set<String>?) -> URL? {
    guard let value, let url = URL(string: value.hasPrefix("//") ? "https:" + value : value), safeURL(url, hosts: hosts) else { return nil }
    return url
  }

  private static func safeURL(_ url: URL, hosts: Set<String>?) -> Bool {
    url.scheme?.lowercased() == "https" && url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
      && url.host != nil && (hosts == nil || hosts!.contains(url.host!.lowercased()))
  }

  /// Metadata is HTML formatted; reduce it to inert plain text without loading a web view.
  static func plainText(_ html: String) -> String {
    var result = String(html.prefix(8192))
      .replacingOccurrences(of: "(?is)<(script|style)\\b[^>]*>.*?</\\1>", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
    let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "ndash": "–", "mdash": "—", "copy": "©"]
    if let pattern = try? NSRegularExpression(pattern: "&(#(?:x[0-9a-fA-F]+|[0-9]+)|[a-z]+);") {
      let matches = pattern.matches(in: result, range: NSRange(result.startIndex..., in: result))
      for match in matches.reversed() {
        guard let whole = Range(match.range, in: result), let keyRange = Range(match.range(at: 1), in: result) else { continue }
        let key = String(result[keyRange])
        let number = key.hasPrefix("#x") ? UInt32(key.dropFirst(2), radix: 16) : key.hasPrefix("#") ? UInt32(key.dropFirst()) : nil
        let replacement = named[key] ?? number.flatMap(UnicodeScalar.init).map(String.init)
        if let replacement { result.replaceSubrange(whole, with: replacement) }
      }
    }
    return String(result.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(2048))
  }

  private final class RedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let hosts: Set<String>
    init(hosts: Set<String>) { self.hosts = hosts }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
      completionHandler(request.url.map { MacGalleryImageSearch.safeURL($0, hosts: hosts) } == true ? request : nil)
    }
  }
}
#endif
