import SwiftUI

struct ContentView: View {
    @StateObject private var homebrewManager = HomebrewManager()
    @StateObject private var packageBuilder = PackageBuilder()
    @StateObject private var authManager = AuthenticationManager()
    @State private var searchText = ""
    @State private var selectedPackage: String?
    @State private var createdPackageURL: URL?
    @State private var packageBundleId: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search Homebrew packages...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            homebrewManager.searchPackages(query: searchText)
                        }
                    
                    if homebrewManager.isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                
                // Results List
                List(homebrewManager.searchResults, id: \.self) { package in
                    HStack {
                        Text(package)
                            .font(.system(.body, design: .monospaced))
                        
                        Spacer()
                        
                        if selectedPackage == package {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPackage = package
                    }
                }
                
                // Error Display
                if let error = homebrewManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Build Status
                if packageBuilder.isBuilding {
                    VStack {
                        ProgressView()
                        Text(packageBuilder.buildProgress.isEmpty ? "Building package..." : packageBuilder.buildProgress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // Action Button
                if selectedPackage != nil && !packageBuilder.isBuilding {
                    Button(action: {
                        Task {
                            do {
                                packageBuilder.isBuilding = true
                                let (pkgURL, bundleId) = try await packageBuilder.createPackage(for: selectedPackage!)
                                createdPackageURL = pkgURL
                                packageBundleId = bundleId
                                packageBuilder.isBuilding = false
                            } catch {
                                packageBuilder.errorMessage = error.localizedDescription
                                showError = true
                                packageBuilder.isBuilding = false
                            }
                        }
                    }) {
                        Label("Create Package", systemImage: "shippingbox")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
                
                // Success Status
                if let pkgURL = createdPackageURL {
                    VStack {
                        Label("Package Created", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(pkgURL.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if authManager.isAuthenticated {
                            Button("Upload to Intune") {
                                // TODO: Phase 4 - Upload
                                print("Ready for upload: \(pkgURL)")
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Sign in to Upload") {
                                authManager.signIn()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Package & Push")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(packageBuilder.errorMessage ?? "Unknown error")
        }
    }
}
