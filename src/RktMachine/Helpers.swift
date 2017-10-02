//
//  Helpers.swift
//
//  Copyright © 2017 Woof Woof, Inc. contributors.
//

import Foundation
import Cocoa

extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


// Path helper functions.

func getWorkingDirectory() -> URL {
    return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".rktmachine")
}

func getResourcesPathFromApp() -> URL {
    return URL(fileURLWithPath: Bundle.main.resourcePath!)
}


// Filesystem helper functions.

func isDirectory(_ path: String) -> Bool {
    var isDirectory: ObjCBool = false
    let fileExists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

    return fileExists && isDirectory.boolValue
}

func isFile(_ path: String) -> Bool {
    var isDirectory: ObjCBool = false
    let fileExists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

    return fileExists && !isDirectory.boolValue
}

func pathExists(_ path: String) -> Bool {
    var isDirectory: ObjCBool = false
    let fileExists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

    return fileExists
}

func ensureDirectoryExists(_ path: String) -> Bool {
    if pathExists(path) {
        return isDirectory(path)
    }

    let result: Void? = try? FileManager.default.createDirectory(
        atPath: path,
        withIntermediateDirectories: true,
        attributes: nil
    )

    return result != nil
}

func appendToExistingFile(path: String, content: String) {
    // Check if file exists
    if let out = FileHandle(forWritingAtPath: path) {
        // Append to file
        out.seekToEndOfFile()
        out.write(content.data(using: String.Encoding.utf8)!)
        out.closeFile()
    }
}

func deleteDirectory(_ path: String) {
    if isDirectory(path) {
        let files: [String]? = try? FileManager.default.contentsOfDirectory(atPath: path)
        files?.forEach { file in
            let filePath = URL(fileURLWithPath: path).appendingPathComponent(file)
            try? FileManager.default.removeItem(at: filePath)
        }

        try? FileManager.default.removeItem(atPath: path)
    }
}

func deleteFile(_ path: String) {
    if isFile(path) {
        try? FileManager.default.removeItem(atPath: path)
    }
}


// Shell helper functions.

func runScript(_ launchPath: String, arguments: [String] = []) {
    let task: Process = Process()
    task.launchPath = launchPath
    task.arguments = arguments
    task.launch()

    task.waitUntilExit()
}

func runScriptAndReturnOutput(_ launchPath: String, arguments: [String] = []) -> String {
    let pipe: Pipe? = Pipe()
    let output: FileHandle? = pipe?.fileHandleForReading

    let task: Process = Process()
    task.launchPath = launchPath
    task.arguments = arguments
    task.standardOutput = pipe
    task.launch()

    task.waitUntilExit()

    let data: Data? = output?.readDataToEndOfFile()

    return String(data: data!, encoding: String.Encoding.utf8)!
}

func runTerminal(_ launchPath: String) {
    var application = "Terminal"

    // Prefer iTerm if it is available.
    if FileManager.default.fileExists(atPath: "/Applications/iTerm.app") {
        application = "iTerm"
    }

    NSWorkspace.shared.openFile(launchPath, withApplication: application)
}
