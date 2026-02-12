import SwiftUI
import Foundation
@preconcurrency import Vision
import PDFKit
import UniformTypeIdentifiers
import CoreImage

/// Service to handle OCR text extraction from Images and PDFs
final class OCRService {
    static let shared = OCRService()

    private init() {}
    private let ciContext = CIContext(options: nil)

    /// Extracts text from a file at the given URL
    func extractText(from url: URL, mode: OCRSAccuracyMode = .standard) async throws -> String {
        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
        guard let contentType = resourceValues.contentType else {
            throw OCRError.unknownFileType
        }

        if contentType.conforms(to: .pdf) {
            return try await extractTextFromPDF(url: url, mode: mode)
        } else if contentType.conforms(to: .image) {
            return try await extractTextFromImage(url: url, mode: mode)
        } else {
            throw OCRError.unsupportedFileType
        }
    }
    
    private func extractTextFromPDF(url: URL, mode: OCRSAccuracyMode) async throws -> String {
        let pdfDoc = try await Task.detached(priority: .userInitiated) {
            guard let pdfDoc = PDFDocument(url: url) else {
                throw OCRError.couldNotLoadPDF
            }
            return pdfDoc
        }.value

        var fullText = ""

        for i in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: i) else { continue }

            let pageRect = page.bounds(for: .mediaBox)
            let image = NSImage(size: pageRect.size, flipped: false) { rect in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                context.setFillColor(NSColor.white.cgColor)
                context.fill(rect)
                page.draw(with: .mediaBox, to: context)
                return true
            }

            if let pageText = try? await performOCR(on: image, mode: mode, languageMode: .auto) {
                if !fullText.isEmpty {
                    fullText += "\n\n--- Page \(i + 1) ---\n\n"
                }
                fullText += pageText
            }
        }

        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTextFromImage(url: URL, mode: OCRSAccuracyMode) async throws -> String {
        let image = try await Task.detached(priority: .userInitiated) {
            guard let image = NSImage(contentsOf: url) else {
                throw OCRError.couldNotLoadImage
            }
            return image
        }.value
        return try await performOCR(on: image, mode: mode, languageMode: .auto)
    }

    func performOCR(on image: NSImage, mode: OCRSAccuracyMode, languageMode: OCRSLanguageMode) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.couldNotProcessImageData
        }

        // Preprocess & downscale once, then feed OCR pipelines and detection.
        let prepared = prepareImages(from: cgImage, mode: mode)
        let candidates = prepared.candidates

        if OCRSDebug.enabled {
            OCRSDebug.log("OCR mode=\(mode.rawValue) language=\(languageMode.rawValue) pipelines=\(candidates.map { $0.label }.joined(separator: ", "))")
            for (index, candidate) in candidates.enumerated() {
                OCRSDebug.save(candidate.image, name: "pipeline_\(index)_\(candidate.label)")
            }
        }

        // Pre-detect text regions to avoid OCR on the full image when possible.
        let regions = await detectTextRegions(in: prepared.detectionImage)
        if OCRSDebug.enabled {
            OCRSDebug.log("Detected text regions: \(regions.count)")
        }

        var fallbackText = ""
        var bestText = ""
        var bestLetters = 0
        var bestRatio: Double = 0

        let batchSize = 2
        var index = 0
        while index < candidates.count {
            let end = min(index + batchSize, candidates.count)
            let batch = Array(candidates[index..<end])
            let results = await recognizeBatch(batch, mode: mode, languageMode: languageMode, regions: regions)

            var strongFound = false
            for result in results {
                fallbackText = result.text
                let (letters, ratio) = score(text: result.text)
                if OCRSDebug.enabled {
                    OCRSDebug.log("Result \(result.label): letters=\(letters) ratio=\(String(format: "%.2f", ratio))")
                }
                if letters > 0 && ratio >= 0.2 {
                    if letters > bestLetters || (letters == bestLetters && ratio > bestRatio) {
                        bestLetters = letters
                        bestRatio = ratio
                        bestText = result.text
                    }
                    if letters >= 8 && ratio >= 0.6 {
                        strongFound = true
                    }
                }
            }

            if strongFound, !bestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return bestText
            }

            index = end
        }

        if !bestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bestText
        }
        return fallbackText
    }

    private struct RecognitionConfig {
        let recognitionLevel: VNRequestTextRecognitionLevel
        let usesLanguageCorrection: Bool
        let minimumTextHeight: Float
    }

    private func recognizeText(in cgImage: CGImage, mode: OCRSAccuracyMode, languageMode: OCRSLanguageMode) async throws -> String {
        let configs = recognitionConfigs(for: mode)

        let languageModesToTry: [OCRSLanguageMode]
        if languageMode == .auto {
            languageModesToTry = [.auto, .system]
        } else {
            languageModesToTry = [languageMode]
        }

        var lastText = ""
        for config in configs {
            for langMode in languageModesToTry {
                let text = try await performRecognition(in: cgImage, mode: mode, languageMode: langMode, config: config)
                lastText = text
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return text
                }
            }
        }

        return lastText
    }

    private func performRecognition(in cgImage: CGImage, mode: OCRSAccuracyMode, languageMode: OCRSLanguageMode, config: RecognitionConfig, regionOfInterest: CGRect? = nil) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let request = VNRecognizeTextRequest { request, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: "")
                        return
                    }

                    let text = observations.compactMap {
                        $0.topCandidates(1).first?.string
                    }.joined(separator: "\n")

                    continuation.resume(returning: text)
                }

                request.recognitionLevel = config.recognitionLevel
                request.usesLanguageCorrection = config.usesLanguageCorrection
                request.minimumTextHeight = config.minimumTextHeight
                if let regionOfInterest {
                    request.regionOfInterest = regionOfInterest
                }

                if let maxRevision = VNRecognizeTextRequest.supportedRevisions.max() {
                    request.revision = maxRevision
                }

                request.automaticallyDetectsLanguage = (languageMode == .auto)

                if let supported = try? request.supportedRecognitionLanguages() {
                    let preferred: [String]
                    switch languageMode {
                    case .auto, .system:
                        preferred = Locale.preferredLanguages
                    default:
                        preferred = languageMode.bcp47
                    }
                    let matched = preferred.filter { supported.contains($0) }
                    if !matched.isEmpty {
                        request.recognitionLanguages = matched
                    }
                }

                do {
                    try requestHandler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func recognitionConfigs(for mode: OCRSAccuracyMode) -> [RecognitionConfig] {
        switch mode {
        case .high:
            return [
                RecognitionConfig(recognitionLevel: .accurate, usesLanguageCorrection: true, minimumTextHeight: 0.002),
                RecognitionConfig(recognitionLevel: .accurate, usesLanguageCorrection: false, minimumTextHeight: 0.002),
                RecognitionConfig(recognitionLevel: .fast, usesLanguageCorrection: false, minimumTextHeight: 0.0015)
            ]
        case .standard:
            return [
                RecognitionConfig(recognitionLevel: .accurate, usesLanguageCorrection: true, minimumTextHeight: 0.006),
                RecognitionConfig(recognitionLevel: .fast, usesLanguageCorrection: false, minimumTextHeight: 0.006)
            ]
        }
    }

    private struct PreparedImages {
        let candidates: [OCRCandidate]
        let detectionImage: CGImage
    }

    private func prepareImages(from cgImage: CGImage, mode: OCRSAccuracyMode) -> PreparedImages {
        var results: [OCRCandidate] = []

        // vImage downscale + preprocess (contrast/sharpen) for speed + clarity.
        let downscaled = OCRSImageProcessing.downscaleIfNeeded(cgImage)
        let preprocessed = OCRSImageProcessing.preprocessIfNeeded(downscaled.image)
        let base = CIImage(cgImage: preprocessed)
        let preferInverted = averageLuminance(of: base).map { $0 < 0.45 } ?? false
        OCRSDebug.log("Prepared images preferInverted=\(preferInverted) scale=\(String(format: "%.2f", downscaled.scale))")

        if mode == .high {
            if preferInverted {
                appendCandidate(&results, image: renderPipeline(base, variant: .micro, invert: true), label: label(variant: .micro, invert: true))
                appendCandidate(&results, image: renderPipeline(base, variant: .high, invert: true), label: label(variant: .high, invert: true))
            }

            appendCandidate(&results, image: renderPipeline(base, variant: .micro, invert: false), label: label(variant: .micro, invert: false))
            appendCandidate(&results, image: renderPipeline(base, variant: .high, invert: false), label: label(variant: .high, invert: false))

            if !preferInverted {
                appendCandidate(&results, image: renderPipeline(base, variant: .micro, invert: true), label: label(variant: .micro, invert: true))
                appendCandidate(&results, image: renderPipeline(base, variant: .high, invert: true), label: label(variant: .high, invert: true))
            }
        }

        if preferInverted {
            appendCandidate(&results, image: renderPipeline(base, variant: .standard, invert: true), label: label(variant: .standard, invert: true))
        }

        appendCandidate(&results, image: renderPipeline(base, variant: .standard, invert: false), label: label(variant: .standard, invert: false))

        if !preferInverted {
            appendCandidate(&results, image: renderPipeline(base, variant: .standard, invert: true), label: label(variant: .standard, invert: true))
        }

        results.append(OCRCandidate(image: preprocessed, label: "original"))

        let detectionImage = renderPipeline(base, variant: .standard, invert: preferInverted) ?? preprocessed
        return PreparedImages(candidates: results, detectionImage: detectionImage)
    }

    private enum PipelineVariant {
        case standard
        case high
        case micro

        var label: String {
            switch self {
            case .standard: return "standard"
            case .high: return "high"
            case .micro: return "micro"
            }
        }
    }

    private func renderPipeline(_ image: CIImage, variant: PipelineVariant, invert: Bool) -> CGImage? {
        var output = image

        let maxDim = max(output.extent.width, output.extent.height)
        let needsUpscale = variant != .standard && maxDim < 1400
        if needsUpscale, let lanczos = CIFilter(name: "CILanczosScaleTransform") {
            let scale: CGFloat
            switch variant {
            case .micro:
                if maxDim < 600 {
                    scale = 3.2
                } else if maxDim < 900 {
                    scale = 2.6
                } else {
                    scale = 2.0
                }
            default:
                if maxDim < 700 {
                    scale = 2.5
                } else if maxDim < 1000 {
                    scale = 2.0
                } else {
                    scale = 1.5
                }
            }
            lanczos.setValue(output, forKey: kCIInputImageKey)
            lanczos.setValue(scale, forKey: kCIInputScaleKey)
            lanczos.setValue(1.0, forKey: kCIInputAspectRatioKey)
            if let filtered = lanczos.outputImage { output = filtered }
        }

        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(output, forKey: kCIInputImageKey)
            controls.setValue(0.0, forKey: kCIInputSaturationKey)
            let contrast: Double
            let brightness: Double
            switch variant {
            case .standard:
                contrast = 1.2
                brightness = 0.0
            case .high:
                contrast = 1.5
                brightness = 0.05
            case .micro:
                contrast = 2.0
                brightness = 0.06
            }
            controls.setValue(contrast, forKey: kCIInputContrastKey)
            controls.setValue(brightness, forKey: kCIInputBrightnessKey)
            if let filtered = controls.outputImage { output = filtered }
        }

        if let exposure = CIFilter(name: "CIExposureAdjust") {
            exposure.setValue(output, forKey: kCIInputImageKey)
            let ev: Double
            switch variant {
            case .standard:
                ev = 0.1
            case .high:
                ev = 0.2
            case .micro:
                ev = 0.25
            }
            exposure.setValue(ev, forKey: kCIInputEVKey)
            if let filtered = exposure.outputImage { output = filtered }
        }

        if let gamma = CIFilter(name: "CIGammaAdjust") {
            gamma.setValue(output, forKey: kCIInputImageKey)
            let power: Double
            switch variant {
            case .standard:
                power = 0.95
            case .high:
                power = 0.88
            case .micro:
                power = 0.85
            }
            gamma.setValue(power, forKey: "inputPower")
            if let filtered = gamma.outputImage { output = filtered }
        }

        if variant != .standard, let noise = CIFilter(name: "CINoiseReduction") {
            noise.setValue(output, forKey: kCIInputImageKey)
            let noiseLevel: Double
            let sharpness: Double
            switch variant {
            case .standard:
                noiseLevel = 0.0
                sharpness = 0.0
            case .high:
                noiseLevel = 0.02
                sharpness = 0.6
            case .micro:
                noiseLevel = 0.02
                sharpness = 0.7
            }
            noise.setValue(noiseLevel, forKey: "inputNoiseLevel")
            noise.setValue(sharpness, forKey: "inputSharpness")
            if let filtered = noise.outputImage { output = filtered }
        }

        if variant != .standard, let morph = CIFilter(name: "CIMorphologyMaximum") {
            morph.setValue(output, forKey: kCIInputImageKey)
            let radius: Double
            switch variant {
            case .high:
                radius = 1.0
            case .micro:
                radius = 0.8
            case .standard:
                radius = 0.0
            }
            morph.setValue(radius, forKey: "inputRadius")
            if let filtered = morph.outputImage { output = filtered }
        }

        if let sharpen = CIFilter(name: "CIUnsharpMask") {
            sharpen.setValue(output, forKey: kCIInputImageKey)
            let radius: Double
            let intensity: Double
            switch variant {
            case .standard:
                radius = 1.5
                intensity = 0.4
            case .high:
                radius = 2.5
                intensity = 0.6
            case .micro:
                radius = 2.0
                intensity = 0.75
            }
            sharpen.setValue(radius, forKey: "inputRadius")
            sharpen.setValue(intensity, forKey: "inputIntensity")
            if let filtered = sharpen.outputImage { output = filtered }
        }

        if variant != .standard, let highlight = CIFilter(name: "CIHighlightShadowAdjust") {
            highlight.setValue(output, forKey: kCIInputImageKey)
            let highlightAmount: Double
            let shadowAmount: Double
            switch variant {
            case .high:
                highlightAmount = 0.2
                shadowAmount = 0.6
            case .micro:
                highlightAmount = 0.15
                shadowAmount = 0.55
            case .standard:
                highlightAmount = 0.0
                shadowAmount = 0.0
            }
            highlight.setValue(highlightAmount, forKey: "inputHighlightAmount")
            highlight.setValue(shadowAmount, forKey: "inputShadowAmount")
            if let filtered = highlight.outputImage { output = filtered }
        }

        if variant == .micro, let sharpen = CIFilter(name: "CISharpenLuminance") {
            sharpen.setValue(output, forKey: kCIInputImageKey)
            sharpen.setValue(0.7, forKey: "inputSharpness")
            if let filtered = sharpen.outputImage { output = filtered }
        }

        if let clamp = CIFilter(name: "CIColorClamp") {
            clamp.setValue(output, forKey: kCIInputImageKey)
            clamp.setValue(CIVector(x: 0.05, y: 0.05, z: 0.05, w: 0.0), forKey: "inputMinComponents")
            clamp.setValue(CIVector(x: 0.95, y: 0.95, z: 0.95, w: 1.0), forKey: "inputMaxComponents")
            if let filtered = clamp.outputImage { output = filtered }
        }

        if invert, let inverted = CIFilter(name: "CIColorInvert", parameters: [kCIInputImageKey: output])?.outputImage {
            output = inverted
        }

        return ciContext.createCGImage(output, from: output.extent)
    }

    private func averageLuminance(of image: CIImage) -> CGFloat? {
        guard let filter = CIFilter(name: "CIAreaAverage") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        ciContext.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: colorSpace
        )

        let r = CGFloat(pixel[0]) / 255.0
        let g = CGFloat(pixel[1]) / 255.0
        let b = CGFloat(pixel[2]) / 255.0
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private struct OCRCandidate {
        let image: CGImage
        let label: String
    }

    private struct CandidateResult {
        let label: String
        let text: String
    }

    // Small-parallel OCR (batch) to reduce total latency without CPU spikes.
    private func recognizeBatch(_ batch: [OCRCandidate], mode: OCRSAccuracyMode, languageMode: OCRSLanguageMode, regions: [CGRect]) async -> [CandidateResult] {
        await withTaskGroup(of: CandidateResult?.self) { group in
            for candidate in batch {
                group.addTask { [self] in
                    do {
                        let text = try await recognizeCandidate(candidate, mode: mode, languageMode: languageMode, regions: regions)
                        return CandidateResult(label: candidate.label, text: text)
                    } catch {
                        OCRSDebug.log("OCR error \(candidate.label): \(error.localizedDescription)")
                        return CandidateResult(label: candidate.label, text: "")
                    }
                }
            }

            var results: [CandidateResult] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results
        }
    }

    // Two-stage OCR: quick pass → region OCR → full OCR fallback.
    private func recognizeCandidate(_ candidate: OCRCandidate, mode: OCRSAccuracyMode, languageMode: OCRSLanguageMode, regions: [CGRect]) async throws -> String {
        let quickText = try await quickRecognizeText(in: candidate.image, mode: mode, languageMode: languageMode)
        if isStrong(text: quickText) {
            return quickText
        }

        var bestText = quickText

        if !regions.isEmpty {
            let regionText = try await recognizeTextInRegions(in: candidate.image, mode: mode, languageMode: languageMode, regions: regions)
            if isStrong(text: regionText) {
                return regionText
            }
            bestText = bestOf(bestText, regionText)
        }

        let fullText = try await recognizeText(in: candidate.image, mode: mode, languageMode: languageMode)
        return bestOf(bestText, fullText)
    }

    // Quick OCR pass: fast recognition + higher minimum text height.
    private func quickRecognizeText(in cgImage: CGImage, mode: OCRSAccuracyMode, languageMode: OCRSLanguageMode) async throws -> String {
        let config: RecognitionConfig
        switch mode {
        case .high:
            config = RecognitionConfig(recognitionLevel: .fast, usesLanguageCorrection: false, minimumTextHeight: 0.004)
        case .standard:
            config = RecognitionConfig(recognitionLevel: .fast, usesLanguageCorrection: false, minimumTextHeight: 0.008)
        }
        return try await performRecognition(in: cgImage, mode: mode, languageMode: languageMode, config: config)
    }

    // OCR only within detected regions to avoid scanning the full image.
    private func recognizeTextInRegions(in cgImage: CGImage, mode: OCRSAccuracyMode, languageMode: OCRSLanguageMode, regions: [CGRect]) async throws -> String {
        let configs = recognitionConfigs(for: mode)
        let orderedRegions = regions.sorted { $0.maxY > $1.maxY }
        var lines: [String] = []

        for region in orderedRegions {
            var regionText = ""
            for config in configs {
                let text = try await performRecognition(in: cgImage, mode: mode, languageMode: languageMode, config: config, regionOfInterest: region)
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    regionText = text
                    break
                }
            }
            if !regionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append(regionText)
            }
        }

        return lines.joined(separator: "\n")
    }

    private func appendCandidate(_ list: inout [OCRCandidate], image: CGImage?, label: String) {
        if let image {
            list.append(OCRCandidate(image: image, label: label))
        }
    }

    private func label(variant: PipelineVariant, invert: Bool) -> String {
        invert ? "\(variant.label)_inv" : variant.label
    }

    private func score(text: String) -> (letters: Int, ratio: Double) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (0, 0) }
        let scalars = trimmed.unicodeScalars
        let total = scalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.count
        guard total > 0 else { return (0, 0) }
        let letters = scalars.filter { CharacterSet.alphanumerics.contains($0) }.count
        let ratio = Double(letters) / Double(total)
        return (letters, ratio)
    }

    private func isStrong(text: String) -> Bool {
        let (letters, ratio) = score(text: text)
        return letters >= 8 && ratio >= 0.6
    }

    private func bestOf(_ lhs: String, _ rhs: String) -> String {
        let (lettersL, ratioL) = score(text: lhs)
        let (lettersR, ratioR) = score(text: rhs)
        if lettersR > lettersL { return rhs }
        if lettersR == lettersL && ratioR > ratioL { return rhs }
        return lhs
    }

    // Detect rough text blocks (rectangles) for ROI-based OCR.
    private func detectTextRegions(in cgImage: CGImage) async -> [CGRect] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectTextRectanglesRequest()
                request.reportCharacterBoxes = false

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                    return
                }

                guard let observations = request.results, !observations.isEmpty else {
                    continuation.resume(returning: [])
                    return
                }

                let width = CGFloat(cgImage.width)
                let height = CGFloat(cgImage.height)
                let imageBounds = CGRect(x: 0, y: 0, width: width, height: height)

                var rects: [CGRect] = observations.map { observation in
                    let bb = observation.boundingBox
                    let rect = CGRect(
                        x: bb.origin.x * width,
                        y: (1 - bb.origin.y - bb.height) * height,
                        width: bb.width * width,
                        height: bb.height * height
                    )
                    return rect
                }

                rects = rects.filter { $0.width > 6 && $0.height > 6 }
                rects = rects.map { Self.expand(rect: $0, in: imageBounds) }

                let merged = Self.mergeRects(rects, in: imageBounds)
                let sorted = merged.sorted { $0.maxY > $1.maxY }
                let limited = Array(sorted.prefix(24))

                let normalized = limited.map { Self.rectToNormalized($0, width: width, height: height) }
                continuation.resume(returning: normalized)
            }
        }
    }

    private static func expand(rect: CGRect, in bounds: CGRect) -> CGRect {
        let padding = max(6, min(rect.width, rect.height) * 0.08)
        let expanded = rect.insetBy(dx: -padding, dy: -padding)
        return expanded.intersection(bounds)
    }

    private static func mergeRects(_ rects: [CGRect], in bounds: CGRect) -> [CGRect] {
        var remaining = rects
        var merged: [CGRect] = []

        remaining.sort { $0.area > $1.area }

        while let rect = remaining.first {
            remaining.removeFirst()
            var current = rect
            var changed = true

            while changed {
                changed = false
                var i = 0
                while i < remaining.count {
                    if current.intersects(remaining[i]) || current.distance(to: remaining[i]) < 12 {
                        current = current.union(remaining[i]).intersection(bounds)
                        remaining.remove(at: i)
                        changed = true
                    } else {
                        i += 1
                    }
                }
            }

            merged.append(current)
        }

        return merged
    }

    private static func rectToNormalized(_ rect: CGRect, width: CGFloat, height: CGFloat) -> CGRect {
        let x = rect.origin.x / width
        let y = 1 - (rect.origin.y + rect.height) / height
        let w = rect.width / width
        let h = rect.height / height
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

private extension CGRect {
    var area: CGFloat { width * height }

    func distance(to other: CGRect) -> CGFloat {
        let dx = max(0, max(other.minX - maxX, minX - other.maxX))
        let dy = max(0, max(other.minY - maxY, minY - other.maxY))
        return sqrt(dx * dx + dy * dy)
    }
}

enum OCRError: LocalizedError {
    case unknownFileType
    case unsupportedFileType
    case couldNotLoadPDF
    case couldNotLoadImage
    case couldNotProcessImageData

    var errorDescription: String? {
        switch self {
        case .unknownFileType: return "Could not determine file type."
        case .unsupportedFileType: return "File type not supported for OCR."
        case .couldNotLoadPDF: return "Could not load PDF document."
        case .couldNotLoadImage: return "Could not load image file."
        case .couldNotProcessImageData: return "Could not process image data."
        }
    }
}
