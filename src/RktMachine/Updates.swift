//
//  Updates.swift
//
//  Created by Rimantas Mocevicius on 11/07/2016.
//  Copyright © 2016 The New Normal. All rights reserved.
//  Copyright © 2017 Woof Woof, Inc. contributors.
//

import Foundation
import Cocoa

func getInstalledRktMachineVersion() -> String {
    // Get installed app version.
    let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    NSLog("Installed RktMachine version: v\(version)")

    return version
}


func getLatestRktMachineVersion() -> String {
    // Get latest available app version from GitHub.
    let resourcesPath = getResourcesPathFromApp()
    let launchPath = resourcesPath.appendingPathComponent("commands/get_latest_rktmachine_version.command").path

    let latestVersion = runScriptAndReturnOutput(launchPath).trim()
    NSLog("Latest RktMachine version: \(latestVersion)")

    if latestVersion == "" {
        NSLog("ERROR: Cannot check the latest version on GitHub. API limit reached or GitHub technical issues.")
    }

    return latestVersion
}


func notifyIfUpdateAvailable() {
    DispatchQueue.global(qos: .userInitiated).async {
        let installedRktMachineVersion = "v\(getInstalledRktMachineVersion())"
        let latestRktMachineVersion = getLatestRktMachineVersion()

        if latestRktMachineVersion == "" {
            alert(informativeText: "Cannot find latest version.")
            return
        }

        if latestRktMachineVersion == installedRktMachineVersion {
            alert(informativeText: "You are up-to-date.")
        } else {
            // Show download prompt dialog.
            let alert: NSAlert = NSAlert()

            alert.alertStyle = NSAlertStyle.warning
            alert.messageText = "There is a new version of RktMachine available."
            alert.informativeText = "Open download URL in your browser?"

            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            DispatchQueue.main.sync {
                if alert.runModal() == NSAlertFirstButtonReturn {
                    let url: URL = URL(string: "https://github.com/woofwoofinc/rktmachine/releases")!
                    NSWorkspace.shared().open(url)
                }
            }
        }
    }
}
