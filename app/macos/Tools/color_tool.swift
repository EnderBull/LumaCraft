import CoreGraphics
import Foundation
import ImageIO
import Darwin

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data(message.utf8))
  exit(EXIT_FAILURE)
}

let arguments = CommandLine.arguments
guard arguments.count == 3, let maxEdge = Int(arguments[2]), maxEdge >= 0 else {
  fail("Invalid decoder arguments")
}
let url = URL(fileURLWithPath: arguments[1])
guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
      CGImageSourceGetCount(source) > 0 else { fail("ImageIO cannot open this file") }
let index = CGImageSourceGetPrimaryImageIndex(source)
guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
      let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
      let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
      width > 0, height > 0 else { fail("ImageIO cannot read image dimensions") }
let longest = max(width, height)
let edge = maxEdge > 0 ? min(maxEdge, longest) : longest
let estimate = Double(edge) / Double(longest)
guard edge <= 16384,
      ceil(Double(width) * estimate) * ceil(Double(height) * estimate) <= 134_217_728 else {
  fail("TOO_LARGE")
}

let options: [CFString: Any] = [
  kCGImageSourceCreateThumbnailFromImageAlways: true,
  kCGImageSourceCreateThumbnailWithTransform: true,
  kCGImageSourceThumbnailMaxPixelSize: edge,
  kCGImageSourceShouldCacheImmediately: true,
]
guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary),
      let space = CGColorSpace(name: CGColorSpace.sRGB),
      let profile = space.copyICCData() as Data? else { fail("ImageIO could not decode into sRGB") }
let w = image.width, h = image.height
guard w > 0, h > 0, w * h <= 134_217_728 else { fail("TOO_LARGE") }
let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
let swapsAxes = (5...8).contains(orientation)
if maxEdge == 0 && (w != (swapsAxes ? height : width) || h != (swapsAxes ? width : height)) {
  fail("ImageIO returned an unexpected full-resolution size")
}
var pixels = Data(count: w * h * 4)
let converted = pixels.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> Bool in
  let flags = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
  guard let context = CGContext(data: buffer.baseAddress, width: w, height: h,
                                bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: space, bitmapInfo: flags) else { return false }
  context.setBlendMode(.copy)
  context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
  let rgba = buffer.bindMemory(to: UInt8.self)
  for offset in stride(from: 0, to: rgba.count, by: 4) {
    let alpha = Int(rgba[offset + 3])
    if alpha > 0 && alpha < 255 {
      for channel in 0..<3 {
        rgba[offset + channel] = UInt8(min(255, (Int(rgba[offset + channel]) * 255 + alpha / 2) / alpha))
      }
    }
  }
  return true
}
guard converted else { fail("TOO_LARGE") }
var header = Data("LMC1".utf8)
for value in [w, h, profile.count] {
  var word = UInt32(value).littleEndian
  withUnsafeBytes(of: &word) { header.append(contentsOf: $0) }
}
FileHandle.standardOutput.write(header)
FileHandle.standardOutput.write(profile)
FileHandle.standardOutput.write(pixels)
