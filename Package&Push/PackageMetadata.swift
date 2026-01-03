//
//  PackageMetadata.swift
//  Package&Push
//
//  Created by Somesh Pathak on 11/07/2025.
//

import Foundation

struct PackageMetadata {
    let name: String
    let version: String
    let description: String
    let license: String?
    let homepage: String?
    let dependencies: [String]
}

class PackageMetadataFetcher {
    static let brewPath = "/opt/homebrew/bin/brew"
    
    static func fetchMetadata(for package: String) async throws -> PackageMetadata {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["info", "--json=v2", package]
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        // Check if it's a formula
        if let formulae = json["formulae"] as? [[String: Any]], !formulae.isEmpty, let first = formulae.first {
            let versions = first["versions"] as? [String: Any] ?? [:]
            let version = versions["stable"] as? String ?? "Unknown"
            let description = first["desc"] as? String ?? first["description"] as? String ?? "No description available"
            let license = first["license"] as? String
            let homepage = first["homepage"] as? String
            let dependencies = first["dependencies"] as? [String] ?? []
            
            return PackageMetadata(
                name: package,
                version: version,
                description: description,
                license: license,
                homepage: homepage,
                dependencies: dependencies
            )
        }
        
        // Check if it's a cask
        if let casks = json["casks"] as? [[String: Any]], !casks.isEmpty, let first = casks.first {
            let version = first["version"] as? String ?? "Unknown"
            let description = first["desc"] as? String ?? first["description"] as? String ?? "No description available"
            
            // Extract homepage from cask - it might be in different places
            var homepage: String? = nil
            if let homepageValue = first["homepage"] as? String {
                homepage = homepageValue
            } else if let url = first["url"] as? String {
                homepage = url
            }
            
            // Casks don't have dependencies in the same way
            let dependencies: [String] = []
            
            // License info might be in different format
            let license = first["license"] as? String
            
            return PackageMetadata(
                name: package,
                version: version,
                description: description,
                license: license,
                homepage: homepage,
                dependencies: dependencies
            )
        }
        
        throw NSError(domain: "PackageMetadata", code: 1, userInfo: [NSLocalizedDescriptionKey: "Package not found"])
    }
}
