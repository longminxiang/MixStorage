//
//  MixStorage.swift
//  MixStorage
//
//  Created by Eric Long on 2022/9/27.
//

import Foundation

class Storage {

    enum Mode {
        case file, userDefaults, keychain
    }

    struct Key {
        var rawValue: String

        init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    private static let shared = Storage()

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

    static func set<T: Encodable>(_ key: Key, value: T, mode: Storage.Mode = .file) {
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

    static func get<T: Decodable>(_ key: Key, valueType: T.Type, mode: Storage.Mode = .file) -> T? {
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


@propertyWrapper struct Storable<Value: Codable> {

    private class ValueRef<Value: Codable> {
        var value: Value

        init(_ value: Value) {
            self.value = value
        }
    }

    private var ref: ValueRef<Value>
    let key: Storage.Key
    let mode: Storage.Mode
    var projectedValue: Self { self }

    var wrappedValue: Value {
        get { ref.value }
        nonmutating set {
            ref.value = newValue
            Storage.set(key, value: ref.value, mode: mode)
        }
    }

    init(wrappedValue: Value, key: Storage.Key, mode: Storage.Mode = .file) {
        self.ref = ValueRef(wrappedValue)
        self.key = key
        self.mode = mode
        if let value = Storage.get(key, valueType: Value.self, mode: mode) {
            ref.value = value
        }
    }
}
