//
//  AuthenticationManager.swift
//  Package&Push
//
//  Created by Somesh Pathak on 11/07/2025.
//


import Foundation
import MSAL
import AppKit

class AzureADService {
    let authManager: AuthenticationManager

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }

    func searchGroups(query: String) async throws -> [AzureADGroup] {
        let token = try await authManager.getToken()
        var urlComponents = URLComponents(string: "https://graph.microsoft.com/v1.0/groups")!
        urlComponents.queryItems = [
            URLQueryItem(name: "$filter", value: "startswith(displayName,'\(query)')"),
            URLQueryItem(name: "$select", value: "id,displayName"),
            URLQueryItem(name: "$top", value: "20")
        ]
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "AzureADService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch groups"])
        }
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let values = json["value"] as? [[String: Any]] ?? []
        return values.compactMap { dict in
            guard let id = dict["id"] as? String else { return nil }
            let displayName = dict["displayName"] as? String
            return AzureADGroup(id: id, displayName: displayName)
        }
    }
}

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var errorMessage: String?
    @Published var userInfo: UserInfo?
    
    private let config = AppConfiguration.shared
    private var msalApplication: MSALPublicClientApplication?
    private let keychainKey = "com.mavericklabs.Package-n-Push.token"
    
    struct UserInfo {
        let tenantId: String
        let userId: String
        let displayName: String
    }
    
    init() {
        setupMSAL()
        checkStoredToken()
    }
    
    private func setupMSAL() {
        do {
            let authority = try MSALAuthority(url: URL(string: config.authority)!)
            
            let msalConfig = MSALPublicClientApplicationConfig(
                clientId: config.clientId,
                redirectUri: config.redirectUri,
                authority: authority
            )
            
            // Verbose MSAL logging (non-PII) to help diagnose issues
            // Also explicitly disable broker/SSO extension on macOS to avoid SSO dictionary serialization errors
            MSALGlobalConfig.brokerAvailability = .none
            MSALGlobalConfig.loggerConfig.logLevel = .verbose
            MSALGlobalConfig.loggerConfig.setLogCallback { (level, message, containsPII) in
                if !containsPII {
                    print("MSAL [\(level.rawValue)]: \(message ?? "")")
                }
            }
            
            // Use ADAL keychain group so MSAL can persist tokens on macOS
            msalConfig.cacheConfig.keychainSharingGroup = "com.microsoft.adalcache"
            
            msalApplication = try MSALPublicClientApplication(configuration: msalConfig)
        } catch {
            errorMessage = "Failed to initialize MSAL: \(error.localizedDescription)"
        }
    }
    
    private func checkStoredToken() {
        guard let application = msalApplication else { return }
        
        // Try to get cached account; if none, fall back to interactive sign-in
        do {
            let accounts = try application.allAccounts()
            if let account = accounts.first {
                acquireTokenSilently(account: account)
            } else {
                // No cached account; prompt user to sign in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.signIn()
                }
            }
        } catch {
            print("No cached accounts")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.signIn()
            }
        }
    }
    
    func signIn() {
        guard let application = msalApplication else {
            errorMessage = "MSAL not initialized"
            return
        }
        
        let viewController = NSApplication.shared.keyWindow?.contentViewController
            ?? NSApplication.shared.windows.first(where: { $0.isVisible })?.contentViewController
        guard let viewController else {
            errorMessage = "No active window found"
            return
        }
        
        let webviewParameters = MSALWebviewParameters(authPresentationViewController: viewController)
        // Force embedded WKWebView to avoid broker/system session redirect issues on macOS
        webviewParameters.webviewType = .wkWebView
        
        let interactiveParameters = MSALInteractiveTokenParameters(
            scopes: config.scopes,
            webviewParameters: webviewParameters
        )
        
        application.acquireToken(with: interactiveParameters) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    let nsError = error as NSError
                    var message = "\(nsError.domain) (code: \(nsError.code))"
                    if let detailed = nsError.userInfo["MSALErrorDescriptionKey"] as? String, !detailed.isEmpty {
                        message += "\n\(detailed)"
                    }
                    if let oauthError = nsError.userInfo["MSALOAuthErrorKey"] as? String, !oauthError.isEmpty {
                        message += "\nOAuth: \(oauthError)"
                    }
                    if let correlationId = nsError.userInfo["MSALCorrelationIdKey"] as? String, !correlationId.isEmpty {
                        message += "\nCorrelation Id: \(correlationId)"
                    }
                    print("MSAL acquireToken error: \(message)")
                    self?.errorMessage = message
                    self?.isAuthenticated = false
                    return
                }
                
                if let result = result {
                    self?.handleAuthResult(result)
                }
            }
        }
    }
    
    private func acquireTokenSilently(account: MSALAccount) {
        guard let application = msalApplication else { return }
        
        let silentParameters = MSALSilentTokenParameters(scopes: config.scopes, account: account)
        
        application.acquireTokenSilent(with: silentParameters) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.handleAuthResult(result)
                } else {
                    // Silent failed, need interactive
                    print("Silent token acquisition failed")
                }
            }
        }
    }
    
    private func handleAuthResult(_ result: MSALResult) {
        self.accessToken = result.accessToken
        self.isAuthenticated = true
        self.errorMessage = nil
        
        // Extract user info - handle optional tenantId
        let tenantId: String
        if let tid = result.tenantProfile.tenantId {
            tenantId = tid
        } else {
            tenantId = "Unknown"
        }
        
        
        let displayName: String
        if let username = result.account.username {
            displayName = username
        } else {
            displayName = "User"
        }
        
        self.userInfo = UserInfo(
            tenantId: tenantId,
            userId: result.account.identifier ?? "Unknown",
            displayName: displayName
        )
        
        // Store token securely
        storeTokenInKeychain(result.accessToken)
    }
    
    func signOut() {
        guard let application = msalApplication else { return }
        
        do {
            let accounts = try application.allAccounts()
            for account in accounts {
                try application.remove(account)
            }
        } catch {
            print("Sign out error: \(error)")
        }
        
        accessToken = nil
        isAuthenticated = false
        userInfo = nil
        deleteTokenFromKeychain()
    }
    
    func getToken() async throws -> String {
        // First check if we have a cached token
        if let cachedToken = self.accessToken {
            print("Using cached token")
            return cachedToken
        }
        
        guard let application = msalApplication else {
            throw AuthError.notInitialized
        }
        
        // Try silent acquisition first
        if let account = try? application.allAccounts().first {
            let silentParameters = MSALSilentTokenParameters(scopes: config.scopes, account: account)
            
            do {
                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MSALResult, Error>) in
                    application.acquireTokenSilent(with: silentParameters) { result, error in
                        if let error = error {
                            print("Silent token acquisition failed: \(error)")
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        if let result = result {
                            continuation.resume(returning: result)
                        } else {
                            continuation.resume(throwing: AuthError.noToken)
                        }
                    }
                }
                
                // Cache the new token
                self.accessToken = result.accessToken
                return result.accessToken
                
            } catch {
                print("Token acquisition error: \(error)")
                // Don't fall back to interactive - that should only happen on user action
                throw AuthError.noToken
            }
        }
        
        // No account found
        throw AuthError.noToken
    }
    
    private func acquireTokenInteractively() async throws -> String {
        guard let application = msalApplication else {
            throw AuthError.notInitialized
        }
        
        let viewController = await MainActor.run {
            NSApplication.shared.keyWindow?.contentViewController
        }
        
        guard let vc = viewController else {
            throw AuthError.noToken
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            Task { @MainActor in
                let webviewParameters = MSALWebviewParameters(authPresentationViewController: vc)
                webviewParameters.webviewType = .wkWebView
                let interactiveParameters = MSALInteractiveTokenParameters(
                    scopes: config.scopes,
                    webviewParameters: webviewParameters
                )
                
                application.acquireToken(with: interactiveParameters) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let result = result {
                        continuation.resume(returning: result.accessToken)
                    } else {
                        continuation.resume(throwing: AuthError.noToken)
                    }
                }
            }
        }
    }
    
    // MARK: - Keychain Methods
    
    private func storeTokenInKeychain(_ token: String) {
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

enum AuthError: LocalizedError {
    case notInitialized
    case noToken
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Authentication not initialized"
        case .noToken:
            return "No access token available"
        }
    }
}
