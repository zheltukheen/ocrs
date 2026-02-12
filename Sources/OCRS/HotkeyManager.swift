import Foundation

final class HotkeyManager: ObservableObject {
    @Published var shortcut: SavedShortcut? {
        didSet {
            saveShortcut()
            registerHotkey()
        }
    }

    var onTrigger: (() -> Void)?

    private var hotKey: GlobalHotKey?

    init() {
        shortcut = ShortcutStorage.load()
        registerHotkey()
    }

    private func registerHotkey() {
        hotKey = nil
        guard let shortcut else { return }
        hotKey = GlobalHotKey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
            self?.onTrigger?()
        }
    }

    private func saveShortcut() {
        ShortcutStorage.save(shortcut)
    }
}

enum ShortcutStorage {
    static func load() -> SavedShortcut? {
        guard let data = UserDefaults.standard.data(forKey: OCRSPreferenceKey.shortcutData) else { return nil }
        return try? JSONDecoder().decode(SavedShortcut.self, from: data)
    }

    static func save(_ shortcut: SavedShortcut?) {
        if let shortcut {
            let data = try? JSONEncoder().encode(shortcut)
            UserDefaults.standard.set(data, forKey: OCRSPreferenceKey.shortcutData)
        } else {
            UserDefaults.standard.removeObject(forKey: OCRSPreferenceKey.shortcutData)
        }
    }
}
