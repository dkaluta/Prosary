#if os(macOS)
import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Prosary

final class MacGalleryImageColorTests: XCTestCase {
  func testWideGamutPixelsAreConvertedAndTaggedAsSRGB() throws {
    let source = try bitmap(colorSpace: CGColorSpace.displayP3, components: [[0.7, 0.4, 0.2]])
    let data = try encode(source, type: .png)
    let preview = try MacPrayerGalleryImageStore.previewBitmap(data).image
    XCTAssertEqual(preview.colorSpace?.name, CGColorSpace.sRGB)
    XCTAssertEqual(preview.bitsPerComponent, 8)
    XCTAssertFalse(preview.bitmapInfo.contains(.floatComponents))
    let converted = try redValues(preview)[0]
    XCTAssertGreaterThan(converted, 185, "P3 red must be color-converted, not relabeled from its original 179")

    let output = try MacPrayerGalleryImageStore.normalized(data).data
    XCTAssertTrue(MacPrayerGalleryImageStore.isSDRsRGBJPEG(output))
    let properties = try properties(output)
    XCTAssertEqual(properties[kCGImagePropertyDepth] as? Int, 8)
    XCTAssertTrue((properties[kCGImagePropertyProfileName] as? String)?.contains("sRGB") == true,
      "The JPEG must carry an actual sRGB profile")
    XCTAssertNotNil(output.range(of: Data("ICC_PROFILE".utf8)))
    XCTAssertFalse(MacPrayerGalleryImageStore.isSDRsRGBJPEG(try encode(source, type: .jpeg)))
    XCTAssertFalse(MacPrayerGalleryImageStore.isSDRsRGBJPEG(data))
  }

  func testPQHDRIsToneMappedBeforeEightBitSRGBEncoding() throws {
    // The .6/.7 PQ patches are about 244/621 nits, above 203-nit HDR reference
    // white. Extreme 1,000/10,000-nit patches both reach 255 with Apple's documented
    // SDR tone curve, so they cannot establish preservation of ordinary highlights.
    // A raw relabel would retain 64/128/153/179 instead of tone-mapped pixels.
    let source = try bitmap(colorSpace: CGColorSpace.itur_2100_PQ,
      components: [[0.25, 0.25, 0.25], [0.5, 0.5, 0.5], [0.6, 0.6, 0.6],
        [0.7, 0.7, 0.7], [0.75, 0.75, 0.75], [1, 1, 1]], depth: 16)
    let data = try encode(source, type: .png)
    let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    let hdr = try XCTUnwrap(CGImageSourceCreateImageAtIndex(imageSource, 0,
      [kCGImageSourceDecodeRequest: kCGImageSourceDecodeToHDR] as CFDictionary))
    XCTAssertTrue(CGColorSpaceUsesITUR_2100TF(try XCTUnwrap(hdr.colorSpace)))
    XCTAssertEqual(try properties(data)[kCGImagePropertyDepth] as? Int, 16)

    let preview = try MacPrayerGalleryImageStore.previewBitmap(data).image
    XCTAssertEqual(preview.colorSpace?.name, CGColorSpace.sRGB)
    XCTAssertEqual(preview.bitsPerComponent, 8)
    let values = try redValues(preview)
    XCTAssertEqual(values.count, 6)
    for (lower, higher) in zip(values, values.dropFirst()) {
      XCTAssertLessThanOrEqual(lower, higher, "Tone mapping must stay monotonic through the brightest extremes")
    }
    XCTAssertGreaterThan(abs(values[0] - 64), 10, "HDR transfer values must be tone mapped, not copied as SDR")
    XCTAssertGreaterThan(values[2], 173, "The highlight must be transformed from its PQ signal value of 153")
    XCTAssertLessThan(values[0], values[1])
    XCTAssertLessThan(values[1], values[2])
    XCTAssertLessThan(values[2], values[3], "Distinct HDR highlights must survive tone mapping")
    XCTAssertLessThan(values[3], 255, "These HDR highlights must not simply clip to SDR white")
    XCTAssertTrue(MacPrayerGalleryImageStore.isSDRsRGBJPEG(try MacPrayerGalleryImageStore.normalized(data).data))
  }

  func testNewJPEGDoesNotCarrySourceEXIFGPSOrHDRGainMaps() throws {
    let source = try bitmap(colorSpace: CGColorSpace.sRGB, components: [[0.3, 0.5, 0.7]])
    let data = try encode(source, type: .jpeg, properties: [
      kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "private camera note"],
      kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 32.0, kCGImagePropertyGPSLatitudeRef: "N"],
      kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Private camera"]
    ])
    XCTAssertNotNil(try properties(data)[kCGImagePropertyGPSDictionary])
    let output = try MacPrayerGalleryImageStore.normalized(data).data
    let properties = try properties(output)
    XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
    XCTAssertNil(properties[kCGImagePropertyExifDictionary])
    XCTAssertNil(properties[kCGImagePropertyTIFFDictionary])
    XCTAssertNil(output.range(of: Data("private camera note".utf8)))
    let decoded = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
    XCTAssertNil(CGImageSourceCopyAuxiliaryDataInfoAtIndex(decoded, 0, kCGImageAuxiliaryDataTypeHDRGainMap))
    if #available(macOS 15, *) {
      XCTAssertNil(CGImageSourceCopyAuxiliaryDataInfoAtIndex(decoded, 0, kCGImageAuxiliaryDataTypeISOGainMap))
    }
    XCTAssertTrue(MacPrayerGalleryImageStore.isSDRsRGBJPEG(output))
  }

  private func bitmap(colorSpace name: CFString, components: [[Double]], depth: Int = 8) throws -> CGImage {
    let width = components.count * 16, height = 16
    var bytes = Data()
    for _ in 0..<height {
      for channels in components {
        for _ in 0..<16 {
          for component in channels + [1] {
            if depth == 16 {
              var value = UInt16((component * 65535).rounded()).littleEndian
              withUnsafeBytes(of: &value) { bytes.append(contentsOf: $0) }
            } else { bytes.append(UInt8((component * 255).rounded())) }
          }
        }
      }
    }
    let provider = try XCTUnwrap(CGDataProvider(data: bytes as CFData))
    let order: CGBitmapInfo = depth == 16 ? .byteOrder16Little : []
    return try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: depth,
      bitsPerPixel: depth * 4, bytesPerRow: width * depth / 8 * 4,
      space: try XCTUnwrap(CGColorSpace(name: name)),
      bitmapInfo: order.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
  }

  private func encode(_ image: CGImage, type: UTType, properties: [CFString: Any] = [:]) throws -> Data {
    let output = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return output as Data
  }

  private func properties(_ data: Data) throws -> [CFString: Any] {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
  }

  private func redValues(_ image: CGImage) throws -> [Int] {
    let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
      bytesPerRow: image.width * 4, space: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
    return stride(from: 8, to: image.width, by: 16).map { Int(bytes[$0 * 4]) }
  }
}
#endif
