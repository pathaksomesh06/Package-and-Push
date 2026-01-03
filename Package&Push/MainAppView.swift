//
//  MainAppView.swift
//  Package&Push
//
//  Created by Somesh Pathak on 11/07/2025.
//

import SwiftUI

struct MainAppView: View {
    @StateObject private var homebrewManager = HomebrewManager()
    @StateObject private var packageBuilder = PackageBuilder()
    @StateObject private var intuneUploader: IntuneMobileAppUploader
    @ObservedObject var authManager: AuthenticationManager
    
    @State private var searchText = ""
    @State private var selectedPackage: String?
    @State private var packageMetadata: PackageMetadata?
    @State private var createdPackageURL: URL?
    @State private var showError = false
    @State private var isUploadingToIntune = false
    @State private var uploadProgress = 0.0
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        _intuneUploader = StateObject(wrappedValue: IntuneMobileAppUploader(authManager: authManager))
    }
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            userHeader
            Divider()
            searchBar
            Divider()
            packageList
        }
        .background(Color(NSColor.controlBackgroundColor))
        .frame(width: 280)
        .fixedSize(horizontal: true, vertical: false)
    }
    
    private var userHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(authManager.userInfo?.displayName ?? "User")
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let email = authManager.userInfo?.userId {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            
            Button(action: {
                authManager.signOut()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .frame(maxHeight: 100)
    }
    
    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search packages...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        if !searchText.isEmpty {
                            homebrewManager.searchPackages(query: searchText)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        homebrewManager.searchResults = []
                        selectedPackage = nil
                        packageMetadata = nil
                        createdPackageURL = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                if homebrewManager.isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
        }
        .padding()
    }
    
    private var packageList: some View {
        Group {
            if homebrewManager.searchResults.isEmpty && !homebrewManager.isSearching {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Search for packages")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Enter a package name above")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(homebrewManager.searchResults, id: \.self, selection: $selectedPackage) { package in
                    HStack(spacing: 10) {
                        Image(systemName: "shippingbox.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        Text(package)
                            .font(.body)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.sidebar)
            }
        }
        .onChange(of: selectedPackage) { _, newValue in
            packageMetadata = nil
            createdPackageURL = nil
            if let package = newValue {
                fetchPackageMetadata(for: package)
            }
        }
    }
    
    private var detailView: some View {
        Group {
            if let package = selectedPackage {
                ModernPackageDetailView(
                    package: package,
                    metadata: packageMetadata,
                    packageBuilder: packageBuilder,
                    authManager: authManager,
                    intuneUploader: intuneUploader,
                    createdPackageURL: $createdPackageURL,
                    isUploadingToIntune: $isUploadingToIntune,
                    uploadProgress: $uploadProgress,
                    onUploadComplete: {
                        // Reset to default search screen
                        selectedPackage = nil
                        createdPackageURL = nil
                        packageMetadata = nil
                        searchText = ""
                        homebrewManager.searchResults = []
                    }
                )
            } else {
                ContentUnavailableView(
                    "Select a Package",
                    systemImage: "shippingbox",
                    description: Text("Search for a Homebrew package and select it to view details")
                )
            }
        }
    }
    
    private func fetchPackageMetadata(for package: String) {
        Task {
            do {
                let metadata = try await PackageMetadataFetcher.fetchMetadata(for: package)
                await MainActor.run {
                    self.packageMetadata = metadata
                }
            } catch {
                print("Failed to fetch metadata: \(error)")
            }
        }
    }
}
