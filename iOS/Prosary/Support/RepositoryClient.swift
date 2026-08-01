//
//  RepositoryClient.swift
//  Prosary
//
//  Fetches the prayers.prosary.app catalog (the versioned /index.json contract — see
//  Shared/ARCHITECTURE.md § Content bundles) and downloads bundles through the same-origin
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
}

enum RepositoryClientError: LocalizedError {
  case unsupportedCatalog
  case badResponse

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
    let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("index.json"))
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw RepositoryClientError.badResponse }
    return try parseCatalog(data)
  }

  static func downloadBundle(_ bundle: RepositoryBundle) async throws -> Data {
    guard let url = URL(string: bundle.file, relativeTo: baseURL) else {
      throw RepositoryClientError.badResponse
    }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw RepositoryClientError.badResponse }
    return data
  }
}
