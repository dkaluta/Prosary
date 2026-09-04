//
//  MinimalZipReader.swift
//  Prosary
//
//  A small, dependency-free reader for the zip archives that back .prosaryprayer bundles (see
//  Shared/ARCHITECTURE.markdown's "Content bundles" section). It accepts the ordinary single-
//  disk ZIP subset produced by the shared packer (stored or raw DEFLATE entries), and rejects
//  unsupported or ambiguous structures before trusting any archive-provided allocation size.
//

import Compression
import Foundation

enum MinimalZipReaderError: Error {
  case notAZipArchive
  case entryNotFound(String)
  case unsupportedCompressionMethod(UInt16)
  case corruptEntry(String)
}

struct MinimalZipReader: Sendable {
  /// Structural limits match the web authoring surface. More specific image/audio/control-plane
  /// limits are applied by PrayerPackStore at the point where an entry's purpose is known.
  nonisolated static let maximumEntryBytes = 256 * 1024 * 1024
  nonisolated static let maximumExpandedBytes = 512 * 1024 * 1024
  /// Allows the full expanded budget plus local headers and the bounded central directory.
  nonisolated static let maximumArchiveBytes = 576 * 1024 * 1024
  nonisolated static let maximumEntryCount = 4_096
  nonisolated static let maximumCentralDirectoryBytes = 16 * 1024 * 1024

  nonisolated private static let endRecordSize = 22
  nonisolated private static let maximumCommentBytes = 65_535
  nonisolated private static let centralHeaderSize = 46
  nonisolated private static let localHeaderSize = 30
  nonisolated private static let storedMethod: UInt16 = 0
  nonisolated private static let deflatedMethod: UInt16 = 8

  private struct Entry: Sendable {
    let compressionMethod: UInt16
    let crc32: UInt32
    let compressedSize: Int
    let uncompressedSize: Int
    /// Validated while indexing, so entry reads never have to reinterpret an untrusted local
    /// header or accidentally address bytes in the central directory.
    let dataOffset: Int
  }

  /// On-disk packs use `mappedIfSafe`, keeping this file-backed and purgeable. Entry reads return
  /// owned data, while `writeContents` streams media directly to its cache destination.
  private let data: Data
  private let entries: [String: Entry]

  nonisolated init(data: Data) throws {
    guard data.count <= Self.maximumArchiveBytes else {
      throw MinimalZipReaderError.notAZipArchive
    }
    let entries = try data.withUnsafeBytes { rawBuffer in
      try Self.readCentralDirectory(rawBuffer.bindMemory(to: UInt8.self))
    }
    self.data = data
    self.entries = entries
  }

  nonisolated init(contentsOf url: URL) throws {
    try self.init(data: Data(contentsOf: url, options: .mappedIfSafe))
  }

  nonisolated func fileNames() -> [String] {
    Array(entries.keys)
  }

  /// Stable identity for an entry's bytes, obtained without opening or inflating it.
  nonisolated func entryFingerprint(_ name: String) -> String? {
    guard let entry = entries[name] else { return nil }
    return String(format: "%08x", entry.crc32) + "-\(entry.uncompressedSize)"
  }

  /// Checks a selected group before any member is allocated. PrayerPackStore uses this for the
  /// JSON control plane, whose aggregate limit is deliberately much smaller than media limits.
  nonisolated func validateEntrySizes(
    names: [String], maximumEntryBytes: Int, maximumTotalBytes: Int
  ) throws {
    var total = 0
    for name in names {
      guard let entry = entries[name] else { continue }
      guard entry.compressedSize <= maximumEntryBytes,
            entry.uncompressedSize <= maximumEntryBytes else {
        throw MinimalZipReaderError.corruptEntry("entry exceeds its size limit: \(name)")
      }
      guard entry.uncompressedSize <= maximumTotalBytes - total else {
        throw MinimalZipReaderError.corruptEntry("selected entries exceed their aggregate size limit")
      }
      total += entry.uncompressedSize
    }
  }

  nonisolated func contents(
    of name: String, maximumBytes: Int = MinimalZipReader.maximumEntryBytes
  ) throws -> Data {
    guard let entry = entries[name] else { throw MinimalZipReaderError.entryNotFound(name) }
    try validate(entry: entry, named: name, maximumBytes: maximumBytes)
    return try data.withUnsafeBytes { rawBuffer in
      let bytes = rawBuffer.bindMemory(to: UInt8.self)
      guard let baseAddress = bytes.baseAddress else {
        throw MinimalZipReaderError.corruptEntry(name)
      }
      let compressed = UnsafeBufferPointer(
        start: baseAddress.advanced(by: entry.dataOffset), count: entry.compressedSize)
      let result: Data
      switch entry.compressionMethod {
      case Self.storedMethod:
        result = Data(buffer: compressed)
      case Self.deflatedMethod:
        result = try Self.inflate(compressed, uncompressedSize: entry.uncompressedSize)
      default:
        throw MinimalZipReaderError.unsupportedCompressionMethod(entry.compressionMethod)
      }
      guard result.count == entry.uncompressedSize,
            Self.crc32(result) == entry.crc32 else {
        throw MinimalZipReaderError.corruptEntry("entry failed its integrity check: \(name)")
      }
      return result
    }
  }

  /// Writes one entry without retaining a second whole-audio buffer. Stored members are copied
  /// in bounded chunks from the mapped archive; DEFLATE members use Compression's incremental
  /// stream decoder with the same bounded output chunks.
  nonisolated func writeContents(
    of name: String, to output: FileHandle,
    maximumBytes: Int = MinimalZipReader.maximumEntryBytes
  ) throws {
    guard let entry = entries[name] else { throw MinimalZipReaderError.entryNotFound(name) }
    try validate(entry: entry, named: name, maximumBytes: maximumBytes)
    let (written, checksum): (Int, UInt32)
    switch entry.compressionMethod {
    case Self.storedMethod:
      (written, checksum) = try writeStored(entry, to: output)
    case Self.deflatedMethod:
      (written, checksum) = try writeDeflated(entry, named: name, to: output)
    default:
      throw MinimalZipReaderError.unsupportedCompressionMethod(entry.compressionMethod)
    }
    guard written == entry.uncompressedSize, checksum == entry.crc32 else {
      throw MinimalZipReaderError.corruptEntry("entry failed its integrity check: \(name)")
    }
  }

  nonisolated private func writeStored(
    _ entry: Entry, to output: FileHandle
  ) throws -> (written: Int, crc32: UInt32) {
    var checksum: UInt32 = 0xffff_ffff
    var offset = entry.dataOffset
    let end = entry.dataOffset + entry.compressedSize
    let chunkSize = 64 * 1024
    while offset < end {
      let next = min(end, offset + chunkSize)
      let chunk = data.subdata(in: offset..<next)
      checksum = Self.updateCRC32(checksum, with: chunk)
      try output.write(contentsOf: chunk)
      offset = next
    }
    return (entry.compressedSize, checksum ^ 0xffff_ffff)
  }

  nonisolated private func writeDeflated(
    _ entry: Entry, named name: String, to output: FileHandle
  ) throws -> (written: Int, crc32: UInt32) {
    try data.withUnsafeBytes { rawBuffer in
      let sourceBytes = rawBuffer.bindMemory(to: UInt8.self)
      guard let archiveBase = sourceBytes.baseAddress else {
        throw MinimalZipReaderError.corruptEntry(name)
      }
      var destination = [UInt8](repeating: 0, count: 64 * 1024)
      return try destination.withUnsafeMutableBufferPointer { destinationBuffer in
        guard let destinationBase = destinationBuffer.baseAddress else {
          throw MinimalZipReaderError.corruptEntry(name)
        }
        var stream = compression_stream(
          dst_ptr: destinationBase,
          dst_size: destinationBuffer.count,
          src_ptr: archiveBase.advanced(by: entry.dataOffset),
          src_size: entry.compressedSize,
          state: nil)
        guard compression_stream_init(
          &stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) != COMPRESSION_STATUS_ERROR else {
          throw MinimalZipReaderError.corruptEntry("could not initialize DEFLATE decoder")
        }
        defer { compression_stream_destroy(&stream) }
        stream.src_ptr = archiveBase.advanced(by: entry.dataOffset)
        stream.src_size = entry.compressedSize

        var written = 0
        var checksum: UInt32 = 0xffff_ffff
        while true {
          stream.dst_ptr = destinationBase
          stream.dst_size = destinationBuffer.count
          let sourceBefore = stream.src_size
          let status = compression_stream_process(
            &stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
          let produced = destinationBuffer.count - stream.dst_size
          guard produced <= entry.uncompressedSize - written else {
            throw MinimalZipReaderError.corruptEntry(
              "entry exceeds its declared uncompressed size: \(name)")
          }
          if produced > 0 {
            let chunk = Data(bytes: destinationBase, count: produced)
            checksum = Self.updateCRC32(checksum, with: chunk)
            try output.write(contentsOf: chunk)
            written += produced
          }
          if status == COMPRESSION_STATUS_END {
            guard stream.src_size == 0 else {
              throw MinimalZipReaderError.corruptEntry("entry contains trailing DEFLATE data: \(name)")
            }
            return (written, checksum ^ 0xffff_ffff)
          }
          if status == COMPRESSION_STATUS_ERROR
            || (produced == 0 && stream.src_size == sourceBefore) {
            throw MinimalZipReaderError.corruptEntry("invalid or truncated DEFLATE entry: \(name)")
          }
        }
      }
    }
  }

  // MARK: - Central-directory validation

  nonisolated private static func readCentralDirectory(
    _ bytes: UnsafeBufferPointer<UInt8>
  ) throws -> [String: Entry] {
    guard let eocd = findEndOfCentralDirectory(bytes) else {
      throw MinimalZipReaderError.notAZipArchive
    }
    let disk = readU16(eocd + 4, from: bytes)
    let centralDisk = readU16(eocd + 6, from: bytes)
    let entriesOnDisk = readU16(eocd + 8, from: bytes)
    let entryCountField = readU16(eocd + 10, from: bytes)
    let centralSizeField = readU32(eocd + 12, from: bytes)
    let centralOffsetField = readU32(eocd + 16, from: bytes)
    guard disk == 0, centralDisk == 0, entriesOnDisk == entryCountField,
          entryCountField != 0xffff,
          centralSizeField != 0xffff_ffff,
          centralOffsetField != 0xffff_ffff else {
      throw MinimalZipReaderError.notAZipArchive
    }

    let entryCount = Int(entryCountField)
    let centralSize = Int(centralSizeField)
    let centralOffset = Int(centralOffsetField)
    guard entryCount <= maximumEntryCount,
          centralSize <= maximumCentralDirectoryBytes,
          isValidRange(offset: centralOffset, length: centralSize, limit: eocd),
          centralOffset + centralSize == eocd else {
      throw MinimalZipReaderError.notAZipArchive
    }

    let centralEnd = centralOffset + centralSize
    var cursor = centralOffset
    var totalUncompressed = 0
    var result: [String: Entry] = [:]
    var seenNames = Set<String>()
    var occupiedRanges: [(start: Int, end: Int)] = []

    for _ in 0..<entryCount {
      guard isValidRange(offset: cursor, length: centralHeaderSize, limit: centralEnd),
            readU32(cursor, from: bytes) == 0x0201_4b50 else {
        throw MinimalZipReaderError.notAZipArchive
      }
      let flags = readU16(cursor + 8, from: bytes)
      let method = readU16(cursor + 10, from: bytes)
      let crc = readU32(cursor + 16, from: bytes)
      let compressedField = readU32(cursor + 20, from: bytes)
      let uncompressedField = readU32(cursor + 24, from: bytes)
      let nameLength = Int(readU16(cursor + 28, from: bytes))
      let extraLength = Int(readU16(cursor + 30, from: bytes))
      let commentLength = Int(readU16(cursor + 32, from: bytes))
      let startDisk = readU16(cursor + 34, from: bytes)
      let localOffsetField = readU32(cursor + 42, from: bytes)
      guard startDisk == 0, compressedField != 0xffff_ffff,
            uncompressedField != 0xffff_ffff, localOffsetField != 0xffff_ffff else {
        throw MinimalZipReaderError.notAZipArchive
      }
      guard method == storedMethod || method == deflatedMethod else {
        throw MinimalZipReaderError.unsupportedCompressionMethod(method)
      }
      let allowedFlags: UInt16 = 0x0800 | 0x0008 | (method == deflatedMethod ? 0x0006 : 0)
      guard flags & ~allowedFlags == 0 else {
        throw MinimalZipReaderError.corruptEntry("unsupported ZIP entry flags")
      }

      let compressedSize = Int(compressedField)
      let uncompressedSize = Int(uncompressedField)
      guard method != storedMethod || compressedSize == uncompressedSize,
            compressedSize <= maximumEntryBytes,
            uncompressedSize <= maximumEntryBytes,
            uncompressedSize <= maximumExpandedBytes - totalUncompressed else {
        throw MinimalZipReaderError.corruptEntry("ZIP entry exceeds structural size limits")
      }
      totalUncompressed += uncompressedSize

      let recordLength = centralHeaderSize + nameLength + extraLength + commentLength
      guard isValidRange(offset: cursor, length: recordLength, limit: centralEnd) else {
        throw MinimalZipReaderError.notAZipArchive
      }
      let nameStart = cursor + centralHeaderSize
      let nameBytes = Array(bytes[nameStart..<(nameStart + nameLength)])
      guard let name = String(bytes: nameBytes, encoding: .utf8),
            isValidEntryName(name), seenNames.insert(name).inserted else {
        throw MinimalZipReaderError.corruptEntry("invalid or duplicate ZIP entry name")
      }

      let localOffset = Int(localOffsetField)
      guard isValidRange(offset: localOffset, length: localHeaderSize, limit: centralOffset),
            readU32(localOffset, from: bytes) == 0x0403_4b50 else {
        throw MinimalZipReaderError.corruptEntry(name)
      }
      let localFlags = readU16(localOffset + 6, from: bytes)
      let localMethod = readU16(localOffset + 8, from: bytes)
      let localCRC = readU32(localOffset + 14, from: bytes)
      let localCompressed = readU32(localOffset + 18, from: bytes)
      let localUncompressed = readU32(localOffset + 22, from: bytes)
      let localNameLength = Int(readU16(localOffset + 26, from: bytes))
      let localExtraLength = Int(readU16(localOffset + 28, from: bytes))
      let localNameStart = localOffset + localHeaderSize
      guard isValidRange(
        offset: localNameStart, length: localNameLength + localExtraLength, limit: centralOffset
      ), localFlags == flags, localMethod == method,
        Array(bytes[localNameStart..<(localNameStart + localNameLength)]) == nameBytes else {
        throw MinimalZipReaderError.corruptEntry("local and central ZIP headers disagree: \(name)")
      }

      let usesDescriptor = flags & 0x0008 != 0
      let localValuesAreEmpty = localCRC == 0 && localCompressed == 0 && localUncompressed == 0
      let localValuesMatch = localCRC == crc && localCompressed == compressedField
        && localUncompressed == uncompressedField
      guard usesDescriptor ? (localValuesAreEmpty || localValuesMatch) : localValuesMatch else {
        throw MinimalZipReaderError.corruptEntry("local and central ZIP sizes disagree: \(name)")
      }

      let dataOffset = localNameStart + localNameLength + localExtraLength
      guard isValidRange(offset: dataOffset, length: compressedSize, limit: centralOffset) else {
        throw MinimalZipReaderError.corruptEntry("entry extends beyond ZIP data area: \(name)")
      }
      var entryEnd = dataOffset + compressedSize
      if usesDescriptor {
        entryEnd = try validatedDescriptorEnd(
          at: entryEnd, limit: centralOffset, bytes: bytes,
          crc: crc, compressedSize: compressedField, uncompressedSize: uncompressedField,
          name: name)
      }
      occupiedRanges.append((localOffset, entryEnd))

      if name.hasSuffix("/") {
        guard compressedSize == 0, uncompressedSize == 0 else {
          throw MinimalZipReaderError.corruptEntry("directory entry contains a payload: \(name)")
        }
      } else {
        result[name] = Entry(
          compressionMethod: method,
          crc32: crc,
          compressedSize: compressedSize,
          uncompressedSize: uncompressedSize,
          dataOffset: dataOffset)
      }
      cursor += recordLength
    }

    guard cursor == centralEnd else { throw MinimalZipReaderError.notAZipArchive }
    occupiedRanges.sort { $0.start < $1.start }
    if occupiedRanges.count > 1 {
      for index in 1..<occupiedRanges.count where
        occupiedRanges[index].start < occupiedRanges[index - 1].end {
        throw MinimalZipReaderError.corruptEntry("ZIP entries overlap")
      }
    }
    return result
  }

  nonisolated private static func validatedDescriptorEnd(
    at offset: Int, limit: Int, bytes: UnsafeBufferPointer<UInt8>,
    crc: UInt32, compressedSize: UInt32, uncompressedSize: UInt32, name: String
  ) throws -> Int {
    func matches(at start: Int) -> Bool {
      isValidRange(offset: start, length: 12, limit: limit)
        && readU32(start, from: bytes) == crc
        && readU32(start + 4, from: bytes) == compressedSize
        && readU32(start + 8, from: bytes) == uncompressedSize
    }
    if isValidRange(offset: offset, length: 16, limit: limit),
       readU32(offset, from: bytes) == 0x0807_4b50, matches(at: offset + 4) {
      return offset + 16
    }
    if matches(at: offset) { return offset + 12 }
    throw MinimalZipReaderError.corruptEntry("ZIP data descriptor disagrees: \(name)")
  }

  /// The EOCD is fixed-size plus its declared comment. Requiring it to consume the file prevents
  /// a signature embedded in trailing attacker-controlled bytes from being mistaken for it.
  nonisolated private static func findEndOfCentralDirectory(
    _ bytes: UnsafeBufferPointer<UInt8>
  ) -> Int? {
    guard bytes.count >= endRecordSize else { return nil }
    let lowerBound = max(0, bytes.count - endRecordSize - maximumCommentBytes)
    var offset = bytes.count - endRecordSize
    while offset >= lowerBound {
      if readU32(offset, from: bytes) == 0x0605_4b50,
         offset + endRecordSize + Int(readU16(offset + 20, from: bytes)) == bytes.count {
        return offset
      }
      offset -= 1
    }
    return nil
  }

  nonisolated private static func isValidEntryName(_ name: String) -> Bool {
    guard !name.isEmpty, !name.hasPrefix("/"), !name.contains("\\"), !name.contains("\0") else {
      return false
    }
    let components = name.split(separator: "/", omittingEmptySubsequences: false)
    for (index, component) in components.enumerated() {
      if component.isEmpty {
        if index != components.count - 1 { return false }
      } else if component == "." || component == ".." {
        return false
      }
    }
    return true
  }

  nonisolated private static func isValidRange(offset: Int, length: Int, limit: Int) -> Bool {
    offset >= 0 && length >= 0 && offset <= limit && length <= limit - offset
  }

  nonisolated private func validate(
    entry: Entry, named name: String, maximumBytes: Int
  ) throws {
    guard maximumBytes >= 0,
          entry.compressedSize <= maximumBytes,
          entry.uncompressedSize <= maximumBytes else {
      throw MinimalZipReaderError.corruptEntry("entry exceeds its size limit: \(name)")
    }
  }

  nonisolated private static func readU16(
    _ offset: Int, from bytes: UnsafeBufferPointer<UInt8>
  ) -> UInt16 {
    UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
  }

  nonisolated private static func readU32(
    _ offset: Int, from bytes: UnsafeBufferPointer<UInt8>
  ) -> UInt32 {
    UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8)
      | (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
  }

  nonisolated private static func inflate(
    _ compressed: UnsafeBufferPointer<UInt8>, uncompressedSize: Int
  ) throws -> Data {
    guard uncompressedSize > 0 else {
      guard compressed.isEmpty else {
        throw MinimalZipReaderError.corruptEntry("empty DEFLATE entry contains data")
      }
      return Data()
    }
    guard let compressedBaseAddress = compressed.baseAddress else {
      throw MinimalZipReaderError.corruptEntry("empty compressed entry")
    }
    var output = [UInt8](repeating: 0, count: uncompressedSize)
    let decodedSize = output.withUnsafeMutableBytes { outPtr -> Int in
      compression_decode_buffer(
        outPtr.bindMemory(to: UInt8.self).baseAddress!, uncompressedSize,
        compressedBaseAddress, compressed.count, nil, COMPRESSION_ZLIB)
    }
    guard decodedSize == uncompressedSize else {
      throw MinimalZipReaderError.corruptEntry(
        "inflate produced \(decodedSize) bytes, expected \(uncompressedSize)")
    }
    return Data(output)
  }

  nonisolated private static let crcTable: [UInt32] = (0..<256).map { value in
    var crc = UInt32(value)
    for _ in 0..<8 {
      crc = crc & 1 == 0 ? crc >> 1 : 0xedb8_8320 ^ (crc >> 1)
    }
    return crc
  }

  nonisolated private static func updateCRC32(_ startingCRC: UInt32, with data: Data) -> UInt32 {
    var crc = startingCRC
    for byte in data {
      crc = crcTable[Int((crc ^ UInt32(byte)) & 0xff)] ^ (crc >> 8)
    }
    return crc
  }

  nonisolated private static func crc32(_ data: Data) -> UInt32 {
    updateCRC32(0xffff_ffff, with: data) ^ 0xffff_ffff
  }
}
