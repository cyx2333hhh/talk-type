import Foundation
import Security

/// Stores each provider's API key in the login keychain as a generic password.
enum KeychainHelper {
    private static let service = "com.leon.Murmur"

    static func save(_ value: String, for provider: AIProvider) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider),
        ]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return }
        var attrs = base
        attrs[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load(for provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Compatibility helpers for older callers. Existing DeepSeek keys use
    /// the same account name as the new provider-specific storage.
    static func save(_ value: String) {
        save(value, for: .deepSeek)
    }

    static func load() -> String? {
        load(for: .deepSeek)
    }

    private static func account(for provider: AIProvider) -> String {
        "\(provider.rawValue)-api-key"
    }
}
