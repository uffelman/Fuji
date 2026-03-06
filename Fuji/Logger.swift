//
//  Logger.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/22/26.
//

import OSLog

extension Logger {
    
    /// A generic logger for all app events.
    nonisolated static let app = Logger(
        subsystem: "com.stephenu.Fuji",
        category: "App"
    )
}
