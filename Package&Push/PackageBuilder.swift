//
//  PackageBuilder.swift
//  Package&Push
//
//  Created by Somesh Pathak on 11/07/2025.
//

import Foundation

class PackageBuilder: ObservableObject {
    @Published var isBuilding = false
    @Published var buildProgress = ""
    @Published var errorMessage: String?
    
    private let brewPath = "/opt/homebrew/bin/brew"
    
    // Add task reference for cancellation
    var currentBuildTask: Task<Void, Never>?
    
    func cancelBuild() {
        currentBuildTask?.cancel()
        isBuilding = false
        buildProgress = "Cancelled"
    }
    
    func createPackage(for formula: String, preInstallScript: String? = nil, postInstallScript: String? = nil) async throws -> (URL, String) {
        // Check for cancellation at the start
        if Task.isCancelled { throw CancellationError() }
        do {
            // Check if it's a cask first
            let isCask = try await checkIfCask(formula)
            
            if isCask {
                // For casks, check if app already exists in /Applications
                let appExists = try await checkIfCaskAppExists(formula)
                if !appExists {
                    // Install cask only if app doesn't exist
                    await MainActor.run {
                        self.buildProgress = "Installing \(formula)..."
                    }
                    try await installFormula(formula)
                } else {
                    await MainActor.run {
                        self.buildProgress = "Using existing app for \(formula)..."
                    }
                }
            } else {
                // For formulas, check if installed
                let isInstalled = try await checkIfInstalled(formula)
            
            if !isInstalled {
                // Install formula first
                await MainActor.run {
                    self.buildProgress = "Installing \(formula)..."
                }
                try await installFormula(formula)
                }
            }
            
            // Get formula info
            await MainActor.run {
                self.buildProgress = "Getting formula info..."
            }
            let info = try await getFormulaInfo(formula)
            
            // Create temp directory
            await MainActor.run {
                self.buildProgress = "Creating package structure..."
            }
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("pkgbuild-\(formula)-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Create install root
            let installRoot = tempDir.appendingPathComponent("root")
            try FileManager.default.createDirectory(at: installRoot, withIntermediateDirectories: true)
            
            // Copy formula files to install root
            await MainActor.run {
                self.buildProgress = "Copying formula files..."
            }
            let bundleId = try await copyFormulaFiles(formula: formula, to: installRoot)
            
            // Build package
            await MainActor.run {
                self.buildProgress = "Building .pkg file..."
            }
            let pkgPath = tempDir.appendingPathComponent("\(formula)-\(info.version).pkg")

            // Prepare scripts directory if needed
            var scriptsDir: URL? = nil
            if (preInstallScript != nil && !preInstallScript!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
               (postInstallScript != nil && !postInstallScript!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                scriptsDir = tempDir.appendingPathComponent("Scripts")
                try FileManager.default.createDirectory(at: scriptsDir!, withIntermediateDirectories: true)
                if let pre = preInstallScript, !pre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let prePath = scriptsDir!.appendingPathComponent("preinstall")
                    try pre.write(to: prePath, atomically: true, encoding: .utf8)
                    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: prePath.path)
                }
                if let post = postInstallScript, !post.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let postPath = scriptsDir!.appendingPathComponent("postinstall")
                    try post.write(to: postPath, atomically: true, encoding: .utf8)
                    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: postPath.path)
                }
            }

            try await buildPackage(
                root: installRoot,
                identifier: bundleId.isEmpty ? "com.homebrew.\(formula)" : "com.homebrew.\(formula)",
                version: info.version,
                output: pkgPath,
                scriptsDir: scriptsDir
            )
            
            return (pkgPath, bundleId)
        } catch is CancellationError {
            await MainActor.run {
                self.isBuilding = false
                self.buildProgress = "Cancelled"
            }
            throw CancellationError()
        } catch {
            throw error
        }
    }
    
    private func checkIfInstalled(_ formula: String) async throws -> Bool {
        do {
            let output = try await executeCommand(
                path: brewPath,
                arguments: ["list", "--versions", formula]
            )
            return !output.isEmpty
        } catch {
            return false
        }
    }
    
    private func installFormula(_ formula: String) async throws {
        try await executeCommand(
            path: brewPath,
            arguments: ["install", formula]
        )
    }
    
    private func getFormulaInfo(_ formula: String) async throws -> FormulaInfo {
        let output = try await executeCommand(
            path: brewPath,
            arguments: ["info", "--json=v2", formula]
        )
        
        guard let data = output.data(using: .utf8) else {
            throw PackageError.invalidFormula
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            
            // Check if it's a cask
            if let casks = json["casks"] as? [[String: Any]], !casks.isEmpty {
                guard let first = casks.first,
                      let version = first["version"] as? String else {
                    throw PackageError.invalidFormula
                }
                return FormulaInfo(name: formula, version: version)
            }
            
            // Check if it's a formula
            if let formulae = json["formulae"] as? [[String: Any]], !formulae.isEmpty {
                guard let first = formulae.first else {
                    throw PackageError.invalidFormula
                }
                
                guard let versions = first["versions"] as? [String: Any],
                      let stable = versions["stable"] as? String else {
                    throw PackageError.invalidFormula
                }
                return FormulaInfo(name: formula, version: stable)
            }
            
            throw PackageError.invalidFormula
            
        } catch {
            throw PackageError.invalidFormula
        }
    }
    
    private func copyFormulaFiles(formula: String, to destination: URL) async throws -> String {
        // Check if it's a cask first
        let isCask = try await checkIfCask(formula)
        
        if isCask {
            return try await copyCaskFiles(formula: formula, to: destination)
        } else {
            // Handle regular formulae
            // Get Homebrew prefix
            let prefix = try await executeCommand(
                path: brewPath,
                arguments: ["--prefix"]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get installed version
            let listOutput = try await executeCommand(
                path: brewPath,
                arguments: ["list", "--versions", formula]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let version = listOutput.split(separator: " ").last else {
                throw PackageError.invalidFormula
            }
            
            // Get formula path
            let formulaPath = URL(fileURLWithPath: prefix)
                .appendingPathComponent("Cellar")
                .appendingPathComponent(formula)
                .appendingPathComponent(String(version))
            
            // Check if path exists
            guard FileManager.default.fileExists(atPath: formulaPath.path) else {
                throw PackageError.commandFailed("Formula files not found at \(formulaPath.path)")
            }
            
            // Copy to destination maintaining structure
            let destCellar = destination
                .appendingPathComponent("opt/homebrew/Cellar")
                .appendingPathComponent(formula)
                .appendingPathComponent(String(version))
            
            try FileManager.default.createDirectory(
                at: destCellar.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            try FileManager.default.copyItem(at: formulaPath, to: destCellar)
            
            // Create symlink in opt
            let optPath = destination
                .appendingPathComponent("opt/homebrew/opt")
                .appendingPathComponent(formula)
            
            try FileManager.default.createDirectory(
                at: optPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            try FileManager.default.createSymbolicLink(
                atPath: optPath.path,
                withDestinationPath: "../Cellar/\(formula)/\(version)"
            )
            
            return "" // No bundle ID for formula packages
        }
    }
    
    private func checkIfCask(_ formula: String) async throws -> Bool {
        let output = try await executeCommand(
            path: brewPath,
            arguments: ["info", "--cask", formula]
        )
        return !output.contains("Error: No available cask")
    }
    
    private func checkIfCaskAppExists(_ formula: String) async throws -> Bool {
        // Get cask info to find the app name
        let jsonOutput = try await executeCommand(
            path: brewPath,
            arguments: ["info", "--json=v2", "--cask", formula]
        )
        
        guard let data = jsonOutput.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let casks = json["casks"] as? [[String: Any]],
              let caskInfo = casks.first,
              let artifacts = caskInfo["artifacts"] as? [[String: Any]] else {
            return false
        }
        
        // Check if any app artifact exists in /Applications
        for artifact in artifacts {
            if let app = artifact["app"] as? [String], let appName = app.first {
                let appPath = URL(fileURLWithPath: "/Applications").appendingPathComponent(appName)
                if FileManager.default.fileExists(atPath: appPath.path) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func copyCaskFiles(formula: String, to destination: URL) async throws -> String {
        // Get cask info
        let jsonOutput = try await executeCommand(
            path: brewPath,
            arguments: ["info", "--json=v2", "--cask", formula]
        )
        
        guard let data = jsonOutput.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let casks = json["casks"] as? [[String: Any]],
              let caskInfo = casks.first,
              let artifacts = caskInfo["artifacts"] as? [[String: Any]] else {
            throw PackageError.invalidFormula
        }
        
        var bundleId = ""
        
        // Find app artifact
        for artifact in artifacts {
            if let app = artifact["app"] as? [String], let appName = app.first {
                let appPath = URL(fileURLWithPath: "/Applications").appendingPathComponent(appName)
                
                if FileManager.default.fileExists(atPath: appPath.path) {
                    // Copy app to destination
                    let destApp = destination.appendingPathComponent("Applications").appendingPathComponent(appName)
                    try FileManager.default.createDirectory(
                        at: destApp.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try FileManager.default.copyItem(at: appPath, to: destApp)
                    
                    // Extract bundle ID from Info.plist
                    let infoPlistPath = appPath.appendingPathComponent("Contents/Info.plist")
                    if let plistData = try? Data(contentsOf: infoPlistPath),
                       let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                       let extractedId = plist["CFBundleIdentifier"] as? String {
                        bundleId = extractedId
                    }
                    
                    break
                }
            }
        }
        
        return bundleId
    }
    
    private func buildPackage(root: URL, identifier: String, version: String, output: URL, scriptsDir: URL? = nil) async throws {
        var args = [
            "--root", root.path,
            "--identifier", identifier,
            "--version", version,
            "--install-location", "/"
        ]
        if let scripts = scriptsDir {
            args += ["--scripts", scripts.path]
        }
        args.append(output.path)
        try await executeCommand(
            path: "/usr/bin/pkgbuild",
            arguments: args
        )
    }
    
    private func executeCommand(path: String, arguments: [String]) async throws -> String {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PackageError.commandFailed(error)
        }
        
        return output
    }
}

struct FormulaInfo {
    let name: String
    let version: String
}

enum PackageError: LocalizedError {
    case invalidFormula
    case commandFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormula:
            return "Invalid formula or formula not found"
        case .commandFailed(let error):
            return "Command failed: \(error)"
        }
    }
}
