//
//  OggOpusCAFTests.swift
//  ProsaryTests
//
//  The Ogg Opus → CAF repackager, tested against a real libopus-encoded fixture (a one-second
//  24 kbps mono tone, small enough to embed) plus synthetic streams for the paths a healthy
//  encode never exercises. The fixture's expected facts (packet count, granule, pre-skip) come
//  from the encode itself and pin the demuxer; AVFoundation then proves the repackaged CAF is
//  actually decodable — the whole point of the container swap.
//

import AVFoundation
import XCTest
@testable import Prosary

final class OggOpusCAFTests: XCTestCase {
  /// One second of 330 Hz mono at 24 kbps VBR (ffmpeg/libopus, 20 ms frames).
  private static let toneOpus = Data(base64Encoded: "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")!

  func testDemuxReadsTheFixtureFacts() throws {
    let stream = try OggOpusCAF.demux(Self.toneOpus)
    XCTAssertEqual(stream.channels, 1)
    XCTAssertEqual(stream.preSkip, 312)
    XCTAssertEqual(stream.packets.count, 51)
    XCTAssertEqual(stream.frameCounts.count, 51)
    // libopus 20 ms frames: every packet decodes to 960 samples at 48 kHz.
    XCTAssertEqual(Set(stream.frameCounts), [960])
    XCTAssertEqual(stream.lastGranule, 48312) // 48000 audible + 312 pre-skip
    XCTAssertEqual(stream.duration, 1.0, accuracy: 0.001)
  }

  func testRepackagedCAFDecodesIdenticallyToTheSource() throws {
    let caf = try OggOpusCAF.repackage(Self.toneOpus)
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("OggOpusCAFTests-\(UUID().uuidString).caf")
    try caf.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let file = try AVAudioFile(forReading: url)
    XCTAssertEqual(file.processingFormat.sampleRate, 48000)
    XCTAssertEqual(file.processingFormat.channelCount, 1)
    XCTAssertEqual(file.length, 48000) // pre-skip already trimmed by the pakt priming fields

    // Decoding all the way through with real signal coming out is what proves the packets
    // survived the container swap byte-for-byte.
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                  frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    XCTAssertEqual(Int(buffer.frameLength), 48000)
    var energy = 0.0
    for i in 0..<Int(buffer.frameLength) { energy += Double(buffer.floatChannelData![0][i]).magnitude }
    XCTAssertGreaterThan(energy / 48000, 0.01, "decoded audio should carry the tone, not silence")
  }

  func testTocSampleCounts() throws {
    func packet(_ bytes: [UInt8]) -> Data { Data(bytes) }
    // Code 0 (one frame): SILK 20 ms (config 1) = 960; SILK 60 ms (config 3) = 2880.
    XCTAssertEqual(try OggOpusCAF.samplesPerPacket(packet([1 << 3])), 960)
    XCTAssertEqual(try OggOpusCAF.samplesPerPacket(packet([3 << 3])), 2880)
    // Hybrid 10 ms (config 12) = 480; CELT 2.5 ms (config 16) = 120.
    XCTAssertEqual(try OggOpusCAF.samplesPerPacket(packet([12 << 3])), 480)
    XCTAssertEqual(try OggOpusCAF.samplesPerPacket(packet([16 << 3])), 120)
    // Codes 1/2: two frames. CELT 20 ms (config 19) twice = 1920.
    XCTAssertEqual(try OggOpusCAF.samplesPerPacket(packet([(19 << 3) | 1])), 1920)
    XCTAssertEqual(try OggOpusCAF.samplesPerPacket(packet([(19 << 3) | 2])), 1920)
    // Code 3: the count byte's low 6 bits. Three 20 ms SILK frames = 2880.
    XCTAssertEqual(try OggOpusCAF.samplesPerPacket(packet([(1 << 3) | 3, 3])), 2880)
    // Malformed: empty, and code 3 with no count byte / a zero count.
    XCTAssertThrowsError(try OggOpusCAF.samplesPerPacket(Data()))
    XCTAssertThrowsError(try OggOpusCAF.samplesPerPacket(packet([(1 << 3) | 3])))
    XCTAssertThrowsError(try OggOpusCAF.samplesPerPacket(packet([(1 << 3) | 3, 0])))
  }

  func testRejectsNonOpusData() {
    XCTAssertThrowsError(try OggOpusCAF.demux(Data("not an ogg stream at all".utf8)))
    XCTAssertThrowsError(try OggOpusCAF.demux(Data()))
  }

  /// Packets over 127 bytes force the multi-byte variable-length quantity encoding in the CAF
  /// packet table — a real 24 kbps mono encode never produces one, so a synthetic stream (valid
  /// TOC byte, padded body) exercises it, and the pakt chunk is parsed back by hand to check.
  func testPacketTableUsesMultiByteVLQForLargePackets() throws {
    let head = Data("OpusHead".utf8) + Data([1, 1, 0x38, 0x01, 0x80, 0xBB, 0, 0, 0, 0, 0])
    let tags = Data("OpusTags".utf8) + Data([0, 0, 0, 0, 0, 0, 0, 0])
    var audio = Data([UInt8(1 << 3)]) // SILK 20 ms, code 0
    audio.append(Data(repeating: 0x42, count: 299)) // 300 bytes total → VLQ 0x82 0x2C
    let ogg = oggPage(packets: [head], granule: 0, first: true)
      + oggPage(packets: [tags], granule: 0, sequence: 1)
      + oggPage(packets: [audio], granule: 960 + 312, sequence: 2, last: true)

    let stream = try OggOpusCAF.demux(ogg)
    XCTAssertEqual(stream.packets.map(\.count), [300])
    XCTAssertEqual(stream.frameCounts, [960])

    let caf = try OggOpusCAF.repackage(ogg)
    let paktRange = try XCTUnwrap(caf.range(of: Data("pakt".utf8)))
    // Chunk header (type + 8-byte size), then 24 bytes of pakt fields, then the entries.
    let entries = caf[(paktRange.upperBound + 8 + 24)...]
    XCTAssertEqual([UInt8](entries.prefix(2)), [0x82, 0x2C])
  }

  /// A minimal Ogg page (CRC left zero — the demuxer doesn't verify it, matching every
  /// tolerant reader; the packets here must each fit in single lacing segments < 255).
  private func oggPage(packets: [Data], granule: Int64, sequence: UInt32 = 0,
                       first: Bool = false, last: Bool = false) -> Data {
    var page = Data("OggS".utf8)
    page.append(0) // version
    page.append(first ? 0x02 : (last ? 0x04 : 0))
    withUnsafeBytes(of: granule.littleEndian) { page.append(contentsOf: $0) }
    page.append(contentsOf: [0x11, 0x22, 0x33, 0x44]) // serial
    withUnsafeBytes(of: sequence.littleEndian) { page.append(contentsOf: $0) }
    page.append(contentsOf: [0, 0, 0, 0]) // crc (unchecked)
    page.append(UInt8(packets.reduce(0) { $0 + ($1.count / 255) + 1 }))
    for packet in packets {
      var remaining = packet.count
      while remaining >= 255 { page.append(255); remaining -= 255 }
      page.append(UInt8(remaining))
    }
    for packet in packets { page.append(packet) }
    return page
  }
}
