import Foundation
import LocalAuthentication
import Security
import Observation
import CareCore
import UIKit

@MainActor enum PrivacyShield {
    private static let tag = 917_204_061
    static func setVisible(_ visible: Bool) {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows where window.windowLevel == .normal {
                if !visible { window.viewWithTag(tag)?.removeFromSuperview(); continue }
                guard window.viewWithTag(tag) == nil else { continue }
                let shield = UIView(frame: window.bounds); shield.tag = tag
                shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]; shield.backgroundColor = .systemGroupedBackground
                let label = UILabel(); label.text = "CareInOne"; label.font = .preferredFont(forTextStyle: .title2); label.textAlignment = .center
                label.translatesAutoresizingMaskIntoConstraints = false; shield.addSubview(label)
                NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: shield.centerXAnchor), label.centerYAnchor.constraint(equalTo: shield.centerYAnchor)])
                window.addSubview(shield)
            }
        }
    }
}

struct BackendCredentials: Codable { var endpoint: String; var token: String }
enum KeychainStore {
    static var backend: BackendCredentials {
        if let value = try? JSONDecoder().decode(BackendCredentials.self,from:Data(get("backendCredentials").utf8)) { return value }
        return BackendCredentials(endpoint:get("backendURL"),token:get("backendToken"))
    }
    static func saveBackend(endpoint:String,token:String) throws {
        let value = try JSONEncoder().encode(BackendCredentials(endpoint:endpoint,token:token))
        // One Keychain update keeps the credential paired with its intended endpoint.
        try set(String(decoding:value,as:UTF8.self),key:"backendCredentials")
        try set("",key:"backendURL"); try set("",key:"backendToken")
    }
    static func eraseBackend() throws {
        try set("",key:"backendCredentials"); try set("",key:"backendURL"); try set("",key:"backendToken")
    }
    static func set(_ value: String, key: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "CareContinuity", kSecAttrAccount as String: key]
        guard !value.isEmpty else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw CareError.invalid("Could not remove saved credentials (\(status)).") }; return
        }
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: Data(value.utf8)] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw CareError.invalid("Could not update credentials securely (\(update)).") }
        var item = query; item[kSecValueData as String] = Data(value.utf8); item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw CareError.invalid("Could not save credentials securely (\(status)).") }
    }
    static func get(_ key: String) -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "CareContinuity", kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?; guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
@MainActor @Observable final class AppLock {
    var unlocked = false
    var message = ""
    var authenticating = false
    func authenticate() async -> Bool {
        guard !authenticating else { return false }; authenticating = true; defer { authenticating = false }
        let context = LAContext(); context.localizedCancelTitle = "Keep locked"
        do {
            let accepted = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Open your saved care information")
            unlocked = accepted; message = ""; return accepted
        } catch { message = "Unlock was not completed. You can try again using Face ID, Touch ID, or your device passcode."; return false }
    }
}
