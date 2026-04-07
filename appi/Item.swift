//
//  Item.swift
//  appi
//
//  Created by Arthur Gabriel Lima Gomes on 06/04/26.
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
