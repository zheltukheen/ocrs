import Foundation
import AppKit

enum OCRSDebug {
    static let enabled: Bool = false
    static let outputDir: URL = URL(fileURLWithPath: "/tmp/ocrs_debug", isDirectory: true)
    static let logFile: URL = outputDir.appendingPathComponent("debug.log")

    static func log(_ message: String) {
        guard enabled else { return }
        print("[OCRS][Debug] \(message)")
        appendToLogFile("[OCRS][Debug] \(message)\n")
    }

    static func prepareOutputDir() {
        guard enabled else { return }
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: outputDir.path) {
                let files = try fm.contentsOfDirectory(atPath: outputDir.path)
                for file in files {
                    let url = outputDir.appendingPathComponent(file)
                    try? fm.removeItem(at: url)
                }
            } else {
                try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
            }
        } catch {
            log("Failed to prepare debug directory: \(error.localizedDescription)")
        }
    }

    static func save(_ image: CGImage, name: String) {
        guard enabled else { return }
        let safeName = sanitize(name)
        let url = outputDir.appendingPathComponent(safeName).appendingPathExtension("png")
        let rep = NSBitmapImageRep(cgImage: image)
        if let data = rep.representation(using: .png, properties: [:]) {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                log("Failed to write debug image \(safeName): \(error.localizedDescription)")
            }
        } else {
            log("Failed to encode debug image \(safeName)")
        }
    }

    private static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let filtered = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(filtered)
    }

    private static func appendToLogFile(_ text: String) {
        guard enabled else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: outputDir.path) {
            try? fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
        }
        let data = Data(text.utf8)
        if fm.fileExists(atPath: logFile.path) {
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                try? handle.write(contentsOf: data)
                try? handle.close()
            }
        } else {
            try? data.write(to: logFile, options: .atomic)
        }
    }
}
