import Foundation
import Security

/// OpenAI-Schlüssel im Schlüsselbund. Er landet nicht in config.json.
enum OpenAIKeyStore {
    private static let service = "de.sinthex.flow"
    /// Früherer Schlüsselbund-Name. Wird einmal gelesen und danach gelöscht.
    private static let legacyService = "de.dietergeschaeft.Flow"
    private static let account = "openai-api-key"

    static func load() -> String {
        if SnapshotMode.isActive { return "" }
        if let value = read(service: service) { return value }
        guard let legacy = read(service: legacyService) else { return "" }
        write(legacy, service: service)
        delete(service: legacyService)
        return legacy
    }

    static func save(_ raw: String) {
        if SnapshotMode.isActive { return }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value == load() { return }
        delete(service: service)
        guard !value.isEmpty else { return }
        write(value, service: service)
    }

    private static func read(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        let value = String(data: data, encoding: .utf8) ?? ""
        return value.isEmpty ? nil : value
    }

    private static func write(_ value: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func delete(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
