//
//  Notifications.swift
//
//  Created by Rimantas Mocevicius on 06/07/2016.
//  Copyright © 2016 The New Normal. All rights reserved.
//  Copyright © 2017 Woof Woof, Inc. contributors.
//

import Foundation
import Cocoa

func alert(_ messageText: String = "RktMachine", informativeText: String) {
    _ = DispatchQueue.main.sync {
        let alert: NSAlert = NSAlert()

        alert.alertStyle = NSAlert.Style.informational
        alert.messageText = messageText
        alert.informativeText = informativeText

        alert.runModal()
    }
}
