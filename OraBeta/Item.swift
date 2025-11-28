//
//  Item.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
