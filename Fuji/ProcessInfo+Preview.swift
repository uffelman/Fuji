//
//  ProcessInfo+Preview.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/20/26.
//

import Foundation

extension ProcessInfo {
    var isSwiftUIPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
