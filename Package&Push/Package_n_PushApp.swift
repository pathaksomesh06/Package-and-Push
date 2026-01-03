//
//  Package_PushApp.swift
//  Package&Push
//
//  Created by Somesh Pathak on 11/07/2025.
//

import SwiftUI

@main
struct Package_n_PushApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainAppView(authManager: authManager)
            } else {
                LoginView(authManager: authManager)
            }
        }
        .windowResizability(.contentSize)
    }
}
