import UIKit
import Vision

struct ClosetItemPhotoPersistence {
    static func jpegData(from image: UIImage) -> Data? {
        normalizedImage(from: image).jpegData(compressionQuality: 0.86)
    }

    static func normalizedJPEGData(from data: Data) -> Data? {
        processedPhotoData(from: data)?.displayJPEGData
    }

    static func processedPhotoData(from data: Data) -> ProcessedClosetPhotoData? {
        guard let image = UIImage(data: data) else { return nil }
        return processedPhotoData(from: image)
    }

    static func processedPhotoData(from image: UIImage) -> ProcessedClosetPhotoData? {
        let originalImage = normalizedImage(from: image)
        guard let originalJPEGData = originalImage.jpegData(compressionQuality: 0.9) else { return nil }

        let displayImage = ClothingPhotoProcessor.autoCroppedDisplayImage(from: originalImage)
        guard let displayJPEGData = displayImage.jpegData(compressionQuality: 0.86) else { return nil }

        return ProcessedClosetPhotoData(
            displayJPEGData: displayJPEGData,
            originalJPEGData: originalJPEGData
        )
    }

    static func stageJPEGData(_ data: Data, id: UUID, imageStore: ImageStore) throws -> StagedPhotoWrite {
        try stageJPEGData(
            data,
            stagingDirectory: imageStore.baseDirectory,
            finalURL: imageStore.baseDirectory.appendingPathComponent("\(id.uuidString).jpg")
        )
    }

    static func stagePhotoData(_ data: ProcessedClosetPhotoData, id: UUID, imageStore: ImageStore) throws -> StagedPhotoDataWrite {
        let displayWrite = try stageJPEGData(data.displayJPEGData, id: id, imageStore: imageStore)
        do {
            let originalsDirectory = imageStore.baseDirectory.appendingPathComponent("Originals", isDirectory: true)
            let originalWrite = try stageJPEGData(
                data.originalJPEGData,
                stagingDirectory: originalsDirectory,
                finalURL: originalsDirectory.appendingPathComponent("\(id.uuidString).jpg")
            )
            return StagedPhotoDataWrite(display: displayWrite, original: originalWrite)
        } catch {
            displayWrite.discard()
            throw error
        }
    }

    static func removeLocalPhotos(for item: ClothingItem) {
        removePhoto(at: item.photoLocalPath)
        removePhoto(at: item.originalPhotoLocalPath)
    }

    private static func stageJPEGData(_ data: Data, stagingDirectory: URL, finalURL: URL) throws -> StagedPhotoWrite {
        try FileManager.default.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )

        let stagingURL = stagingDirectory
            .appendingPathComponent("\(finalURL.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).staged.jpg")
        try data.write(to: stagingURL, options: [.atomic])

        return StagedPhotoWrite(stagingURL: stagingURL, finalURL: finalURL)
    }

    private static func normalizedImage(from image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func removePhoto(at path: String) {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              FileManager.default.fileExists(atPath: path) else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
}

struct ProcessedClosetPhotoData {
    let displayJPEGData: Data
    let originalJPEGData: Data
}

struct ClothingPhotoProcessor {
    static func autoCroppedDisplayImage(from image: UIImage) -> UIImage {
        if let foregroundImage = visionForegroundDisplayImage(in: image) {
            return foregroundImage
        }

        guard let cropRect = visionForegroundCropRect(in: image)
                ?? centeredGarmentCropRect(in: image)
                ?? saliencyCropRect(in: image)
                ?? foregroundCropRect(in: image) else { return image }
        return croppedImage(from: image, cropRect: cropRect)
    }

    private static func croppedImage(from image: UIImage, cropRect: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: cropRect.size, format: format).image { _ in
            image.draw(
                in: CGRect(
                    x: -cropRect.origin.x,
                    y: -cropRect.origin.y,
                    width: image.size.width,
                    height: image.size.height
                )
            )
        }
    }

    private static func visionForegroundDisplayImage(in image: UIImage) -> UIImage? {
        guard #available(iOS 17.0, *),
              let cgImage = image.cgImage else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first,
              let instances = bestForegroundInstances(in: observation, handler: handler, sourceSize: image.size),
              let maskedBuffer = try? observation.generateMaskedImage(
                ofInstances: instances,
                from: handler,
                croppedToInstancesExtent: true
              ) else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: maskedBuffer)
        let context = CIContext()
        guard let maskedCGImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        let maskedImage = UIImage(cgImage: maskedCGImage, scale: image.scale, orientation: .up)
        return compositedForegroundImage(maskedImage)
    }

    private static func compositedForegroundImage(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func visionForegroundCropRect(in image: UIImage) -> CGRect? {
        guard #available(iOS 17.0, *),
              let cgImage = image.cgImage else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first,
              let instances = bestForegroundInstances(in: observation, handler: handler, sourceSize: image.size),
              let maskBuffer = try? observation.generateScaledMaskForImage(
                forInstances: instances,
                from: handler
              ),
              let bestRect = maskBoundingRect(maskBuffer, sourceSize: image.size) else { return nil }

        return paddedValidCropRect(bestRect, sourceSize: image.size, paddingRatio: 0.06)
    }

    @available(iOS 17.0, *)
    private static func bestForegroundInstances(
        in observation: VNInstanceMaskObservation,
        handler: VNImageRequestHandler,
        sourceSize: CGSize
    ) -> IndexSet? {
        var bestRect: CGRect?
        var bestScore = 0.0
        var bestInstances: IndexSet?

        for instance in observation.allInstances {
            let selectedInstances = IndexSet(integer: instance)
            guard let maskBuffer = try? observation.generateScaledMaskForImage(
                forInstances: selectedInstances,
                from: handler
            ),
                let rect = maskBoundingRect(maskBuffer, sourceSize: sourceSize) else {
                continue
            }

            let center = CGPoint(x: rect.midX / sourceSize.width, y: rect.midY / sourceSize.height)
            let centerDistance = hypot(center.x - 0.5, center.y - 0.48)
            let sourceArea = sourceSize.width * sourceSize.height
            let areaRatio = (rect.width * rect.height) / sourceArea
            guard areaRatio > 0.04, areaRatio < 0.92 else { continue }

            let centerWeight = max(0.35, 1.35 - centerDistance)
            let score = Double(areaRatio) * centerWeight
            if score > bestScore {
                bestScore = score
                bestRect = rect
                bestInstances = selectedInstances
            }
        }

        guard bestRect != nil else { return nil }
        return bestInstances
    }

    private static func maskBoundingRect(_ pixelBuffer: CVPixelBuffer, sourceSize: CGSize) -> CGRect? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var count = 0

        for y in 0..<height {
            for x in 0..<width {
                if maskPixelIsForeground(
                    baseAddress: baseAddress,
                    pixelFormat: pixelFormat,
                    bytesPerRow: bytesPerRow,
                    x: x,
                    y: y
                ) {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                    count += 1
                }
            }
        }

        guard count > max(24, (width * height) / 600),
              minX <= maxX,
              minY <= maxY else { return nil }

        let scaleX = sourceSize.width / CGFloat(width)
        let scaleY = sourceSize.height / CGFloat(height)
        return CGRect(
            x: CGFloat(minX) * scaleX,
            y: CGFloat(minY) * scaleY,
            width: CGFloat(maxX - minX + 1) * scaleX,
            height: CGFloat(maxY - minY + 1) * scaleY
        )
    }

    private static func maskPixelIsForeground(
        baseAddress: UnsafeMutableRawPointer,
        pixelFormat: OSType,
        bytesPerRow: Int,
        x: Int,
        y: Int
    ) -> Bool {
        let row = baseAddress.advanced(by: y * bytesPerRow)
        switch pixelFormat {
        case kCVPixelFormatType_OneComponent8:
            return row.load(fromByteOffset: x, as: UInt8.self) > 12
        case kCVPixelFormatType_OneComponent32Float:
            return row.load(fromByteOffset: x * MemoryLayout<Float>.stride, as: Float.self) > 0.04
        default:
            return row.load(fromByteOffset: x, as: UInt8.self) > 12
        }
    }

    private static func saliencyCropRect(in image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first,
              let objects = observation.salientObjects,
              !objects.isEmpty else {
            return nil
        }

        let unionBox = objects
            .map(\.boundingBox)
            .reduce(CGRect.null) { $0.union($1) }
        guard !unionBox.isNull, !unionBox.isEmpty else { return nil }

        let width = image.size.width
        let height = image.size.height
        let convertedRect = CGRect(
            x: unionBox.minX * width,
            y: (1 - unionBox.maxY) * height,
            width: unionBox.width * width,
            height: unionBox.height * height
        )
        return paddedValidCropRect(convertedRect, sourceSize: image.size, paddingRatio: 0.08)
    }

    private static func centeredGarmentCropRect(in image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        let maxSampleDimension = 220
        let sourceWidth = cgImage.width
        let sourceHeight = cgImage.height
        guard sourceWidth > 2, sourceHeight > 2 else { return nil }

        let scale = min(1, CGFloat(maxSampleDimension) / CGFloat(max(sourceWidth, sourceHeight)))
        let width = max(2, Int(CGFloat(sourceWidth) * scale))
        let height = max(2, Int(CGFloat(sourceHeight) * scale))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let background = averageCornerColor(in: pixels, width: width, height: height, bytesPerRow: bytesPerRow)
        var mask = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = pixels[offset + 3]
                guard alpha > 20 else { continue }

                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                let difference = abs(red - background.red)
                    + abs(green - background.green)
                    + abs(blue - background.blue)
                let brightness = max(red, green, blue)
                let saturation = brightness == 0 ? 0 : Double(brightness - min(red, green, blue)) / Double(brightness)
                let isLikelyGarment = difference > 58 && !(brightness > 236 && saturation < 0.16)
                mask[y * width + x] = isLikelyGarment
            }
        }

        var visited = [Bool](repeating: false, count: width * height)
        var bestComponent: (score: Double, count: Int, minX: Int, minY: Int, maxX: Int, maxY: Int)?
        let minimumComponentPixels = max(24, (width * height) / 900)

        for index in mask.indices where mask[index] && !visited[index] {
            var stack = [index]
            visited[index] = true
            var count = 0
            var sumX = 0
            var sumY = 0
            var minX = width
            var minY = height
            var maxX = 0
            var maxY = 0

            while let current = stack.popLast() {
                let x = current % width
                let y = current / width
                count += 1
                sumX += x
                sumY += y
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)

                let neighbors = [
                    x > 0 ? current - 1 : nil,
                    x < width - 1 ? current + 1 : nil,
                    y > 0 ? current - width : nil,
                    y < height - 1 ? current + width : nil
                ].compactMap { $0 }

                for neighbor in neighbors where mask[neighbor] && !visited[neighbor] {
                    visited[neighbor] = true
                    stack.append(neighbor)
                }
            }

            guard count >= minimumComponentPixels else { continue }
            let centroidX = Double(sumX) / Double(count) / Double(width)
            let centroidY = Double(sumY) / Double(count) / Double(height)
            let centerDistance = hypot(centroidX - 0.5, centroidY - 0.48)
            let widthRatio = Double(maxX - minX + 1) / Double(width)
            let heightRatio = Double(maxY - minY + 1) / Double(height)
            guard widthRatio > 0.12, heightRatio > 0.16 else { continue }

            let score = Double(count) * max(0.25, 1.25 - centerDistance)
            if bestComponent == nil || score > bestComponent!.score {
                bestComponent = (score, count, minX, minY, maxX, maxY)
            }
        }

        guard let bestComponent else { return nil }
        let scaleX = image.size.width / CGFloat(width)
        let scaleY = image.size.height / CGFloat(height)
        let detectedRect = CGRect(
            x: CGFloat(bestComponent.minX) * scaleX,
            y: CGFloat(bestComponent.minY) * scaleY,
            width: CGFloat(bestComponent.maxX - bestComponent.minX + 1) * scaleX,
            height: CGFloat(bestComponent.maxY - bestComponent.minY + 1) * scaleY
        )
        return paddedValidCropRect(detectedRect, sourceSize: image.size, paddingRatio: 0.10)
    }

    private static func foregroundCropRect(in image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 2, height > 2 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let background = averageCornerColor(in: pixels, width: width, height: height, bytesPerRow: bytesPerRow)
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var foregroundCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = pixels[offset + 3]
                guard alpha > 20 else { continue }

                let difference = abs(Int(pixels[offset]) - background.red)
                    + abs(Int(pixels[offset + 1]) - background.green)
                    + abs(Int(pixels[offset + 2]) - background.blue)
                if difference > 75 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                    foregroundCount += 1
                }
            }
        }

        guard foregroundCount > max(16, (width * height) / 300) else { return nil }

        let cropWidth = maxX - minX + 1
        let cropHeight = maxY - minY + 1
        let sourceArea = width * height
        let cropArea = cropWidth * cropHeight
        guard cropArea < Int(Double(sourceArea) * 0.92) else { return nil }

        let scaleX = image.size.width / CGFloat(width)
        let scaleY = image.size.height / CGFloat(height)
        let detectedRect = CGRect(
            x: CGFloat(minX) * scaleX,
            y: CGFloat(minY) * scaleY,
            width: CGFloat(cropWidth) * scaleX,
            height: CGFloat(cropHeight) * scaleY
        )
        return paddedValidCropRect(detectedRect, sourceSize: image.size, paddingRatio: 0.14)
    }

    private static func paddedValidCropRect(_ rect: CGRect, sourceSize: CGSize, paddingRatio: CGFloat) -> CGRect? {
        guard sourceSize.width > 2, sourceSize.height > 2 else { return nil }

        let paddingX = max(2, rect.width * paddingRatio)
        let paddingY = max(2, rect.height * paddingRatio)
        let paddedRect = rect
            .insetBy(dx: -paddingX, dy: -paddingY)
            .intersection(CGRect(origin: .zero, size: sourceSize))
            .integral

        guard paddedRect.width > 8, paddedRect.height > 8 else { return nil }

        let sourceArea = sourceSize.width * sourceSize.height
        let cropArea = paddedRect.width * paddedRect.height
        guard cropArea < sourceArea * 0.94, cropArea > sourceArea * 0.04 else { return nil }

        return paddedRect
    }

    private static func averageCornerColor(in pixels: [UInt8], width: Int, height: Int, bytesPerRow: Int) -> (red: Int, green: Int, blue: Int) {
        let sampleSize = max(1, min(width, height, 12))
        let origins = [
            (x: 0, y: 0),
            (x: width - sampleSize, y: 0),
            (x: 0, y: height - sampleSize),
            (x: width - sampleSize, y: height - sampleSize)
        ]
        var red = 0
        var green = 0
        var blue = 0
        var count = 0

        for origin in origins {
            for y in origin.y..<(origin.y + sampleSize) {
                for x in origin.x..<(origin.x + sampleSize) {
                    let offset = y * bytesPerRow + x * 4
                    red += Int(pixels[offset])
                    green += Int(pixels[offset + 1])
                    blue += Int(pixels[offset + 2])
                    count += 1
                }
            }
        }

        return (red / count, green / count, blue / count)
    }
}

struct StagedPhotoWrite {
    let stagingURL: URL
    let finalURL: URL

    func commit() throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: finalURL.path) {
            let backupURL = finalURL.deletingLastPathComponent()
                .appendingPathComponent("\(finalURL.deletingPathExtension().lastPathComponent)-backup-\(UUID().uuidString).jpg")
            try fileManager.moveItem(at: finalURL, to: backupURL)
            do {
                try fileManager.moveItem(at: stagingURL, to: finalURL)
                try? fileManager.removeItem(at: backupURL)
            } catch {
                try? fileManager.moveItem(at: backupURL, to: finalURL)
                throw error
            }
        } else {
            try fileManager.moveItem(at: stagingURL, to: finalURL)
        }
    }

    func discard() {
        try? FileManager.default.removeItem(at: stagingURL)
    }
}

struct StagedPhotoDataWrite {
    let display: StagedPhotoWrite
    let original: StagedPhotoWrite

    func commit() throws {
        try original.commit()
        try display.commit()
    }

    func discard() {
        display.discard()
        original.discard()
    }
}
