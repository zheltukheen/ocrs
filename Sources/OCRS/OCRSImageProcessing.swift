import Accelerate
import CoreGraphics

enum OCRSImageProcessing {
    // Max working dimension to keep OCR latency reasonable on large captures.
    static let maxWorkingDimension: CGFloat = 2600
    private static let minPreprocessArea = 800 * 800

    // Downscale large images using vImage for speed and predictable quality.
    static func downscaleIfNeeded(_ cgImage: CGImage) -> (image: CGImage, scale: CGFloat) {
        let maxDim = max(cgImage.width, cgImage.height)
        guard maxDim > Int(maxWorkingDimension) else {
            return (cgImage, 1.0)
        }

        let scale = maxWorkingDimension / CGFloat(maxDim)
        let destWidth = max(1, Int(CGFloat(cgImage.width) * scale))
        let destHeight = max(1, Int(CGFloat(cgImage.height) * scale))

        guard let scaled = vImageScale(cgImage, width: destWidth, height: destHeight) else {
            return (cgImage, 1.0)
        }
        return (scaled, scale)
    }

    // Lightweight preprocessing (contrast stretch + sharpen) for OCR readiness.
    static func preprocessIfNeeded(_ cgImage: CGImage) -> CGImage {
        let area = cgImage.width * cgImage.height
        guard area >= minPreprocessArea else { return cgImage }
        guard let processed = vImageContrastAndSharpen(cgImage) else { return cgImage }
        return processed
    }

    // High-quality resize with vImage.
    private static func vImageScale(_ cgImage: CGImage, width: Int, height: Int) -> CGImage? {
        var format = argbFormat()
        defer { format.colorSpace?.release() }
        var source = vImage_Buffer()
        var error = vImageBuffer_InitWithCGImage(&source, &format, nil, cgImage, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        defer { free(source.data) }

        var dest = vImage_Buffer()
        error = vImageBuffer_Init(&dest, vImagePixelCount(height), vImagePixelCount(width), format.bitsPerPixel, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }

        error = vImageScale_ARGB8888(&source, &dest, nil, vImage_Flags(kvImageHighQualityResampling))
        guard error == kvImageNoError else {
            free(dest.data)
            return nil
        }

        var outError: vImage_Error = kvImageNoError
        let result = vImageCreateCGImageFromBuffer(
            &dest,
            &format,
            { _, data in free(data) },
            nil,
            vImage_Flags(kvImageNoAllocate),
            &outError
        )

        if outError != kvImageNoError {
            free(dest.data)
            return nil
        }

        return result?.takeRetainedValue()
    }

    // Fast contrast stretch + mild sharpening using vImage.
    private static func vImageContrastAndSharpen(_ cgImage: CGImage) -> CGImage? {
        var format = argbFormat()
        defer { format.colorSpace?.release() }
        var source = vImage_Buffer()
        var error = vImageBuffer_InitWithCGImage(&source, &format, nil, cgImage, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        defer { free(source.data) }

        var dest = vImage_Buffer()
        error = vImageBuffer_Init(&dest, vImagePixelCount(source.height), vImagePixelCount(source.width), format.bitsPerPixel, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }

        error = vImageContrastStretch_ARGB8888(&source, &dest, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else {
            free(dest.data)
            return nil
        }

        var sharpened = vImage_Buffer()
        error = vImageBuffer_Init(&sharpened, vImagePixelCount(source.height), vImagePixelCount(source.width), format.bitsPerPixel, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else {
            free(dest.data)
            return nil
        }

        // 3x3 sharpen kernel: enhances edges without heavy halos.
        let kernel: [Int16] = [
            0, -1, 0,
            -1, 5, -1,
            0, -1, 0
        ]
        error = vImageConvolve_ARGB8888(
            &dest,
            &sharpened,
            nil,
            0,
            0,
            kernel,
            3,
            3,
            1,
            nil,
            vImage_Flags(kvImageEdgeExtend)
        )
        free(dest.data)
        guard error == kvImageNoError else {
            free(sharpened.data)
            return nil
        }

        var outError: vImage_Error = kvImageNoError
        let result = vImageCreateCGImageFromBuffer(
            &sharpened,
            &format,
            { _, data in free(data) },
            nil,
            vImage_Flags(kvImageNoAllocate),
            &outError
        )

        if outError != kvImageNoError {
            free(sharpened.data)
            return nil
        }

        return result?.takeRetainedValue()
    }

    private static func argbFormat() -> vImage_CGImageFormat {
        vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: Unmanaged.passRetained(CGColorSpaceCreateDeviceRGB()),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )
    }
}
