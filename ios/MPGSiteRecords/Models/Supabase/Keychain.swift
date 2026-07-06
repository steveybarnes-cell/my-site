import Foundation
import Security

/// Minimal Keychain wrapper for persisting the Supabase session between launches.
/// Tokens are secrets, so they live here rather than in UserDefaults.
enum Keychain {
  private static let service = "com.myprojectgroup.mpgsiterecords.auth"

  static func set(_ data: Data, for key: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)

    var attributes = query
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(attributes as CFDictionary, nil)
  }

  static func set(_ string: String, for key: String) {
    set(Data(string.utf8), for: key)
  }

  static func data(for key: String) -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess else { return nil }
    return result as? Data
  }

  static func string(for key: String) -> String? {
    guard let data = data(for: key) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func remove(_ key: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
  }
}
