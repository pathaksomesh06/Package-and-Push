//
//  ModernPackageDetailView.swift
//  Package&Push
//
//  Created by Somesh Pathak on 12/07/2025.
//


import SwiftUI

struct ModernPackageDetailView: View {
    let package: String
    let metadata: PackageMetadata?
    @ObservedObject var packageBuilder: PackageBuilder
    @ObservedObject var authManager: AuthenticationManager
    @ObservedObject var intuneUploader: IntuneMobileAppUploader
    @Binding var createdPackageURL: URL?
    @Binding var isUploadingToIntune: Bool
    @Binding var uploadProgress: Double
    let onUploadComplete: (() -> Void)?
    
    @State private var showingUploadConfirmation = false
    @State private var packageBundleId: String?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color(NSColor.controlBackgroundColor).opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if metadata == nil {
                // Loading or waiting for metadata
                MetadataLoadingView(package: package)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Section
                        HeroSectionView(package: package, metadata: metadata)
                        
                        // Content Section
                        VStack(spacing: 32) {
                            // Metadata Cards
                            if let metadata = metadata {
                                MetadataCardsView(metadata: metadata)
                            }
                            
                            // Action Section
                            ActionSectionView(
                                packageBuilder: packageBuilder,
                                intuneUploader: intuneUploader,
                                authManager: authManager,
                                createdPackageURL: $createdPackageURL,
                                isUploadingToIntune: $isUploadingToIntune,
                                uploadProgress: $uploadProgress,
                                showingUploadConfirmation: $showingUploadConfirmation,
                                packageBundleId: $packageBundleId,
                                package: package,
                                metadata: metadata,
                                onUploadComplete: onUploadComplete
                            )
                        }
                        .padding(32)
                    }
                }
            }
        }
        .confirmationDialog("Upload to Intune", isPresented: $showingUploadConfirmation) {
            Button("Upload") {
                uploadToIntune()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Upload \(createdPackageURL?.lastPathComponent ?? "package") to Microsoft Intune?")
        }
    }
    
    private func uploadToIntune() {
        guard let pkgURL = createdPackageURL,
              let metadata = metadata else {
            print("Upload failed: Missing package URL or metadata")
            return
        }
        
        print("Starting upload to Intune for: \(pkgURL.lastPathComponent)")
        if let bundleId = packageBundleId {
            print("Using bundle ID: \(bundleId)")
        }
        
        Task {
            do {
                isUploadingToIntune = true
                try await intuneUploader.uploadPackageToIntune(
                    packageURL: pkgURL,
                    appName: package,
                    version: metadata.version,
                    bundleId: packageBundleId
                )
                print("Upload completed successfully")
            } catch {
                print("Upload failed: \(error)")
                intuneUploader.errorMessage = error.localizedDescription
                isUploadingToIntune = false
            }
        }
    }
}

// MARK: - Hero Section
struct HeroSectionView: View {
    let package: String
    let metadata: PackageMetadata?
    
    var body: some View {
        VStack(spacing: 0) {
            // Dark header background
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.15),
                        Color(red: 0.05, green: 0.05, blue: 0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                VStack(spacing: 24) {
                    // Package Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        Image(systemName: iconForPackage(package))
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                    
                    // Package Info
                    VStack(spacing: 12) {
                        Text(package)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        if let metadata = metadata {
                            Text(metadata.description)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .frame(maxWidth: 500)
                        }
                    }
                }
                .padding(.vertical, 48)
            }
            .frame(height: 280)
        }
    }
    
    private func iconForPackage(_ name: String) -> String {
        if name.contains("chrome") || name.contains("firefox") || name.contains("safari") {
            return "globe"
        } else if name.contains("code") || name.contains("vim") || name.contains("emacs") {
            return "chevron.left.forwardslash.chevron.right"
        } else if name.contains("docker") || name.contains("kubernetes") {
            return "shippingbox.fill"
        } else {
            return "app.fill"
        }
    }
}

// MARK: - Metadata Loading View
struct MetadataLoadingView: View {
    let package: String
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.2)
            
            VStack(spacing: 8) {
                Text("Loading package information")
                    .font(.system(size: 18, weight: .medium))
                
                Text(package)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Metadata Cards
struct MetadataCardsView: View {
    let metadata: PackageMetadata
    
    var body: some View {
        VStack(spacing: 20) {
            // Version and License Row
            HStack(spacing: 16) {
                MetadataCard(
                    icon: "number.square.fill",
                    title: "Version",
                    value: metadata.version,
                    color: .blue
                )
                
                if let license = metadata.license {
                    MetadataCard(
                        icon: "doc.text.fill",
                        title: "License",
                        value: license,
                        color: .green
                    )
                }
            }
            
            // Dependencies
            if !metadata.dependencies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                        Text("Dependencies")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(metadata.dependencies, id: \.self) { dep in
                            DependencyChip(name: dep)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            
            // Homepage
            if let homepage = metadata.homepage {
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                    
                    Text("Homepage:")
                        .font(.system(size: 14, weight: .medium))
                    
                    Link(destination: URL(string: homepage)!) {
                        Text(homepage)
                            .font(.system(size: 14))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Metadata Card
struct MetadataCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Action Section
struct ActionSectionView: View {
    @ObservedObject var packageBuilder: PackageBuilder
    @ObservedObject var intuneUploader: IntuneMobileAppUploader
    @ObservedObject var authManager: AuthenticationManager
    @Binding var createdPackageURL: URL?
    @Binding var isUploadingToIntune: Bool
    @Binding var uploadProgress: Double
    @Binding var showingUploadConfirmation: Bool
    @Binding var packageBundleId: String?
    let package: String
    let metadata: PackageMetadata?
    let onUploadComplete: (() -> Void)?
    
    @State private var showingConfiguration = false
    @State private var buildTask: Task<Void, Never>? = nil
    @State private var uploadTask: Task<Void, Never>? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            // Status Card - only show during active operations
            if packageBuilder.isBuilding {
                StatusCard(
                    packageBuilder: packageBuilder,
                    intuneUploader: intuneUploader,
                    createdPackageURL: createdPackageURL,
                    uploadProgress: intuneUploader.uploadProgress,
                    isUploading: intuneUploader.isUploading
                )
                Button("Cancel Build") {
                    packageBuilder.cancelBuild()
                    buildTask?.cancel()
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            } else if intuneUploader.isUploading {
                StatusCard(
                    packageBuilder: packageBuilder,
                    intuneUploader: intuneUploader,
                    createdPackageURL: createdPackageURL,
                    uploadProgress: intuneUploader.uploadProgress,
                    isUploading: intuneUploader.isUploading
                )
                Button("Cancel Upload") {
                    intuneUploader.cancelUpload()
                    uploadTask?.cancel()
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
            // Action Buttons
            if !packageBuilder.isBuilding && !intuneUploader.isUploading {
                if createdPackageURL == nil {
                    PrimaryActionButton(
                        title: "Build Package",
                        icon: "hammer.fill",
                        action: {
                            buildTask = Task {
                                packageBuilder.currentBuildTask = buildTask
                                await createPackage()
                            }
                        }
                    )
                } else {
                    PrimaryActionButton(
                        title: "Configure the app",
                        icon: "gearshape.fill",
                        action: { showingConfiguration = true }
                    )
                }
            }
        }
        .onAppear {
            print("=== ActionSectionView Debug ===")
            print("createdPackageURL: \(createdPackageURL?.lastPathComponent ?? "nil")")
            print("isBuilding: \(packageBuilder.isBuilding)")
            print("isUploading: \(intuneUploader.isUploading)")
            print("uploadProgress: \(intuneUploader.uploadProgress)")
            print("=============================")
        }
        .onChange(of: createdPackageURL) { newValue in
            print("=== createdPackageURL Changed ===")
            print("New value: \(newValue?.lastPathComponent ?? "nil")")
            print("================================")
        }
        .onChange(of: packageBuilder.isBuilding) { newValue in
            print("=== isBuilding Changed ===")
            print("New value: \(newValue)")
            print("==========================")
        }
        .sheet(isPresented: $showingConfiguration) {
            if let pkgURL = createdPackageURL {
                IntuneConfigurationView(
                    packageURL: pkgURL,
                    packageName: package,
                    packageVersion: metadata?.version ?? "1.0",
                    bundleId: packageBundleId ?? "com.homebrew.\(package)",
                    authManager: authManager,
                    onUploadComplete: {
                        // Reset local state after successful upload
                        createdPackageURL = nil
                        intuneUploader.uploadResult = nil
                        intuneUploader.uploadCompleted = false
                        // Call the parent callback to reset to default search screen
                        onUploadComplete?()
                    }
                )
            }
        }
    }
    
    private func createPackage() async {
            do {
            await MainActor.run {
                packageBuilder.isBuilding = true
            }
            // Get scripts from config if available
            let config = IntuneAppConfiguration()
            let preScript = config.preInstallScript
            let postScript = config.postInstallScript
            let (pkgURL, bundleId) = try await packageBuilder.createPackage(for: package, preInstallScript: preScript, postInstallScript: postScript)
            await MainActor.run {
                createdPackageURL = pkgURL
                packageBundleId = bundleId
                packageBuilder.isBuilding = false
            }
                print("=== Package Created ===")
                print("URL: \(pkgURL.lastPathComponent)")
                print("BundleID: \(bundleId)")
            print("createdPackageURL set to: \(pkgURL)")
                print("====================")
            } catch {
            await MainActor.run {
                packageBuilder.errorMessage = error.localizedDescription
                packageBuilder.isBuilding = false
            }
            print("=== Package Creation Failed ===")
            print("Error: \(error)")
            print("=============================")
        }
    }
}

// MARK: - Status Card
struct StatusCard: View {
    @ObservedObject var packageBuilder: PackageBuilder
    @ObservedObject var intuneUploader: IntuneMobileAppUploader
    let createdPackageURL: URL?
    let uploadProgress: Double
    let isUploading: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if packageBuilder.isBuilding {
                BuildingStatusView(progress: packageBuilder.buildProgress)
            } else if isUploading {
                UploadingStatusView(uploader: intuneUploader)
            } else if let pkgURL = createdPackageURL {
                if intuneUploader.uploadProgress >= 1.0 {
                    SuccessStatusView(
                        icon: "checkmark.icloud.fill",
                        title: "Successfully Deployed",
                        subtitle: "Package uploaded to Intune"
                    )
                } else {
                    SuccessStatusView(
                        icon: "checkmark.seal.fill",
                        title: "Package Built",
                        subtitle: pkgURL.lastPathComponent
                    )
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Building Status
struct BuildingStatusView: View {
    let progress: String
    
    var body: some View {
        HStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Building Package")
                    .font(.system(size: 16, weight: .semibold))
                Text(progress.isEmpty ? "Preparing..." : progress)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

// MARK: - Uploading Status
struct UploadingStatusView: View {
    @ObservedObject var uploader: IntuneMobileAppUploader
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uploading to Intune")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Step \(uploader.currentStepNumber)/\(uploader.totalSteps) • \(Int(uploader.uploadProgress * 100))%")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(uploader.currentStep)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                CircularProgressView(progress: uploader.uploadProgress)
                    .frame(width: 60, height: 60)
            }
            
            ProgressView(value: uploader.uploadProgress)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
    }
}

// MARK: - Success Status
struct SuccessStatusView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
    }
}

// MARK: - Primary Action Button
struct PrimaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: isHovering ? [.blue.opacity(0.8), .purple.opacity(0.8)] : [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: .blue.opacity(0.3), radius: isHovering ? 20 : 10, x: 0, y: isHovering ? 10 : 5)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Supporting Views
struct DependencyChip: View {
    let name: String
    
    var body: some View {
        Text(name)
            .font(.system(size: 13, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }
}

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 16, weight: .semibold))
        }
    }
}

// FlowLayout remains the same as before
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.positions[index].x + bounds.minX,
                                      y: result.positions[index].y + bounds.minY),
                          proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let dimensions = subview.dimensions(in: .unspecified)
                
                if x + dimensions.width > maxWidth, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                
                x += dimensions.width + spacing
                lineHeight = max(lineHeight, dimensions.height)
                size.width = max(size.width, x - spacing)
            }
            size.height = y + lineHeight
        }
    }
}
