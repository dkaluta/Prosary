#if os(macOS)
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Prosary

@MainActor
final class MacGalleryImageSearchTests: XCTestCase {
  func testPreviewDownsamplesBeforeDisplayAndReusesItsBoundedCache() async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let context = try XCTUnwrap(CGContext(data: nil, width: 1200, height: 600, bitsPerComponent: 8,
      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    context.setFillColor(CGColor(gray: 0.4, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 1200, height: 600))
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    let png = data as Data
    GallerySearchURLProtocol.configure { _ in .init(data: png, mime: "image/png") }
    let result = try XCTUnwrap(MacGalleryImageSearch.results(from: fixtureData()).first)
    let loader = MacGalleryImagePreviewLoader(service: MacGalleryImageSearch(session: session))
    let first = try await loader.image(for: result)
    XCTAssertEqual(first.size, NSSize(width: 256, height: 128))
    let second = try await loader.image(for: result)
    XCTAssertTrue(first === second)
    XCTAssertEqual(GallerySearchURLProtocol.requests.count, 1)
  }

  func testSearchUsesOneFileQueryAndPreservesSafeAuthorAndLicenseMetadata() async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let data = try fixtureData()
    GallerySearchURLProtocol.configure { _ in .init(data: data, mime: "application/json") }
    let results = try await MacGalleryImageSearch(session: session).search("Mary & Joseph")
    XCTAssertEqual(results.map(\.id), [12, 11])
    XCTAssertEqual(results.first?.author, "Alice & Bob")
    XCTAssertEqual(results.first?.license, "CC BY-SA 4.0")
    XCTAssertEqual(results.first?.licenseURL?.absoluteString, "https://creativecommons.org/licenses/by-sa/4.0/")
    XCTAssertEqual(results.first?.attribution.sourceURL, results.first?.sourceURL)
    XCTAssertEqual(results.first?.imageURL, results.first?.thumbnailURL, "Use the API's bounded-size raster preview")
    let requests = GallerySearchURLProtocol.requests
    XCTAssertEqual(requests.count, 1)
    let request = try XCTUnwrap(requests.first)
    let query = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
    let parameters = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
    XCTAssertEqual(parameters["gsrnamespace"], "6")
    XCTAssertEqual(parameters["gsrsearch"], "Mary & Joseph filetype:bitmap")
    XCTAssertEqual(parameters["gsrlimit"], "12")
    XCTAssertTrue(request.value(forHTTPHeaderField: "User-Agent")?.contains("Prosary/") == true)
    let empty = try await MacGalleryImageSearch(session: session).search("  ")
    XCTAssertEqual(empty, [])
    XCTAssertEqual(GallerySearchURLProtocol.requests.count, 1)
  }

  func testMalformedResponsesAndUnsafeOrNonRasterResultsFailClosed() throws {
    let unsafe = try fixtureData(extraPages: [
      page(id: 30, imageURL: "http://upload.wikimedia.org/image.jpg"),
      page(id: 31, imageURL: "https://example.com/image.jpg"),
      page(id: 32, imageURL: "https://upload.wikimedia.org@localhost/image.jpg"),
      page(id: 33, imageURL: "https://upload.wikimedia.org/image.svg", mime: "image/svg+xml")
    ])
    XCTAssertEqual(try MacGalleryImageSearch.results(from: unsafe).map(\.id), [12, 11])
    XCTAssertThrowsError(try MacGalleryImageSearch.results(from: Data("{\"error\":{\"code\":\"ratelimited\"}}".utf8)))
    XCTAssertThrowsError(try MacGalleryImageSearch.results(from: Data("[]".utf8)))
    XCTAssertEqual(MacGalleryImageSearch.plainText("<script>ignored()</script><a href='https://invalid/'>A&#x20;B</a>&nbsp;&copy;"), "A B ©")
  }

  func testDownloadChecksStatusMIMEAndBothDeclaredAndStreamedSize() async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let result = try XCTUnwrap(MacGalleryImageSearch.results(from: fixtureData()).first)
    let service = MacGalleryImageSearch(session: session, maximumDownloadBytes: 32)
    let valid = Data([0xff, 0xd8, 0xff, 1, 2, 3])
    GallerySearchURLProtocol.configure { _ in .init(data: valid, mime: "image/jpeg") }
    let downloaded = try await service.download(result)
    XCTAssertEqual(downloaded, valid)
    for payload in [
      GallerySearchURLProtocol.Payload(data: valid, mime: "image/jpeg", status: 404),
      .init(data: valid, mime: "text/html"),
      .init(data: valid, mime: "image/jpeg", declaredLength: 33),
      .init(data: Data(count: 33), mime: "image/jpeg")
    ] {
      GallerySearchURLProtocol.configure { _ in payload }
      do { _ = try await service.download(result); XCTFail("Invalid response accepted") }
      catch { }
    }
    let outside = MacGalleryImageSearch.Result(id: 1, title: "Outside", thumbnailURL: result.thumbnailURL,
      imageURL: URL(string: "https://example.com/image.jpg")!, sourceURL: result.sourceURL, author: "", license: "", licenseURL: nil)
    GallerySearchURLProtocol.configure { _ in XCTFail("Unsafe URL must not be requested"); return .init(data: valid, mime: "image/jpeg") }
    do { _ = try await service.download(outside); XCTFail("External download accepted") } catch { }
    XCTAssertTrue(GallerySearchURLProtocol.requests.isEmpty)
  }

  func testCancellationStopsAnInFlightSearch() async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let started = expectation(description: "Search request started")
    GallerySearchURLProtocol.configure { _ in
      started.fulfill()
      return .init(data: Data(), mime: "application/json", neverFinish: true)
    }
    let task = Task { try await MacGalleryImageSearch(session: session).search("Angelus") }
    await fulfillment(of: [started], timeout: 5)
    task.cancel()
    do { _ = try await task.value; XCTFail("Cancelled search succeeded") }
    catch { XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled) }
  }

  private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GallerySearchURLProtocol.self]
    return URLSession(configuration: configuration)
  }

  private func fixtureData(extraPages: [[String: Any]] = []) throws -> Data {
    var first = page(id: 12)
    first["index"] = 1
    var second = page(id: 11)
    second["index"] = 2
    return try JSONSerialization.data(withJSONObject: ["query": ["pages": [second, first] + extraPages]])
  }

  private func page(id: Int, imageURL: String = "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Painting.jpg/1024px-Painting.jpg", mime: String = "image/jpeg") -> [String: Any] {
    ["pageid": id, "title": "File:Painting.jpg", "imageinfo": [[
      "mime": mime, "thumburl": imageURL, "descriptionurl": "https://commons.wikimedia.org/wiki/File:Painting.jpg",
      "extmetadata": ["Artist": ["value": "<a href='https://invalid/'>Alice &amp; Bob</a>"],
        "LicenseShortName": ["value": "CC BY-SA 4.0"],
        "LicenseUrl": ["value": "//creativecommons.org/licenses/by-sa/4.0/"]]
    ]]]
  }
}

nonisolated private final class GallerySearchURLProtocol: URLProtocol, @unchecked Sendable {
  struct Payload: Sendable {
    let data: Data
    let mime: String
    var status = 200
    var declaredLength: Int? = nil
    var neverFinish = false
  }
  private final class State: @unchecked Sendable {
    let lock = NSLock()
    var handler: (@Sendable (URLRequest) -> Payload)?
    var requests: [URLRequest] = []
  }
  private static let state = State()
  static var requests: [URLRequest] { state.lock.withLock { state.requests } }
  static func configure(_ handler: @escaping @Sendable (URLRequest) -> Payload) {
    state.lock.withLock { state.handler = handler; state.requests = [] }
  }
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let handler = Self.state.lock.withLock { Self.state.requests.append(request); return Self.state.handler }
    guard let payload = handler?(request), let url = request.url else { return }
    if payload.neverFinish { return }
    var headers = ["Content-Type": payload.mime]
    if let length = payload.declaredLength { headers["Content-Length"] = String(length) }
    let response = HTTPURLResponse(url: url, statusCode: payload.status, httpVersion: "HTTP/1.1", headerFields: headers)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: payload.data)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() { }
}
#endif
