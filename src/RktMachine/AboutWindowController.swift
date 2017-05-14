//
//  AboutWindowController.swift
//
//  Created by David Ehlen on 24.07.15.
//  Copyright © 2015 David Ehlen. All rights reserved.
//  Copyright © 2017 Woof Woof, Inc. contributors.
//

import Cocoa

class AboutWindowController: NSWindowController {

    @IBOutlet var infoView: NSView!
    @IBOutlet var titleLabel: NSTextField!
    @IBOutlet var versionLabel: NSTextField!
    @IBOutlet var descriptionLabel: NSTextField!
    @IBOutlet var visitWebsiteButton: NSButton!

    override open func windowDidLoad() {
        super.windowDidLoad()

        self.window?.backgroundColor = NSColor.white
        self.window?.hasShadow = true

        self.infoView.wantsLayer = true
        self.infoView.layer?.cornerRadius = 10.0
        self.infoView.layer?.backgroundColor = NSColor.white.cgColor

        self.titleLabel.stringValue = "RktMachine"
        self.versionLabel.stringValue = "Version \(getInstalledRktMachineVersion())"
        self.descriptionLabel.stringValue = "CoreOS VM manager for Woof Woof, Inc. development."
    }

    @IBAction func visitWebsite(_ sender: AnyObject) {
        NSWorkspace.shared().open(
            URL(string: "https://github.com/woofwoofinc/rktmachine")!
        )
    }
}
