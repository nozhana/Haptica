//
//  Dictionary+Extension.swift
//  Haptica
//
//  Created by Nozhan Amiri on 12/31/24.
//

import Foundation

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: @escaping (Key) throws -> T) rethrows -> Dictionary<T, Value> {
        try map { key, value in
            let transformedKey = try transform(key)
            return (transformedKey, value)
        }
        .toDictionary()
    }
}

extension Sequence {
    func toDictionary<Key: Hashable, Value>() -> Dictionary<Key, Value> where Element == (Key, Value) {
        Dictionary(uniqueKeysWithValues: self)
    }
}
