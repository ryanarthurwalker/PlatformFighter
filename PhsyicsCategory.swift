//
//  PhsyicsCategory.swift
//  PlatformFighter
//
//  Created by Ryan Walker on 12/10/24.
//

import Foundation

struct PhysicsCategory {
    static let player: UInt32 = 0x1 << 0
    static let enemy: UInt32 = 0x1 << 1
    static let attack: UInt32 = 0x1 << 2
    static let edge: UInt32 = 0x1 << 3
    static let none: UInt32 = 0
    static let platform: UInt32 = 0x1 << 1 // 2
}
