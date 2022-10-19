//
//  MixStorage.swift
//  MixStorage
//
//  Created by Eric Long on 2022/9/27.
//

import Foundation

/// Storage
///
/// Set storage
/// ```swift
/// MixStorage.set(.init("akey"), value: "keyvalue", mode: .keychain)
/// ```
///
/// Get storage
/// ```swift
/// let str = MixStorage.get(.init("akey"), valueType: String.self, mode: .keychain)
/// ```
public class MixStorage {

    /// Storage Mode
    public enum Mode {
        /// File mode
        case file
        /// NSUserDefaults mode
        case userDefaults

        /// Keychain mode
        case keychain
    }

    /// Storage Key
    ///
    /// Extension
    /// ```swift
    /// extension MixStorage.Key {
    ///     static var akey: Self { .init("akey") }
    /// }
    ///
    /// MixStorage.set(.akey, value: "keyvalue")
    /// ```
    public struct Key {
        public var rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    private static let shared = MixStorage()

    private var _fileDirectory: URL?
    private var fileDirectory: URL {
        if let dir = _fileDirectory { return dir }
        let cacheDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last!
        let bundleId = Bundle.main.infoDictionary!["CFBundleIdentifier"] as! String
        let dir = URL(fileURLWithPath: "\(cacheDirectory)/\(bundleId).Storage")
        debugPrint(dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        _fileDirectory = dir
        return dir
    }
    private var fileCache: [String: Data] = [:]

    private let keychainLock = NSLock()

    /// Set value to storage
    ///
    /// - Parameter key: The Storage Key.
    /// - Parameter value: A ``Encodable`` Value.
    /// - Parameter mode: The Storage Mode.
    public static func set<T: Encodable>(_ key: Key, value: T, mode: Mode = .file) {
        let data = (try? JSONEncoder().encode(value)) ?? Data()
        let rawKey = key.rawValue
        switch mode {
        case .userDefaults:
            UserDefaults.standard.set(data, forKey: rawKey)
            UserDefaults.standard.synchronize()
        case .keychain:
            shared.keychainLock.lock()
            defer { shared.keychainLock.unlock() }
            let deleteQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: rawKey
            ]
            SecItemDelete(deleteQuery as CFDictionary)

            let query: [CFString : Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: rawKey,
                kSecValueData: data,
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked
            ]
            SecItemAdd(query as CFDictionary, nil)
        case .file:
            do {
                try data.write(to: shared.fileDirectory.appendingPathComponent(rawKey))
            }
            catch {
                debugPrint(error)
            }
            shared.fileCache[rawKey] = data
        }
    }

    /// Get value from storage
    ///
    /// - Parameter key: The Storage Key.
    /// - Parameter valueType: The Value Type.
    /// - Parameter mode: The Storage Mode.
    /// - Returns: A ``Decodable`` Value.
    public static func get<T: Decodable>(_ key: Key, valueType: T.Type, mode: Mode = .file) -> T? {
        let rawKey = key.rawValue
        var data: Data?
        switch mode {
        case .userDefaults:
            data = UserDefaults.standard.data(forKey: rawKey)
        case .keychain:
            shared.keychainLock.lock()
            defer { shared.keychainLock.unlock() }
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: rawKey,
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnData: kCFBooleanTrue as Any
            ]
            var result: AnyObject?
            let code = withUnsafeMutablePointer(to: &result) {
                SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
            }
            data = code == noErr ? result as? Data : nil
        case .file:
            data = shared.fileCache[rawKey]
            if data == nil {
                data = try? Data(contentsOf: shared.fileDirectory.appendingPathComponent(rawKey))
                if data != nil {
                    shared.fileCache[rawKey] = data
                }
            }
        }
        guard let data = data else { return nil }
        let obj = try? JSONDecoder().decode(valueType, from: data)
        return obj
    }
}

/// Storable PropertyWrapper
///
/// Usage
/// ```swift
/// @MixStorable(wrappedValue: nil, key: .init("username_storage"), mode: .keychain)
/// var username: String?
/// ```
///
/// ```swift
/// @MixStorable(wrappedValue: "defaultUsername", key: .init("username_storage"))
/// var username: String
/// ```
///
@propertyWrapper public struct MixStorable<Value: Codable> {

    private class ValueRef<Value: Codable> {
        var value: Value

        init(_ value: Value) {
            self.value = value
        }
    }
    
    public typealias ValueDidSet = (_ value: Value) -> Void

    private var ref: ValueRef<Value>
    private var valueDidSet: ValueDidSet?
    /// Key
    public let key: MixStorage.Key
    /// Mode
    public let mode: MixStorage.Mode
    /// A binding to the self, use with (`$`)
    public var projectedValue: Self { self }

    /// Wrapped value
    public var wrappedValue: Value {
        get { ref.value }
        nonmutating set {
            ref.value = newValue
            MixStorage.set(key, value: ref.value, mode: mode)
            valueDidSet?(newValue)
        }
    }

    /// Init
    public init(wrappedValue: Value, key: MixStorage.Key, mode: MixStorage.Mode = .file, didSet: ValueDidSet? = nil) {
        self.ref = ValueRef(wrappedValue)
        self.key = key
        self.mode = mode
        self.valueDidSet = didSet
        if let value = MixStorage.get(key, valueType: Value.self, mode: mode) {
            self.ref.value = value
        }
        else {
            self.wrappedValue = wrappedValue
        }
    }
}
