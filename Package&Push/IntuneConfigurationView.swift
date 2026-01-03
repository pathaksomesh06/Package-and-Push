//
//  IntuneConfigurationView.swift
//  Package&Push
//
//  Created by Somesh Pathak on 12/07/2025.
//

import SwiftUI

struct IntuneConfigurationView: View {
    @StateObject private var config = IntuneAppConfiguration()
    @ObservedObject var authManager: AuthenticationManager
    @StateObject private var uploader: IntuneMobileAppUploader
    @State private var selectedTab: ConfigurationTab = .appInfo
    @State private var isUploading = false
    @State private var uploadProgress = 0.0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessScreen = false
    @Environment(\.dismiss) private var dismiss
    @State private var showCancelAlert = false
    @State private var showVersionUpdateConfirmation = false
    @State private var versionUpdateInfo: (appId: String, appName: String, oldVersion: String, newVersion: String)? = nil
    
    let packageURL: URL
    let packageName: String
    let packageVersion: String
    let bundleId: String
    let onUploadComplete: (() -> Void)?
    
    init(packageURL: URL, packageName: String, packageVersion: String, bundleId: String, authManager: AuthenticationManager, onUploadComplete: (() -> Void)? = nil) {
        self.packageURL = packageURL
        self.packageName = packageName
        self.packageVersion = packageVersion
        self.bundleId = bundleId
        self.authManager = authManager
        self.onUploadComplete = onUploadComplete
        self._uploader = StateObject(wrappedValue: IntuneMobileAppUploader(authManager: authManager))
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            HStack(spacing: 0) {
                // Sidebar - Fixed position (locked, not resizable)
                VStack(spacing: 0) {
                    ModernSidebar(
                        selectedTab: $selectedTab,
                        config: config,
                        packageName: packageName,
                        packageVersion: packageVersion,
                        isUploading: isUploading
                    )
                }
                .frame(width: 260)
                .background(Color(NSColor.controlBackgroundColor))
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1) // Prevent resizing
                
                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1)
                
                // Main Content
                VStack(spacing: 0) {
                    // Top Bar
                    ModernTopBar(
                        selectedTab: selectedTab,
                        onCancel: { showCancelAlert = true },
                        isUploading: isUploading
                    )
                    
                    // Content Area
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            switch selectedTab {
                            case .appInfo:
                                ModernAppInfoSection(config: config)
                            case .program:
                                ModernProgramSection(config: config)
                            case .requirements:
                                ModernRequirementsSection(config: config)
                            case .detectionRules:
                                ModernDetectionSection(config: config)
                            case .assignments:
                                AssignmentsView(config: config, authManager: authManager)
                            case .review:
                                ModernReviewSection(config: config, packageName: packageName)
                            }
                        }
                        .padding(32)
                    }
                    
                    // Bottom Bar
                    ModernBottomBar(
                        selectedTab: $selectedTab,
                        config: config,
                        isUploading: $isUploading,
                        uploader: uploader,
                        onUpload: uploadToIntune
                    )
                }
            }
            
            // Upload Overlay
            if isUploading {
                UploadOverlay(uploader: uploader)
            }
            
            // Success Screen
            if showSuccessScreen, let result = uploader.uploadResult {
                UploadSuccessView(result: result, onDone: {
                    // Call the completion callback if provided
                    onUploadComplete?()
                    // Dismiss the configuration view
                    dismiss()
                })
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            config.populateFromPackage(
                name: packageName,
                version: packageVersion,
                bundleId: bundleId,
                url: packageURL
            )
        }
        .alert("Discard Changes?", isPresented: $showCancelAlert, actions: {
            Button("Discard", role: .destructive) {
                // Call the completion callback to reset to default search screen
                onUploadComplete?()
                // Dismiss the configuration view
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        }, message: {
            Text("Your configuration changes will be lost.")
        })
        .alert("Upload Error", isPresented: $showError) {
            Button("OK") {
                // Call the completion callback to reset to default search screen
                onUploadComplete?()
                // Dismiss the configuration view
                dismiss()
            }
        } message: {
            Text(errorMessage)
        }
        .alert("Update Existing App?", isPresented: $showVersionUpdateConfirmation) {
            Button("Cancel", role: .cancel) {
                isUploading = false
            }
            Button("Update App") {
                proceedWithVersionUpdate()
            }
        } message: {
            if let info = versionUpdateInfo {
                Text("An app with the same bundle ID already exists in Intune:\n\n\(info.appName)\nCurrent version: \(info.oldVersion)\nNew version: \(info.newVersion)\n\nThis will update the existing app to the new version. Existing assignments will be preserved.")
            }
        }
    }
    
    private func uploadToIntune() {
        guard let packageURL = config.packageURL else { return }
        
        Task {
            do {
                isUploading = true
                uploadProgress = 0.0
                
                try await uploader.uploadConfiguredPackage(
                    packageURL: packageURL,
                    configuration: config
                )
                
                uploadProgress = 1.0
                
                // Show success screen instead of dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isUploading = false
                    showSuccessScreen = true
                }
            } catch let error as UploadError {
                // Handle version update required error
                if case .versionUpdateRequired(let appId, let appName, let oldVersion, let newVersion) = error {
                    versionUpdateInfo = (appId: appId, appName: appName, oldVersion: oldVersion, newVersion: newVersion)
                    showVersionUpdateConfirmation = true
                    // Don't set isUploading = false here, we'll continue after confirmation
                } else {
                    errorMessage = error.localizedDescription
                    showError = true
                    isUploading = false
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isUploading = false
            }
        }
    }
    
    private func proceedWithVersionUpdate() {
        guard let packageURL = config.packageURL,
              let info = versionUpdateInfo else {
            isUploading = false
            return
        }
        
        Task {
            do {
                isUploading = true
                uploadProgress = 0.0
                
                // Fetch assignments first and show them in UI before starting upload
                print("[UI] Fetching existing assignments from Intune...")
                try await uploader.fetchAndPopulateAssignments(appId: info.appId, configuration: config)
                
                // Switch to Assignments tab to show fetched assignments
                await MainActor.run {
                    selectedTab = .assignments
                    // Force UI update to show fetched assignments
                }
                
                // Wait a moment for UI to update and user to see the assignments
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Now proceed with upload
                try await uploader.proceedWithVersionUpdate(
                    packageURL: packageURL,
                    configuration: config,
                    existingAppId: info.appId
                )
                
                uploadProgress = 1.0
                
                // Show success screen instead of dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isUploading = false
                    showSuccessScreen = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isUploading = false
            }
        }
    }
}

// MARK: - Modern Sidebar
struct ModernSidebar: View {
    @Binding var selectedTab: ConfigurationTab
    let config: IntuneAppConfiguration
    let packageName: String
    let packageVersion: String
    let isUploading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Info Header
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(packageName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text("Version \(packageVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.05))
            
            Divider()
            
            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(ConfigurationTab.allCases, id: \.self) { tab in
                        SidebarNavItem(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            isCompleted: isTabCompleted(tab),
                            isDisabled: isUploading,
                            action: { if !isUploading { selectedTab = tab } }
                        )
                    }
                }
                .padding(12)
            }
            
            Spacer()
            
            Divider()
            
            // Progress Indicator
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Completion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(completedSteps)/\(ConfigurationTab.allCases.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * completionProgress, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(20)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .frame(width: 260)
    }
    
    private var completedSteps: Int {
        ConfigurationTab.allCases.filter { isTabCompleted($0) }.count
    }
    
    private var completionProgress: CGFloat {
        CGFloat(completedSteps) / CGFloat(ConfigurationTab.allCases.count)
    }
    
    private func isTabCompleted(_ tab: ConfigurationTab) -> Bool {
        switch tab {
        case .appInfo:
            return !config.displayName.isEmpty
        case .program:
            return true
        case .requirements:
            return true
        case .detectionRules:
            return !config.bundleId.isEmpty && !config.bundleVersion.isEmpty
        case .assignments:
            return true
        case .review:
            return config.isValid
        }
    }
}

// MARK: - Sidebar Nav Item
struct SidebarNavItem: View {
    let tab: ConfigurationTab
    let isSelected: Bool
    let isCompleted: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : (isSelected ? Color.blue : Color.gray.opacity(0.3)))
                        .frame(width: 28, height: 28)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text(tab.stepNumber)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                    }
                }
                
                Text(tab.shortName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 3, height: 20)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

// MARK: - Modern Top Bar
struct ModernTopBar: View {
    let selectedTab: ConfigurationTab
    let onCancel: () -> Void
    let isUploading: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedTab.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(selectedTab.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Cancel")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(isUploading)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Modern Bottom Bar
struct ModernBottomBar: View {
    @Binding var selectedTab: ConfigurationTab
    let config: IntuneAppConfiguration
    @Binding var isUploading: Bool
    @ObservedObject var uploader: IntuneMobileAppUploader
    let onUpload: () -> Void
    
    var body: some View {
        HStack {
            // Previous Button
            Button(action: goToPrevious) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Previous")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(selectedTab == .appInfo || isUploading)
            .opacity(selectedTab == .appInfo ? 0.5 : 1)
            
            Spacer()
            
            // Next/Upload Button
            if selectedTab == .review {
                Button(action: onUpload) {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.system(size: 14))
                        Text("Deploy to Intune")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: config.isValid ? [.blue, .purple] : [.gray, .gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: config.isValid ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!config.isValid || isUploading)
            } else {
                Button(action: goToNext) {
                    HStack(spacing: 6) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isUploading)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(
            Color(NSColor.windowBackgroundColor)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4)
        )
    }
    
    private func goToPrevious() {
        if let currentIndex = ConfigurationTab.allCases.firstIndex(of: selectedTab),
           currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = ConfigurationTab.allCases[currentIndex - 1]
            }
        }
    }
    
    private func goToNext() {
        if let currentIndex = ConfigurationTab.allCases.firstIndex(of: selectedTab),
           currentIndex < ConfigurationTab.allCases.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = ConfigurationTab.allCases[currentIndex + 1]
            }
        }
    }
}

// MARK: - Upload Overlay
struct UploadOverlay: View {
    @ObservedObject var uploader: IntuneMobileAppUploader
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated Icon
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: uploader.uploadProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Deploying to Intune")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(uploader.currentStep)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                VStack(spacing: 8) {
                    Text("\(Int(uploader.uploadProgress * 100))%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Step \(uploader.currentStepNumber) of \(uploader.totalSteps)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Button {
                    uploader.cancelUpload()
                } label: {
                    Text("Cancel")
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

// MARK: - Upload Success View
struct UploadSuccessView: View {
    let result: UploadResult
    let onDone: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Success Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Successfully Deployed!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Your app is now available in Microsoft Intune")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // App Details Card
                VStack(alignment: .leading, spacing: 16) {
                    SuccessDetailRow(label: "App Name", value: result.appName)
                    SuccessDetailRow(label: "Version", value: result.appVersion)
                    SuccessDetailRow(label: "Bundle ID", value: result.bundleId)
                    SuccessDetailRow(label: "App ID", value: result.appId)
                    
                    Divider()
                    
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Required")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.blue)
                                Text("\(result.requiredGroupsAssigned) groups")
                                    .fontWeight(.medium)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: "person.2")
                                    .foregroundColor(.green)
                                Text("\(result.availableGroupsAssigned) groups")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    
                    Divider()
                    
                    SuccessDetailRow(label: "Deployed", value: dateFormatter.string(from: result.timestamp))
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .frame(width: 400)
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button {
                        // Open Intune admin center
                        if let url = URL(string: "https://intune.microsoft.com/#view/Microsoft_Intune_Apps/SettingsMenu/~/0/appId/\(result.appId)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("View in Intune")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onDone()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Done")
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(48)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 10)
            )
        }
    }
}

struct SuccessDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
    }
}

// MARK: - Modern Section Card
struct ModernSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Modern Form Field
struct ModernFormField<Content: View>: View {
    let label: String
    let isRequired: Bool
    let content: Content
    
    init(label: String, isRequired: Bool = false, @ViewBuilder content: () -> Content) {
        self.label = label
        self.isRequired = isRequired
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
            }
            
            content
        }
    }
}

// MARK: - Modern App Info Section
struct ModernAppInfoSection: View {
    @ObservedObject var config: IntuneAppConfiguration
    
    var body: some View {
        VStack(spacing: 24) {
            ModernSectionCard(title: "Basic Information", icon: "info.circle.fill") {
                VStack(spacing: 20) {
                    ModernFormField(label: "App Name", isRequired: true) {
                        TextField("Enter app name", text: $config.displayName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    ModernFormField(label: "Description") {
                        TextEditor(text: $config.description)
                            .font(.body)
                            .frame(height: 80)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    HStack(spacing: 20) {
                        ModernFormField(label: "Publisher") {
                            TextField("Enter publisher", text: $config.publisher)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        ModernFormField(label: "Category") {
                            Picker("", selection: $config.category) {
                                Text("No Category").tag("")
                                Text("Productivity").tag("Productivity")
                                Text("Developer Tools").tag("Developer Tools")
                                Text("Utilities").tag("Utilities")
                                Text("Business").tag("Business")
                            }
                            .pickerStyle(.menu)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            ModernSectionCard(title: "Additional Details", icon: "link") {
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        ModernFormField(label: "Developer") {
                            TextField("Enter developer name", text: $config.developer)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        ModernFormField(label: "Owner") {
                            TextField("Enter owner", text: $config.owner)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    HStack(spacing: 20) {
                        ModernFormField(label: "Information URL") {
                            TextField("https://example.com", text: $config.informationUrl)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        ModernFormField(label: "Privacy URL") {
                            TextField("https://example.com/privacy", text: $config.privacyUrl)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    ModernFormField(label: "Notes") {
                        TextEditor(text: $config.notes)
                            .font(.body)
                            .frame(height: 60)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

// MARK: - Modern Program Section
struct ModernProgramSection: View {
    @ObservedObject var config: IntuneAppConfiguration
    
    var body: some View {
        VStack(spacing: 24) {
            ModernSectionCard(title: "Installation Scripts", icon: "terminal.fill") {
                VStack(spacing: 24) {
                    Text("Configure optional scripts to run before or after the app installation.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ModernFormField(label: "Pre-install Script") {
                        TextEditor(text: $config.preInstallScript)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 150)
                            .padding(12)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    ModernFormField(label: "Post-install Script") {
                        TextEditor(text: $config.postInstallScript)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 150)
                            .padding(12)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Modern Requirements Section
struct ModernRequirementsSection: View {
    @ObservedObject var config: IntuneAppConfiguration
    
    var body: some View {
        VStack(spacing: 24) {
            ModernSectionCard(title: "System Requirements", icon: "desktopcomputer") {
                VStack(spacing: 20) {
                    ModernFormField(label: "Minimum macOS Version", isRequired: true) {
                        Picker("", selection: $config.minimumOS) {
                            ForEach(MacOSVersion.allCases, id: \.self) { version in
                                Text(version.rawValue).tag(version)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .frame(maxWidth: 300)
                    }
                    
                    Toggle(isOn: $config.ignoreAppVersion) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ignore app version")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Install regardless of existing version")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
            }
        }
    }
}

// MARK: - Modern Detection Section
struct ModernDetectionSection: View {
    @ObservedObject var config: IntuneAppConfiguration
    
    var body: some View {
        VStack(spacing: 24) {
            ModernSectionCard(title: "App Detection", icon: "magnifyingglass") {
                VStack(spacing: 20) {
                    Text("Configure how Intune detects if this app is installed on a device.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ModernFormField(label: "Bundle ID", isRequired: true) {
                        TextField("com.example.app", text: $config.bundleId)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    ModernFormField(label: "Bundle Version", isRequired: true) {
                        TextField("1.0.0", text: $config.bundleVersion)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

// MARK: - Modern Review Section
struct ModernReviewSection: View {
    @ObservedObject var config: IntuneAppConfiguration
    let packageName: String
    
    var body: some View {
        VStack(spacing: 24) {
            // Summary Card
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(config.displayName.isEmpty ? packageName : config.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Version \(config.bundleVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(config.publisher)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if config.isValid {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ready to deploy")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("Missing required fields")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            
            // Details
            HStack(alignment: .top, spacing: 24) {
                ModernSectionCard(title: "App Information", icon: "info.circle.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        ModernReviewRow(label: "Name", value: config.displayName)
                        ModernReviewRow(label: "Bundle ID", value: config.bundleId)
                        ModernReviewRow(label: "Version", value: config.bundleVersion)
                        ModernReviewRow(label: "Publisher", value: config.publisher)
                    }
                }
                
                ModernSectionCard(title: "Requirements", icon: "desktopcomputer") {
                    VStack(alignment: .leading, spacing: 12) {
                        ModernReviewRow(label: "Min macOS", value: config.minimumOS.rawValue)
                        ModernReviewRow(label: "Ignore Version", value: config.ignoreAppVersion ? "Yes" : "No")
                    }
                }
            }
        }
    }
}

struct ModernReviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
