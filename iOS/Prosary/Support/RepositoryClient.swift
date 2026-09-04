//
//  RepositoryClient.swift
//  Prosary
//
//  Fetches the prayers.prosary.app catalog (the versioned /index.json contract — see
//  Shared/ARCHITECTURE.markdown § Content bundles) and downloads bundles through the same-origin
//  /api/download/<id> path, so server-side download counting keeps working and the storage
//  behind it can change without breaking installed apps.
//

import Foundation

/// One catalog entry. `id` is always `repo.<username>.<name>` — the prefix the Favorites
/// rows key their "Repository" tag on.
struct RepositoryBundle: Decodable, Identifiable, Hashable {
  let id: String
  let name: String
  let author: String
  let languages: [String]
  let tags: [String]
  let description: String
  /// Same-origin download path ("/api/download/<id>").
  let file: String
  /// Server-side last-modified stamp; optional so older catalogs (pre-0.6) still parse.
  /// The browser keys its "Update" badge on this changing after install.
  let updatedAt: String?
}

enum RepositoryClientError: LocalizedError {
  case unsupportedCatalog
  case badResponse
  case invalidBundle

  var errorDescription: String? {
    switch self {
    case .unsupportedCatalog:
      return String(
        localized: "repository.error.unsupportedCatalog",
        defaultValue: "The repository uses a newer catalog format — update Prosary to browse it.")
    case .badResponse:
      return String(
        localized: "repository.error.badResponse",
        defaultValue: "The repository could not be reached.")
    case .invalidBundle:
      return String(
        localized: "packInstall.error.unreadable",
        defaultValue: "This file is not a readable .prosaryprayer bundle.")
    }
  }
}

enum RepositoryClient {
  static let baseURL = URL(string: "https://prayers.prosary.app")!

  /// Split out from the fetch so tests can pin the contract without a network.
  static func parseCatalog(_ data: Data) throws -> [RepositoryBundle] {
    struct Catalog: Decodable {
      let prosaryRepository: Int
      let bundles: [RepositoryBundle]
    }
    let catalog = try JSONDecoder().decode(Catalog.self, from: data)
    guard catalog.prosaryRepository == 1 else { throw RepositoryClientError.unsupportedCatalog }
    return catalog.bundles
  }

  static func fetchCatalog() async throws -> [RepositoryBundle] {
    let (data, response) = try await URLSession.shared.data(
      for: URLRequest(url: baseURL.appendingPathComponent("index.json"), timeoutInterval: 15))
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw RepositoryClientError.badResponse }
    return try parseCatalog(data)
  }

  static func downloadBundle(_ bundle: RepositoryBundle) async throws -> Data {
    guard let url = URL(string: bundle.file, relativeTo: baseURL) else {
      throw RepositoryClientError.badResponse
    }
    // A download task writes to a temporary file instead of accumulating an untrusted response
    // in RAM. Only after both the advertised and actual file sizes pass the native import limit
    // do we create the Data value consumed by PrayerPackStore.
    let (temporaryURL, response) = try await URLSession.shared.download(
      for: URLRequest(url: url, timeoutInterval: 30))
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw RepositoryClientError.badResponse }
    if response.expectedContentLength > Int64(MinimalZipReader.maximumArchiveBytes) {
      throw RepositoryClientError.invalidBundle
    }
    let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
    guard let fileSize = values.fileSize,
          fileSize <= MinimalZipReader.maximumArchiveBytes else {
      throw RepositoryClientError.invalidBundle
    }
    let data = try Data(contentsOf: temporaryURL, options: .mappedIfSafe)
    guard data.count <= MinimalZipReader.maximumArchiveBytes else {
      throw RepositoryClientError.invalidBundle
    }
    return data
  }
}

/// Which catalog `updatedAt` each repository bundle was installed at — the whole "update
/// available" feature: a bundle shows Update when the live catalog's stamp differs from the
/// one recorded at install. File-imported bundles have no record and never nag.
enum RepositoryInstallStamps {
  private static let key = "repoInstalledUpdatedAt"

  static func stamp(for bundleId: String) -> String? {
    (UserDefaults.standard.dictionary(forKey: key) as? [String: String])?[bundleId]
  }

  static func record(_ updatedAt: String?, for bundleId: String) {
    var stamps = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    stamps[bundleId] = updatedAt
    UserDefaults.standard.set(stamps, forKey: key)
  }

  static func hasUpdate(bundle: RepositoryBundle, isInstalled: Bool) -> Bool {
    guard isInstalled, let live = bundle.updatedAt, let installed = stamp(for: bundle.id) else {
      return false
    }
    return live != installed
  }
}
