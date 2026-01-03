//
//  HomebrewManager.swift
//  Package&Push
//
//  Created by Somesh Pathak on 11/07/2025.
//


import Foundation

struct PackageInfo {
    let name: String
    let type: PackageType
    
    enum PackageType {
        case formula
        case cask
    }
}

class HomebrewManager: ObservableObject {
    @Published var searchResults: [String] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    private let brewPath = "/opt/homebrew/bin/brew"  // M1 Mac default
    // Use "/usr/local/bin/brew" for Intel Macs
    
    func searchPackages(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await executeBrewSearch(query: query)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
    
    private func executeBrewSearch(query: String) async throws -> [String] {
        // Search for both formulas and casks
        let formulaResults = try await searchFormulas(query: query)
        let caskResults = try await searchCasks(query: query)
        
        // Combine and deduplicate results
        var allResults = Set<String>()
        allResults.formUnion(formulaResults)
        allResults.formUnion(caskResults)
        
        return Array(allResults).sorted()
    }
    
    private func searchFormulas(query: String) async throws -> [String] {
        return try await executeBrewCommand(arguments: ["search", "--formula", query])
    }
    
    private func searchCasks(query: String) async throws -> [String] {
        return try await executeBrewCommand(arguments: ["search", "--cask", query])
    }
    
    private func executeBrewCommand(arguments: [String]) async throws -> [String] {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            // Check if it's just "no formula/cask found" which is not an error
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if let errorOutput = String(data: errorData, encoding: .utf8),
               (errorOutput.contains("No formula") || errorOutput.contains("No cask")) {
                return []
            }
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw HomebrewError.invalidOutput
        }
        
        // Parse output - each line is a package
        let packages = output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.starts(with: "==>") }
        
        return packages
    }
}

enum HomebrewError: LocalizedError {
    case invalidOutput
    case brewNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidOutput:
            return "Failed to parse Homebrew output"
        case .brewNotFound:
            return "Homebrew not found at expected path"
        }
    }
}
