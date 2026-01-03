//
//  IntuneAppConfiguration.swift
//  Package&Push
//
//  Created by Somesh Pathak on 12/07/2025.
//


//
//  IntuneAppConfiguration.swift
//  Package&Push
//
//  Created by Somesh Pathak on 12/07/2025.
//

import Foundation

class IntuneAppConfiguration: ObservableObject {
    // App Information
    @Published var displayName: String = ""
    @Published var description: String = ""
    @Published var publisher: String = "Homebrew"
    @Published var category: String = ""
    @Published var informationUrl: String = ""
    @Published var privacyUrl: String = ""
    @Published var developer: String = ""
    @Published var owner: String = ""
    @Published var notes: String = ""
    
    // Program
    @Published var preInstallScript: String = ""
    @Published var postInstallScript: String = ""
    
    // Requirements
    @Published var minimumOS: MacOSVersion = .v10_13
    
    // Detection Rules
    @Published var ignoreAppVersion: Bool = false
    @Published var bundleId: String = ""
    @Published var bundleVersion: String = ""
    
    // Assignments
    @Published var requiredGroups: [AzureADGroup] = []
    @Published var availableGroups: [AzureADGroup] = []
    
    // Package info
    var packageURL: URL?
    var packageName: String = ""
    var packageVersion: String = ""
    
    // Validation
    var isValid: Bool {
        !displayName.isEmpty && 
        !bundleId.isEmpty && 
        !bundleVersion.isEmpty
    }
    
    func reset() {
        displayName = ""
        description = ""
        publisher = "Homebrew"
        category = ""
        informationUrl = ""
        privacyUrl = ""
        developer = ""
        owner = ""
        notes = ""
        preInstallScript = ""
        postInstallScript = ""
        minimumOS = .v10_13
        ignoreAppVersion = false
        bundleId = ""
        bundleVersion = ""
        requiredGroups = []
        availableGroups = []
        packageURL = nil
        packageName = ""
        packageVersion = ""
    }
    
    func populateFromPackage(name: String, version: String, bundleId: String, url: URL) {
        self.packageName = name
        self.packageVersion = version
        self.packageURL = url
        self.displayName = name
        self.description = "Homebrew package: \(name)"
        self.bundleId = bundleId
        self.bundleVersion = version
    }
}

enum MacOSVersion: String, CaseIterable {
    case v10_13 = "macOS High Sierra 10.13"
    case v10_14 = "macOS Mojave 10.14"
    case v10_15 = "macOS Catalina 10.15"
    case v11_0 = "macOS Big Sur 11.0"
    case v12_0 = "macOS Monterey 12.0"
    case v13_0 = "macOS Ventura 13.0"
    case v14_0 = "macOS Sonoma 14.0"
    case v15_0 = "macOS Sequoia 15.0"
    
    var apiValue: [String: Bool] {
        let allVersions: [(String, MacOSVersion)] = [
            ("v10_7", .v10_13), ("v10_8", .v10_13), ("v10_9", .v10_13),
            ("v10_10", .v10_13), ("v10_11", .v10_13), ("v10_12", .v10_13),
            ("v10_13", .v10_13), ("v10_14", .v10_14), ("v10_15", .v10_15),
            ("v11_0", .v11_0), ("v12_0", .v12_0), ("v13_0", .v13_0),
            ("v14_0", .v14_0), ("v15_0", .v15_0)
        ]
        
        var result: [String: Bool] = [:]
        var shouldEnable = false
        
        for (key, version) in allVersions {
            if version == self {
                shouldEnable = true
            }
            result[key] = shouldEnable
        }
        
        return result
    }
}

enum ConfigurationTab: String, CaseIterable {
    case appInfo = "App Information"
    case program = "Program"
    case requirements = "Requirements"
    case detectionRules = "Detection Rules"
    case assignments = "Assignments"
    case review = "Review & Deploy"
    
    var shortName: String {
        switch self {
        case .appInfo: return "App Info"
        case .program: return "Program"
        case .requirements: return "Requirements"
        case .detectionRules: return "Detection"
        case .assignments: return "Assignments"
        case .review: return "Review"
        }
    }
    
    var description: String {
        switch self {
        case .appInfo: return "Configure app name, description, and metadata"
        case .program: return "Set up installation scripts"
        case .requirements: return "Define system requirements"
        case .detectionRules: return "Configure app detection settings"
        case .assignments: return "Assign to groups and users"
        case .review: return "Review configuration and deploy"
        }
    }
    
    var icon: String {
        switch self {
        case .appInfo: return "info.circle.fill"
        case .program: return "terminal.fill"
        case .requirements: return "desktopcomputer"
        case .detectionRules: return "magnifyingglass"
        case .assignments: return "person.2.fill"
        case .review: return "checkmark.seal.fill"
        }
    }
    
    var stepNumber: String {
        switch self {
        case .appInfo: return "1"
        case .program: return "2"
        case .requirements: return "3"
        case .detectionRules: return "4"
        case .assignments: return "5"
        case .review: return "6"
        }
    }
}