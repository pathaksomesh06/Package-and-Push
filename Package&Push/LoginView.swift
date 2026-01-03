//
//  LoginView.swift
//  Package&Push
//
//  Created by Somesh Pathak on 11/07/2025.
//


import SwiftUI

struct LoginView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 48) {
                // Logo and Title
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: .blue.opacity(0.5), radius: 30, x: 0, y: 10)
                        
                        Image(systemName: "shippingbox.and.arrow.backward.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 12) {
                        Text("Package & Push")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("Deploy Homebrew packages to Microsoft Intune")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Login Section
                VStack(spacing: 20) {
                    Button(action: { authManager.signIn() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 20))
                            
                            Text("Sign in with Microsoft")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(width: 280, height: 56)
                        .background(
                            ZStack {
                                if isHovering {
                                    LinearGradient(
                                        colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                        .scaleEffect(isHovering ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3), value: isHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isHovering = hovering
                    }
                    
                    // Error Message
                    if let error = authManager.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                            
                            Text(error)
                                .font(.system(size: 14))
                                .lineLimit(2)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 320)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                
                // Features Grid
                VStack(spacing: 16) {
                    HStack(spacing: 40) {
                        FeatureIcon(
                            icon: "magnifyingglass",
                            title: "Search",
                            color: .cyan
                        )
                        
                        FeatureIcon(
                            icon: "hammer.fill",
                            title: "Build",
                            color: .orange
                        )
                        
                        FeatureIcon(
                            icon: "cloud.fill",
                            title: "Deploy",
                            color: .green
                        )
                    }
                }
                .padding(.top, 20)
            }
            .frame(maxWidth: 600)
        }
        .frame(minWidth: 800, minHeight: 700)
    }
}

struct FeatureIcon: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}
