import Foundation
import Vision

/// Finds the text in an image, on this Mac, so that search can find the image.
enum ImageTextRecognizer {
    static func text(in imageData: Data) async -> String? {
        await Task.detached(priority: .utility) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            guard (try? VNImageRequestHandler(data: imageData).perform([request])) != nil else { return nil }
            let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
            return lines.isEmpty ? nil : lines.joined(separator: "\n")
        }.value
    }
}
