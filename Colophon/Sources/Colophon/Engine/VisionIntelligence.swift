import CoreGraphics
import Foundation
import Vision

/// Apple's built-in image intelligence: aesthetics scoring, OCR, feature prints and scene labels.
/// Everything here is best-effort and returns nothing (rather than throwing) when Vision cannot help.
enum VisionIntelligence {
    /// Overall aesthetics score (−1...1) and whether the picture is a "utility" image (screenshot,
    /// document, receipt). Needs macOS 15; nil below that or on failure.
    static func aesthetics(_ image: CGImage) -> (score: Double, isUtility: Bool)? {
        if #available(macOS 15, *) {
            let request = VNCalculateImageAestheticsScoresRequest()
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
                guard let obs = request.results?.first else { return nil }
                let score = Double(obs.overallScore)
                guard score.isFinite else { return nil }
                return (score: score.clamped(-1, 1), isUtility: obs.isUtility)
            } catch {
                return nil
            }
        }
        return nil
    }

    /// Bounding boxes of printed text, normalized with a top-left origin. Fast recognition, no
    /// language correction: we only need to know where the words are, not what they say.
    static func textRegions(_ image: CGImage, minimumConfidence: Float = 0.5) -> [NRect] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let results = request.results else { return [] }
            var rects: [NRect] = []
            for obs in results where obs.confidence >= minimumConfidence {
                // Fast recognition sees "words" in noise and gradients; real words have letters and some confidence.
                guard let top = obs.topCandidates(1).first, top.confidence >= minimumConfidence else { continue }
                let letters = top.string.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.count
                guard letters >= 2 else { continue }
                let b = obs.boundingBox
                guard b.width > 0.02, b.height > 0.01 else { continue }
                rects.append(NRect(Double(b.minX), Double(1 - b.maxY), Double(b.width), Double(b.height)))
            }
            return rects
        } catch {
            return []
        }
    }

    /// A compact perceptual fingerprint of the image, for similarity comparisons.
    static func featurePrint(_ image: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first
        } catch {
            return nil
        }
    }

    /// Perceptual distance between two feature prints: 0 is identical, larger is more different.
    static func distance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Float? {
        var d: Float = 0
        do {
            try a.computeDistance(&d, to: b)
            return d.isFinite ? d : nil
        } catch {
            return nil
        }
    }

    /// Scene and object labels ("outdoor", "cat", "document"), most confident first.
    static func classify(_ image: CGImage, limit: Int = 8, minimumConfidence: Double = 0.2) -> [(label: String, confidence: Double)] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let results = request.results else { return [] }
            var out: [(label: String, confidence: Double)] = []
            for obs in results {
                let c = Double(obs.confidence)
                if c >= minimumConfidence { out.append((label: obs.identifier, confidence: c)) }
            }
            out.sort { $0.confidence > $1.confidence }
            if out.count > max(0, limit) { out = Array(out.prefix(max(0, limit))) }
            return out
        } catch {
            return []
        }
    }
}
