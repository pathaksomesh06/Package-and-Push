//
//  AppConfiguration.swift
//  Package&Push
//
//  Created by Somesh Pathak on 12/07/2025.
//


import Foundation

struct AppConfiguration {
    static let shared = AppConfiguration()
    
    private init() {}
    
    // MSAL Configuration
    var clientId: String {
        // Try to get from Info.plist first
        if let clientId = Bundle.main.object(forInfoDictionaryKey: "MSALClientId") as? String,
           !clientId.isEmpty && clientId != "YOUR_CLIENT_ID_HERE" {
            return clientId
        }
        
        // Try Config.plist
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: configPath),
           let clientId = config["MSALClientId"] as? String,
           !clientId.isEmpty && clientId != "YOUR_CLIENT_ID_HERE" {
            return clientId
        }
        
        // Fallback to environment variable
        if let clientId = ProcessInfo.processInfo.environment["MSAL_CLIENT_ID"],
           !clientId.isEmpty {
            return clientId
        }
        
        fatalError("""
        MSAL Client ID not configured!
        
        Please configure your Azure AD app registration:
        1. Add MSALClientId to Info.plist, or
        2. Create Config.plist with MSALClientId, or
        3. Set MSAL_CLIENT_ID environment variable
        
        Get your Client ID from Azure Portal:
        https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps
        """)
    }
    
    var redirectUri: String {
        // Always use the actual bundle identifier
        return "msauth.com.mavericklabs.Package-n-Push://auth"
    }
    
    var authority: String {
        // Use common endpoint for multi-tenant support
        return "https://login.microsoftonline.com/common"
    }
    
    var scopes: [String] {
        return [
            // Reserved scopes (openid, profile, offline_access) must NOT be requested explicitly
            "https://graph.microsoft.com/DeviceManagementApps.ReadWrite.All"
        ]
    }
    
    var graphEndpoint: String {
        return "https://graph.microsoft.com"
    }
}
