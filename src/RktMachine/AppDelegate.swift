//
//  AppDelegate.swift
//
//  Created by Rimantas Mocevicius on 28/06/2016.
//  Copyright © 2016 The New Normal. All rights reserved.
//  Copyright © 2017 Woof Woof, Inc. contributors.
//

import Cocoa
import Foundation


var statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    var aboutWindowController: AboutWindowController

    override init() {
        self.aboutWindowController = AboutWindowController(windowNibName: "AboutWindow")
        super.init()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let icon = NSImage(named: "StatusItemIcon")
        icon?.isTemplate = true

        statusItem.menu = statusMenu
        statusItem.image = icon
        statusItem.highlightMode = true

        if #available(OSX 10.12, *) {
            statusItem.isVisible = true
        }

        assertNotRunningFromDmg()

        // Stop corectl daemon first in case it is still running, then start the VM.
        ensureVmStartedAsync(stopCorectldFirst: true)

        // Update the VM state menu item every five seconds.
        Timer.every(5.seconds) { (timer: Timer) in
            updateStatusAsync()
        }
    }


    // Menu item handlers.

    @IBAction func status(_ sender: NSMenuItem) {
        // Empty function to create menu item.
    }

    @IBAction func start(_ sender: NSMenuItem) {
        ensureVmStartedAsync()
    }

    @IBAction func stop(_ sender: NSMenuItem) {
        ensureVmStoppedAsync()
    }

    @IBAction func reset(_ sender: NSMenuItem) {
        let alert = NSAlert()

        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        alert.messageText = "Reset RktMachine VM?"
        alert.informativeText = "This will delete any stored data on the VM."

        alert.alertStyle = NSWarningAlertStyle
        if alert.runModal() == NSAlertFirstButtonReturn {
            ensureVmResetAsync()
        }
    }

    @IBAction func ssh(_ sender: NSMenuItem) {
        sshVmAsync()
    }

    @IBAction func about(_ sender: NSMenuItem) {
        self.aboutWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func checkForUpdates(_ sender: NSMenuItem) {
        notifyIfUpdateAvailable()
    }

    @IBAction func quit(_ sender: NSMenuItem) {
        // Unwire the status bar icon quickly, then run slow synchronous cleanup.
        if #available(OSX 10.12, *) {
            statusItem.isVisible = false
        }

        ensureCorectldStopped()

        NSApplication.shared().terminate(self)
    }


    // Other functions.

    func assertNotRunningFromDmg() {
        // Exit app if running from the dmg.
        let resourcesPathFromApp = getResourcesPathFromApp().path
        let dmgPath: String = URL(fileURLWithPath: "/Volumes/RktMachine/RktMachine.app/Contents/Resources").path

        if resourcesPathFromApp == dmgPath {
            let alert = NSAlert()

            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            alert.messageText = "RktMachine cannot be started from DMG."
            alert.informativeText = "Please copy RktMachine to your Applications folder."

            alert.alertStyle = NSWarningAlertStyle
            alert.runModal()

            // Exit
            NSApplication.shared().terminate(self)
        }
    }
}
