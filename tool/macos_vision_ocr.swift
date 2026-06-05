import Foundation
import Vision
import AppKit

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: swift tool/macos_vision_ocr.swift <image.jpg>\n", stderr)
    exit(1)
}

let path = CommandLine.arguments[1]
let url = URL(fileURLWithPath: path)
guard let image = NSImage(contentsOf: url),
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let cgImage = bitmap.cgImage else {
    fputs("Could not load image\n", stderr)
    exit(1)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false
request.recognitionLanguages = ["en-US", "az-AZ"]

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
try handler.perform([request])

var lines: [(CGFloat, String)] = []
for obs in request.results ?? [] {
    guard let best = obs.topCandidates(1).first else { continue }
    let box = obs.boundingBox
    lines.append((box.origin.y, best.string))
}

lines.sort { $0.0 > $1.0 }
for (_, text) in lines {
    print(text)
}
