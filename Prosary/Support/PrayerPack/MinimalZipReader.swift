//
//  MinimalZipReader.swift
//  Prosary
//
//  A small, dependency-free reader for the zip archives that back .prosaryprayer bundles (see
//  Shared/ARCHITECTURE.md's "Content bundles" section). Deliberately hand-rolled instead of
//  pulling in a third-party package (e.g. ZIPFoundation): this app has zero external
//  dependencies today, and .prosaryprayer archives are always produced by
//  Shared/tools/make-prosaryprayer.sh — a small, known, non-adversarial writer (plain DEFLATE or
//  store, no encryption, no multi-disk archives, no data descriptors) — so a full general-purpose
//  zip implementation isn't needed. Uses the Compression framework for inflation: despite its
//  name, `COMPRESSION_ZLIB` decodes raw DEFLATE (RFC 1951, no zlib header/trailer), which is
//  exactly what zip's compression method 8 stores.
//

import Compression
import Foundation

enum MinimalZipReaderError: Error {
  case notAZipArchive
  case entryNotFound(String)
  case unsupportedCompressionMethod(UInt16)
  case corruptEntry(String)
}

struct MinimalZipReader {
  private struct Entry {
    let compressionMethod: UInt16
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int
  }

  private let bytes: [UInt8]
  private let entries: [String: Entry]

  init(data: Data) throws {
    self.bytes = [UInt8](data)
    self.entries = try Self.readCentralDirectory(bytes)
  }

  func fileNames() -> [String] {
    Array(entries.keys)
  }

  func contents(of name: String) throws -> Data {
    guard let entry = entries[name] else { throw MinimalZipReaderError.entryNotFound(name) }

    // Local file header: signature(4) version(2) flags(2) method(2) time(2) date(2) crc32(4)
    // compressedSize(4) uncompressedSize(4) nameLen(2) extraLen(2), then the name/extra, then data.
    let header = entry.localHeaderOffset
    guard header + 30 <= bytes.count, readU32(header) == 0x0403_4b50 else {
      throw MinimalZipReaderError.corruptEntry(name)
    }
    let nameLen = Int(readU16(header + 26))
    let extraLen = Int(readU16(header + 28))
    let dataStart = header + 30 + nameLen + extraLen
    guard dataStart + entry.compressedSize <= bytes.count else {
      throw MinimalZipReaderError.corruptEntry(name)
    }
    let compressed = Array(bytes[dataStart..<(dataStart + entry.compressedSize)])

    switch entry.compressionMethod {
    case 0:
      return Data(compressed)
    case 8:
      return try inflate(compressed, uncompressedSize: entry.uncompressedSize)
    default:
      throw MinimalZipReaderError.unsupportedCompressionMethod(entry.compressionMethod)
    }
  }

  // MARK: - Central directory parsing

  private static func readCentralDirectory(_ bytes: [UInt8]) throws -> [String: Entry] {
    guard let eocd = findEndOfCentralDirectory(bytes) else { throw MinimalZipReaderError.notAZipArchive }

    func u16(_ offset: Int) -> UInt16 {
      UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }
    func u32(_ offset: Int) -> Int {
      Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8) | (Int(bytes[offset + 2]) << 16) | (Int(bytes[offset + 3]) << 24)
    }

    let entryCount = Int(u16(eocd + 10))
    var cdOffset = u32(eocd + 16)

    var result: [String: Entry] = [:]
    for _ in 0..<entryCount {
      guard u32(cdOffset) == 0x0201_4b50 else { throw MinimalZipReaderError.notAZipArchive }
      let method = u16(cdOffset + 10)
      let compressedSize = u32(cdOffset + 20)
      let uncompressedSize = u32(cdOffset + 24)
      let nameLen = Int(u16(cdOffset + 28))
      let extraLen = Int(u16(cdOffset + 30))
      let commentLen = Int(u16(cdOffset + 32))
      let localHeaderOffset = u32(cdOffset + 42)

      let nameStart = cdOffset + 46
      let name = String(decoding: bytes[nameStart..<(nameStart + nameLen)], as: UTF8.self)

      if !name.hasSuffix("/") {
        result[name] = Entry(
          compressionMethod: method, compressedSize: compressedSize,
          uncompressedSize: uncompressedSize, localHeaderOffset: localHeaderOffset)
      }

      cdOffset = nameStart + nameLen + extraLen + commentLen
    }
    return result
  }

  /// Scans backward from the end of the file for the End Of Central Directory signature
  /// (`PK\x05\x06`). The EOCD record is fixed-size (22 bytes) plus a variable-length comment (up
  /// to 65535 bytes), so the signature can be anywhere in that trailing window.
  private static func findEndOfCentralDirectory(_ bytes: [UInt8]) -> Int? {
    let signature: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
    let searchWindow = min(bytes.count, 22 + 65535)
    let lowerBound = bytes.count - searchWindow
    var offset = bytes.count - 22
    while offset >= lowerBound {
      if Array(bytes[offset..<(offset + 4)]) == signature {
        return offset
      }
      offset -= 1
    }
    return nil
  }

  private func readU16(_ offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
  }

  private func readU32(_ offset: Int) -> UInt32 {
    UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8) | (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
  }

  private func inflate(_ compressed: [UInt8], uncompressedSize: Int) throws -> Data {
    guard uncompressedSize > 0 else { return Data() }
    var output = [UInt8](repeating: 0, count: uncompressedSize)
    let decodedSize = output.withUnsafeMutableBytes { outPtr -> Int in
      compressed.withUnsafeBytes { inPtr -> Int in
        compression_decode_buffer(
          outPtr.bindMemory(to: UInt8.self).baseAddress!, uncompressedSize,
          inPtr.bindMemory(to: UInt8.self).baseAddress!, compressed.count,
          nil, COMPRESSION_ZLIB)
      }
    }
    guard decodedSize == uncompressedSize else {
      throw MinimalZipReaderError.corruptEntry("inflate produced \(decodedSize) bytes, expected \(uncompressedSize)")
    }
    return Data(output)
  }
}
