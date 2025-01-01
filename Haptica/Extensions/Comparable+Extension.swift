//
//  Comparable+Extension.swift
//  Haptica
//
//  Created by Nozhan Amiri on 12/31/24.
//

import Foundation

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(range.lowerBound, self), range.upperBound)
    }
    
    func between(lhs: Self, rhs: Self) -> Bool {
        lhs <= self && self <= rhs
    }
}
