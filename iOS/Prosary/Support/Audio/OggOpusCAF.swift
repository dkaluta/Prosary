//
//  OggOpusCAF.swift
//  Prosary
//
//  Repackages an Ogg Opus recording (RFC 7845 — the .prosaryprayer interchange format) into a
//  Core Audio Format file, losslessly: the Opus packets are copied as-is, only the container
//  changes. Needed because the deployment floor (iOS 17/macOS 14) decodes the Opus *codec* but
//  demuxes it only from MP4/CAF — a bare .opus file is "Cannot Open" there, while CAF-wrapped
//  Opus plays everywhere Core Audio does. Newer OSes open .opus directly, so the player tries
//  that first and only falls back to this (see AudioPlaybackController).
//

import Foundation

enum OggOpusError: Error, Equatable {
  case notOggOpus
  case truncatedPage(offset: Int)
  case malformedPacket
}

/// A demuxed Ogg Opus stream: the identification-header facts CAF needs, plus the raw audio
/// packets. `frameCounts[i]` is the 48 kHz sample count packet `i` decodes to (from its TOC
/// byte); `lastGranule` is the final page's granule position (total 48 kHz samples including
/// the encoder's `preSkip` priming, which players discard).
struct OggOpusStream {
  let channels: Int
  let preSkip: Int
  let packets: [Data]
  let frameCounts: [Int]
  let lastGranule: Int64

  var totalFrames: Int { frameCounts.reduce(0, +) }
  /// Playable duration in seconds (what a progress bar should show).
  var duration: Double {
    Double(max(Int64(0), (lastGranule > 0 ? lastGranule : Int64(totalFrames)) - Int64(preSkip))) / 48000
  }
}

enum OggOpusCAF {
  // MARK: Ogg demuxing

  static func demux(_ data: Data) throws -> OggOpusStream {
    let bytes = [UInt8](data)
    var offset = 0
    var serial: UInt32?
    var packets: [Data] = []
    var partial = Data()
    var lastGranule: Int64 = 0

    while offset + 27 <= bytes.count {
      guard bytes[offset] == 0x4F, bytes[offset + 1] == 0x67,
            bytes[offset + 2] == 0x67, bytes[offset + 3] == 0x53,
            bytes[offset + 4] == 0 else { throw OggOpusError.truncatedPage(offset: offset) }
      let headerType = bytes[offset + 5]
      var granule: Int64 = 0
      for i in (0..<8).reversed() { granule = (granule << 8) | Int64(bytes[offset + 6 + i]) }
      var pageSerial: UInt32 = 0
      for i in (0..<4).reversed() { pageSerial = (pageSerial << 8) | UInt32(bytes[offset + 14 + i]) }
      let segmentCount = Int(bytes[offset + 26])
      guard offset + 27 + segmentCount <= bytes.count else { throw OggOpusError.truncatedPage(offset: offset) }
      let lacing = bytes[(offset + 27)..<(offset + 27 + segmentCount)]
      var payloadOffset = offset + 27 + segmentCount
      let pageEnd = payloadOffset + lacing.reduce(0) { $0 + Int($1) }
      guard pageEnd <= bytes.count else { throw OggOpusError.truncatedPage(offset: offset) }

      // Lock onto the first stream's serial; a multiplexed second stream (which the format
      // validator forbids anyway) is skipped rather than corrupting packet assembly.
      if serial == nil { serial = pageSerial }
      guard pageSerial == serial else { offset = pageEnd; continue }

      // A fresh page never continues a packet unless it says so — a dangling partial from a
      // lost continuation would otherwise silently splice into the wrong packet.
      if headerType & 0x01 == 0 { partial.removeAll() }

      for segment in lacing {
        partial.append(contentsOf: bytes[payloadOffset..<(payloadOffset + Int(segment))])
        payloadOffset += Int(segment)
        if segment < 255 {
          packets.append(partial)
          partial.removeAll()
        }
      }
      // granule == -1 marks a page where no packet ends; anything else on this stream is the
      // running total of decodable samples through the last packet completed on the page.
      if granule >= 0 { lastGranule = granule }
      offset = pageEnd
    }

    guard packets.count >= 2, packets[0].count >= 19,
          packets[0].prefix(8).elementsEqual("OpusHead".utf8) else { throw OggOpusError.notOggOpus }
    let head = [UInt8](packets[0])
    let channels = Int(head[9])
    let preSkip = Int(head[10]) | (Int(head[11]) << 8)

    // packets[1] is OpusTags; everything after is audio.
    let audioPackets = Array(packets.dropFirst(2))
    let frameCounts = try audioPackets.map { try samplesPerPacket($0) }
    return OggOpusStream(channels: channels, preSkip: preSkip, packets: audioPackets,
                         frameCounts: frameCounts, lastGranule: lastGranule)
  }

  /// 48 kHz samples one Opus packet decodes to, from its TOC byte (RFC 6716 §3.1): the config
  /// number picks the per-frame duration, the code (and for code 3 the count byte) the number
  /// of frames.
  static func samplesPerPacket(_ packet: Data) throws -> Int {
    guard let toc = packet.first else { throw OggOpusError.malformedPacket }
    let config = Int(toc >> 3)
    let samplesPerFrame: Int
    switch config {
    case 0..<12: samplesPerFrame = [480, 960, 1920, 2880][config % 4] // SILK 10/20/40/60 ms
    case 12..<16: samplesPerFrame = [480, 960][config % 2]            // Hybrid 10/20 ms
    default: samplesPerFrame = [120, 240, 480, 960][config % 4]       // CELT 2.5/5/10/20 ms
    }
    let frames: Int
    switch toc & 0x3 {
    case 0: frames = 1
    case 1, 2: frames = 2
    default:
      guard packet.count >= 2 else { throw OggOpusError.malformedPacket }
      frames = Int(packet[packet.startIndex + 1] & 0x3F)
      guard frames > 0 else { throw OggOpusError.malformedPacket }
    }
    return frames * samplesPerFrame
  }

  // MARK: CAF muxing

  /// The CAF equivalent of the given Ogg Opus data — same packets, Core Audio's container
  /// (all fields big-endian per the CAF spec).
  static func repackage(_ oggOpus: Data) throws -> Data {
    let stream = try demux(oggOpus)
    var caf = Data()
    caf.append(contentsOf: "caff".utf8)
    appendBE(UInt16(1), to: &caf) // file version
    appendBE(UInt16(0), to: &caf) // file flags

    // desc: variable-size packets (0 bytes per packet) — frames per packet is constant when
    // every packet agrees (the usual fixed-20 ms encode), else 0 with per-packet counts in pakt.
    let uniformFrames = Set(stream.frameCounts).count == 1 ? stream.frameCounts[0] : 0
    caf.append(contentsOf: "desc".utf8)
    appendBE(Int64(32), to: &caf)
    appendBE(Double(48000).bitPattern, to: &caf)
    caf.append(contentsOf: "opus".utf8)
    appendBE(UInt32(0), to: &caf)                  // format flags
    appendBE(UInt32(0), to: &caf)                  // bytes per packet (variable)
    appendBE(UInt32(uniformFrames), to: &caf)      // frames per packet
    appendBE(UInt32(stream.channels), to: &caf)
    appendBE(UInt32(0), to: &caf)                  // bits per channel (compressed)

    // pakt: byte size per packet always (bytes are variable), frame count per packet only when
    // frames vary too. Sizes use the spec's big-endian 7-bit variable-length encoding.
    var table = Data()
    for (packet, frames) in zip(stream.packets, stream.frameCounts) {
      appendVLQ(packet.count, to: &table)
      if uniformFrames == 0 { appendVLQ(frames, to: &table) }
    }
    let totalFrames = Int64(stream.totalFrames)
    let validFrames = max(Int64(0),
      (stream.lastGranule > 0 ? stream.lastGranule : totalFrames) - Int64(stream.preSkip))
    caf.append(contentsOf: "pakt".utf8)
    appendBE(Int64(24 + table.count), to: &caf)
    appendBE(Int64(stream.packets.count), to: &caf)
    appendBE(validFrames, to: &caf)
    appendBE(Int32(stream.preSkip), to: &caf)                              // priming frames
    appendBE(Int32(max(Int64(0), totalFrames - Int64(stream.preSkip) - validFrames)), to: &caf)
    caf.append(table)

    let payload = stream.packets.reduce(into: Data()) { $0.append($1) }
    caf.append(contentsOf: "data".utf8)
    appendBE(Int64(4 + payload.count), to: &caf)
    appendBE(UInt32(0), to: &caf) // edit count
    caf.append(payload)
    return caf
  }

  private static func appendBE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
  }

  private static func appendVLQ(_ value: Int, to data: inout Data) {
    var bytes: [UInt8] = [UInt8(value & 0x7F)]
    var rest = value >> 7
    while rest > 0 {
      bytes.append(UInt8(rest & 0x7F) | 0x80)
      rest >>= 7
    }
    data.append(contentsOf: bytes.reversed())
  }
}
