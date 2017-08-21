//
//  VM.swift
//
//  Created by Rimantas Mocevicius on 06/07/2016.
//  Copyright © 2016 The New Normal. All rights reserved.
//  Copyright © 2017 Woof Woof, Inc. contributors.
//

import Foundation
import Cocoa

// Service status functions.

private func getCorectldIsRunning() -> Bool {
    let launchPath = getResourcesPathFromApp().appendingPathComponent("bin/corectld").path
    let result = runScriptAndReturnOutput(launchPath, arguments: ["status"])

    return result.contains("Uptime:")
}

private func getVmIsRunning() -> Bool {
    let launchPath = getResourcesPathFromApp().appendingPathComponent("bin/corectl").path
    let result = runScriptAndReturnOutput(launchPath, arguments: ["query", "--up", "rktmachine"])

    return result.trim() == "true"
}

private func getVmIpAddress() -> String {
    let launchPath = getResourcesPathFromApp().appendingPathComponent("bin/corectl").path
    let result = runScriptAndReturnOutput(launchPath, arguments: ["query", "--ip", "rktmachine"])

    return result.trim()
}


// Service state manipulation functions.

private func ensureEnvironmentInstalled() -> Bool {
    let workingDirectory: URL = getWorkingDirectory()

    if !ensureDirectoryExists(workingDirectory.path) {
        alert(
            informativeText: "Cannot create \(workingDirectory.path), please delete or rename existing file."
        )

        return false
    }

    // Test that SSH keys exist and alert for creation if not.
    let publicKeyFile: String = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ssh/id_rsa.pub").path
    if !isFile(publicKeyFile) {
        alert(
            informativeText: "Public key not found at ~/.ssh/id_rsa.pub. Run 'ssh-keygen -t rsa' before continuing."
        )

        return false
    }

    // Write app version number file.
    let versionFile = workingDirectory.appendingPathComponent("version").path
    let versionKey: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    let version: Data? = versionKey.data(using: String.Encoding.utf8)

    deleteFile(versionFile)

    FileManager.default.createFile(
        atPath: versionFile,
        contents: version,
        attributes: nil
    )

    // Write resources_path file.
    let resourcesPathFile = workingDirectory.appendingPathComponent("resources_path").path
    let resourcesPath: Data? = getResourcesPathFromApp().path.data(using: String.Encoding.utf8)

    deleteFile(resourcesPathFile)

    FileManager.default.createFile(
        atPath: resourcesPathFile,
        contents: resourcesPath,
        attributes: nil
    )

    // Write corectl rktmachine.toml configuration file.
    let tomlWorkingDirectoryFile = workingDirectory.appendingPathComponent("rktmachine.toml").path

    deleteFile(tomlWorkingDirectoryFile)

    let tomlResourceFile = getResourcesPathFromApp().appendingPathComponent("vm/rktmachine.toml").path
    try? FileManager.default.copyItem(
        atPath: tomlResourceFile,
        toPath: tomlWorkingDirectoryFile
    )

    // Add ssh key to toml configuration file for corectl.
    let publicKey = try? String(
        contentsOfFile: publicKeyFile,
        encoding: String.Encoding.utf8
    )

    appendToExistingFile(
        path: tomlWorkingDirectoryFile,
        content: "   sshkey = '\(publicKey!.trim())'\n"
    )

    // Write user-data installation file if missing.
    let userDataWorkingDirectoryFile = workingDirectory.appendingPathComponent("user-data").path

    if !isFile(userDataWorkingDirectoryFile) {
        let userDataResourceFile = getResourcesPathFromApp().appendingPathComponent("vm/user-data").path
        try? FileManager.default.copyItem(
            atPath: userDataResourceFile,
            toPath: userDataWorkingDirectoryFile
        )

        // Add format_root option to rktmachine.toml file for next start. This
        // will be cleared on following ensureEnvironmentInstalled() call.
        appendToExistingFile(
            path: tomlWorkingDirectoryFile,
            content: "   format-root = 'true'\n"
        )
    }

    // Copy a new persistent root image if missing.
    let rootImagePath = workingDirectory.appendingPathComponent("root.qcow2").path

    if !isFile(rootImagePath) {
        let rootImageResourceFile = getResourcesPathFromApp().appendingPathComponent("vm/root.qcow2").path
        try? FileManager.default.copyItem(
            atPath: rootImageResourceFile,
            toPath: rootImagePath
        )

    }

    // Copy a tools disk image if missing.
    let toolsImagePath = workingDirectory.appendingPathComponent("tools.qcow2").path

    if !isFile(toolsImagePath) {
        let toolsImageResourceFile = getResourcesPathFromApp().appendingPathComponent("vm/tools.qcow2").path
        try? FileManager.default.copyItem(
            atPath: toolsImageResourceFile,
            toPath: toolsImagePath
        )
    }

    // Write MOTD installation file if missing.
    let motdWorkingDirectoryFile = workingDirectory.appendingPathComponent("motd").path

    if !isFile(motdWorkingDirectoryFile) {
        let motdResourceFile = getResourcesPathFromApp().appendingPathComponent("vm/motd").path
        try? FileManager.default.copyItem(
            atPath: motdResourceFile,
            toPath: motdWorkingDirectoryFile
        )
    }

    return true
}

private func ensureCorectldRunning() {
    if !getCorectldIsRunning() {
        // Inform the user about why their password is required.
        alert(informativeText: "Your password or TouchID is needed to start the RktMachine VM.")

        // Start corectld.
        let launchPath = getResourcesPathFromApp().appendingPathComponent("bin/corectld").path
        runScript(launchPath, arguments: ["start", "--user", "$(whoami)"])

        updateStatusAsync()

        if !getCorectldIsRunning() {
            // Display an error message.
            alert(informativeText: "Failed to start Corectld.")
        }
    }
}

private func ensureVmStopped() {
    if getVmIsRunning() {
        // Stop VM.
        let launchPath = getResourcesPathFromApp().appendingPathComponent("bin/corectl").path
        runScript(launchPath, arguments: ["stop", "rktmachine"])

        updateStatusAsync()
    }
}

// Public since used in quit handler synchronously.
func ensureCorectldStopped() {
    if getCorectldIsRunning() {
        ensureVmStopped()

        // Stop corectld.
        let launchPath = getResourcesPathFromApp().appendingPathComponent("bin/corectld").path
        runScript(launchPath, arguments: ["stop"])

        updateStatusAsync()
    }
}


// Async calls for use by UI action handlers.

func updateStatusAsync() {
    DispatchQueue.global(qos: .userInitiated).async {
        // Default to stopped state unless seen to be otherwise.
        var title = "Corectld: Stopped"
        var state = NSOffState

        if getVmIsRunning() {
            title = "VM: Running"
            state = NSOnState
        } else if getCorectldIsRunning() {
            title = "VM: Stopped"
            state = NSOffState
        }

        DispatchQueue.main.async {
            let menuItem: NSMenuItem? = statusItem.menu?.item(withTag: 1)
            menuItem?.title = title
            menuItem?.state = state
        }
    }
}

func ensureVmStartedAsync(stopCorectldFirst: Bool = false) {
    DispatchQueue.global(qos: .userInitiated).async {
        let environmentReady = ensureEnvironmentInstalled()
        if !environmentReady {
            return
        }

        if stopCorectldFirst {
            ensureCorectldStopped()
        }

        ensureCorectldRunning()

        if !getVmIsRunning() {
            // This is a terminal script as it may include a long CoreOS image
            // download step which should be visible to the user.
            let startVmCommand = getResourcesPathFromApp().appendingPathComponent("commands/start_vm.command").path
            runTerminal(startVmCommand)
        }
    }
}

func sshVmAsync() {
    DispatchQueue.global(qos: .userInitiated).async {
        if getVmIsRunning() {
            // Add SSH key to authentication agent if not present.
            let sshAdd = URL(fileURLWithPath: "/usr/bin/ssh-add").path
            let keys = runScriptAndReturnOutput(sshAdd, arguments: ["-l"])

            if !keys.contains("ssh/id_rsa") {
                let home = URL(fileURLWithPath: NSHomeDirectory())
                let privateKeyFile: String = home.appendingPathComponent(".ssh/id_rsa").path
                runScript(sshAdd, arguments: ["-K", privateKeyFile])
            }

            let sshCommand = getResourcesPathFromApp().appendingPathComponent("commands/ssh.command").path
            runTerminal(sshCommand)
        } else {
            alert(informativeText: "Cannot SSH to stopped VM.")
        }
    }
}

func ensureVmStoppedAsync() {
    DispatchQueue.global(qos: .userInitiated).async {
        ensureVmStopped()
    }
}

func ensureVmResetAsync() {
    DispatchQueue.global(qos: .userInitiated).async {
        ensureVmStopped()

        if !getVmIsRunning() {
            // Delete ~/.rktmachine.
            deleteDirectory(getWorkingDirectory().path)
        }
    }
}
