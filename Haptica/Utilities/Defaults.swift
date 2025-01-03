//
//  Defaults.swift
//  Haptica
//
//  Created by Nozhan Amiri on 1/3/25.
//

import SwiftUI

@propertyWrapper
struct Defaults<V>: DynamicProperty where V: Codable {
    private let store: UserDefaults
    private let key: String
    
    var wrappedValue: V {
        get {
            if V.self == String.self {
                guard let stringValue = store.string(forKey: key) else {
                    fatalError("Failed to read string from UserDefaults store \(store)")
                }
                return stringValue as! V
            } else if V.self == Int.self {
                let intValue = store.integer(forKey: key)
                return intValue as! V
            } else if V.self == Double.self {
                let doubleValue = store.double(forKey: key)
                return doubleValue as! V
            } else if V.self == Bool.self {
                let boolValue = store.bool(forKey: key)
                return boolValue as! V
            }
            
            guard let data = store.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(V.self, from: data) else {
                fatalError("Failed to read value from UserDefaults store \(store)")
            }
            return decoded
        }
        nonmutating set {
            if [String.self, Int.self, Double.self, Bool.self].contains(where: { $0 == V.self }) {
                store.set(newValue, forKey: key)
                return
            }
            
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
    
    var projectedValue: Binding<V> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
    
    init(wrappedValue: V, _ key: String, store: UserDefaults = .standard) {
        self.store = store
        self.key = key
        if let data = try? JSONEncoder().encode(wrappedValue) {
            store.set(data, forKey: key)
        }
    }
    
    init(wrappedValue: V, _ key: UserDefaultsKey, store: UserDefaults = .standard) {
        self.store = store
        self.key = key.rawValue
        if let data = try? JSONEncoder().encode(wrappedValue) {
            store.set(data, forKey: key.rawValue)
        }
    }
    
    static subscript(key: String, store: UserDefaults = .standard) -> V? {
        get {
            if V.self == String.self {
                guard let stringValue = store.string(forKey: key) else { return nil }
                return stringValue as? V
            } else if V.self == Int.self {
                let intValue = store.integer(forKey: key)
                return intValue as? V
            } else if V.self == Double.self {
                let doubleValue = store.double(forKey: key)
                return doubleValue as? V
            } else if V.self == Bool.self {
                let boolValue = store.bool(forKey: key)
                return boolValue as? V
            }
            
            guard let data = store.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(V.self, from: data) else { return nil }
            return decoded
        }
        set {
            if [String.self, Int.self, Double.self, Bool.self].contains(where: { $0 == V.self }) {
                store.set(newValue, forKey: key)
                return
            }
            
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
    
    static subscript(key: UserDefaultsKey, store: UserDefaults = .standard) -> V? {
        get {
            guard let data = store.data(forKey: key.rawValue),
                  let decoded = try? JSONDecoder().decode(V.self, from: data) else { return nil }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key.rawValue)
        }
    }
}

enum UserDefaultsKey: String {
    case shouldShowOnboarding
    case myName
}
