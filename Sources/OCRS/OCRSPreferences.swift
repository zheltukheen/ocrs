import Foundation

enum OCRSPreferenceKey {
    static let outputMode = "ocrs_output_mode"
    static let shortcutData = "ocrs_shortcut"
    static let accuracyMode = "ocrs_accuracy_mode"
    static let languageMode = "ocrs_language_mode"
}

enum OCRSOutputMode: String, CaseIterable, Identifiable {
    case copy
    case popup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copy: return "Copy to Clipboard"
        case .popup: return "Show Popup"
        }
    }
}

enum OCRSAccuracyMode: String, CaseIterable, Identifiable {
    case standard
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .high: return "High Accuracy (slower)"
        }
    }
}

enum OCRSLanguageMode: String, CaseIterable, Identifiable {
    case auto
    case system
    case english
    case russian

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto Detect"
        case .system: return "System Languages"
        case .english: return "English"
        case .russian: return "Russian"
        }
    }

    var bcp47: [String] {
        switch self {
        case .auto: return []
        case .system: return Locale.preferredLanguages
        case .english: return ["en-US"]
        case .russian: return ["ru-RU"]
        }
    }
}
