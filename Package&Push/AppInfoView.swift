//
//  AppInfoView.swift
//  Package&Push
//
//  Created by Somesh Pathak on 12/07/2025.
//


//
//  IntuneTabViews.swift
//  Package&Push
//
//  Created by Somesh Pathak on 12/07/2025.
//

import SwiftUI

// MARK: - App Info View
struct AppInfoView: View {
    @ObservedObject var config: IntuneAppConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            FormField(label: "Name", isRequired: true) {
                TextField("Enter app name", text: $config.displayName)
                    .textFieldStyle(.roundedBorder)
            }
            
            FormField(label: "Description") {
                TextEditor(text: $config.description)
                    .frame(height: 80)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
            
            FormField(label: "Publisher") {
                TextField("Enter publisher", text: $config.publisher)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 20) {
                FormField(label: "Category") {
                    Picker("Select category", selection: $config.category) {
                        Text("No Category").tag("")
                        Text("Productivity").tag("Productivity")
                        Text("Developer Tools").tag("Developer Tools")
                        Text("Utilities").tag("Utilities")
                        Text("Business").tag("Business")
                    }
                    .pickerStyle(.menu)
                }
                
                FormField(label: "Logo") {
                    Button("Select file") {
                        // TODO: Implement logo selection
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            FormField(label: "Information URL") {
                TextField("https://", text: $config.informationUrl)
                    .textFieldStyle(.roundedBorder)
            }
            
            FormField(label: "Privacy URL") {
                TextField("https://", text: $config.privacyUrl)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 20) {
                FormField(label: "Developer") {
                    TextField("Enter developer", text: $config.developer)
                        .textFieldStyle(.roundedBorder)
                }
                
                FormField(label: "Owner") {
                    TextField("Enter owner", text: $config.owner)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            FormField(label: "Notes") {
                TextEditor(text: $config.notes)
                    .frame(height: 60)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - Program View
struct ProgramView: View {
    @ObservedObject var config: IntuneAppConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Configure the app installation scripts.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            FormField(label: "Pre-install script", info: true) {
                TextEditor(text: $config.preInstallScript)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 200)
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            FormField(label: "Post-install script", info: true) {
                TextEditor(text: $config.postInstallScript)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 200)
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Requirements View
struct RequirementsView: View {
    @ObservedObject var config: IntuneAppConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            FormField(label: "Minimum operating system", isRequired: true, info: true) {
                Picker("Select one", selection: $config.minimumOS) {
                    ForEach(MacOSVersion.allCases, id: \.self) { version in
                        Text(version.rawValue).tag(version)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 300)
                .padding(8)
                .background(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            
            Spacer()
        }
    }
}

// MARK: - Detection Rules View
struct DetectionRulesView: View {
    @ObservedObject var config: IntuneAppConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Ignore app version")
                    .font(.subheadline)
                
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Spacer()
                
                Toggle("", isOn: $config.ignoreAppVersion)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            Text("Configure the app bundle identifiers and version numbers to be used to detect the presence of the app.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Included apps")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Provide the list of apps included in the uploaded file. The app list is case-sensitive. The app listed first is used as the primary app in app reporting.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("App bundle ID (CFBundleIdentifier)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(config.bundleId)
                            .font(.system(.body, design: .monospaced))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading) {
                        Text("App version (CFBundleShortVersionString)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(config.bundleVersion)
                            .font(.system(.body, design: .monospaced))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button(action: {}) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                
                HStack(spacing: 20) {
                    TextField("Enter bundle ID", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    
                    TextField("Enter app version", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                }
            }
        }
    }
}

// MARK: - Assignments View
struct AssignmentsView: View {
    @ObservedObject var config: IntuneAppConfiguration
    @ObservedObject var authManager: AuthenticationManager
    @State private var showGroupPicker = false
    @State private var addToRequired = true
    @State private var azureADService: AzureADService? = nil
    // Well-known Azure AD group IDs for All Users and All Devices
    let allUsersGroup = AzureADGroup(id: "e2361a68-7ee7-4b4c-9a7e-1b2c7c6a7b5a", displayName: "All Users")
    let allDevicesGroup = AzureADGroup(id: "b1e5c6c7-7e7e-4b4c-9a7e-1b2c7c6a7b5b", displayName: "All Devices")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Any macOS app deployed using Intune agent will not automatically be removed from the device when the device is retired. The app and data it contains will remain on the device. If the app is not removed prior to retiring the device, the end user will need to manually uninstall the app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
            
            // Required Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Required")
                        .font(.headline)
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                HStack {
                    Text("Group mode")
                        .frame(width: 100, alignment: .leading)
                    Text("Group")
                        .fontWeight(.medium)
                    Spacer()
                }
                
                if config.requiredGroups.isEmpty {
                    Text("No assignments")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(config.requiredGroups, id: \.id) { group in
                        HStack {
                            Text(group.displayName ?? group.id)
                                .padding(.vertical, 4)
                            Spacer()
                            Button(action: {
                                if let idx = config.requiredGroups.firstIndex(where: { $0.id == group.id }) {
                                    config.requiredGroups.remove(at: idx)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                HStack(spacing: 16) {
                    Button("+ Add group") {
                        addToRequired = true
                        showGroupPicker = true
                    }
                    .buttonStyle(.link)
                    Button("+ Add all users") {
                        if !config.requiredGroups.contains(where: { $0.id == allUsersGroup.id }) {
                            config.requiredGroups.append(allUsersGroup)
                        }
                    }
                    .buttonStyle(.link)
                    Button("+ Add all devices") {
                        if !config.requiredGroups.contains(where: { $0.id == allDevicesGroup.id }) {
                            config.requiredGroups.append(allDevicesGroup)
                        }
                    }
                    .buttonStyle(.link)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            // Available Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Available for enrolled devices")
                        .font(.headline)
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                HStack {
                    Text("Group mode")
                        .frame(width: 100, alignment: .leading)
                    Text("Group")
                        .fontWeight(.medium)
                    Spacer()
                }
                
                if config.availableGroups.isEmpty {
                    Text("No assignments")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(config.availableGroups, id: \.id) { group in
                        HStack {
                            Text(group.displayName ?? group.id)
                                .padding(.vertical, 4)
                            Spacer()
                            Button(action: {
                                if let idx = config.availableGroups.firstIndex(where: { $0.id == group.id }) {
                                    config.availableGroups.remove(at: idx)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                HStack(spacing: 16) {
                    Button("+ Add group") {
                        addToRequired = false
                        showGroupPicker = true
                    }
                    .buttonStyle(.link)
                    Button("+ Add all users") {
                        if !config.availableGroups.contains(where: { $0.id == allUsersGroup.id }) {
                            config.availableGroups.append(allUsersGroup)
                        }
                    }
                    .buttonStyle(.link)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .sheet(isPresented: $showGroupPicker) {
            GroupPickerView(isPresented: $showGroupPicker, authManager: authManager) { group in
                if addToRequired {
                    if !config.requiredGroups.contains(where: { $0.id == group.id }) {
                        config.requiredGroups.append(group)
                    }
                } else {
                    if !config.availableGroups.contains(where: { $0.id == group.id }) {
                        config.availableGroups.append(group)
                    }
                }
            }
        }
        .onAppear {
            if azureADService == nil {
                azureADService = AzureADService(authManager: authManager)
            }
        }
    }
}

struct GroupPickerView: View {
    @Binding var isPresented: Bool
    @ObservedObject var authManager: AuthenticationManager
    @State private var searchText = ""
    @State private var searchResults: [AzureADGroup] = []
    @State private var isSearching = false
    let onSelect: (AzureADGroup) -> Void
    var azureADService: AzureADService { AzureADService(authManager: authManager) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient accent
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                        }
                        
                        Text("Select Azure AD Group")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                TextField("Search groups by name...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onChange(of: searchText) { newValue in
                        performSearch(query: newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            Divider()
            
            // Results List
            if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                    }
                    
                    Text("No groups found")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            } else if searchResults.isEmpty && searchText.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text("Search for Azure AD Groups")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Enter a group name to find and add assignments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(searchResults, id: \.id) { group in
                            Button(action: {
                                onSelect(group)
                                isPresented = false
                            }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: "person.3.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 16))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.displayName ?? "Unnamed Group")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Text(group.id)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color(NSColor.textBackgroundColor))
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(searchResults.count) groups found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 550, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        Task {
            do {
                let results = try await azureADService.searchGroups(query: query)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                print("Group search error: \(error)")
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
}

// MARK: - Review View
struct ReviewView: View {
    @ObservedObject var config: IntuneAppConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Summary")
                .font(.headline)
            
            // App Information
            ReviewSection(title: "App information") {
                VStack(alignment: .leading, spacing: 8) {
                    ReviewRow(label: "App package file", value: config.packageName)
                    ReviewRow(label: "Name", value: config.displayName)
                    ReviewRow(label: "Description", value: config.description)
                    ReviewRow(label: "Publisher", value: config.publisher.isEmpty ? "No Publisher" : config.publisher)
                    ReviewRow(label: "Category", value: config.category.isEmpty ? "No Category" : config.category)
                    ReviewRow(label: "Information URL", value: config.informationUrl.isEmpty ? "No Information URL" : config.informationUrl)
                    ReviewRow(label: "Privacy URL", value: config.privacyUrl.isEmpty ? "No Privacy URL" : config.privacyUrl)
                    ReviewRow(label: "Developer", value: config.developer.isEmpty ? "No Developer" : config.developer)
                    ReviewRow(label: "Owner", value: config.owner.isEmpty ? "No Owner" : config.owner)
                    ReviewRow(label: "Notes", value: config.notes.isEmpty ? "No Notes" : config.notes)
                    ReviewRow(label: "Logo", value: "No logo")
                }
            }
            
            // Program
            ReviewSection(title: "Program") {
                VStack(alignment: .leading, spacing: 8) {
                    ReviewRow(label: "Pre-install script", value: config.preInstallScript.isEmpty ? "No Pre-install script" : "Configured")
                    ReviewRow(label: "Post-install script", value: config.postInstallScript.isEmpty ? "No Post-install script" : "Configured")
                }
            }
            
            // Requirements
            ReviewSection(title: "Requirements") {
                ReviewRow(label: "Minimum operating system", value: config.minimumOS.rawValue)
            }
            
            // Detection Rules
            ReviewSection(title: "Detection rules") {
                VStack(alignment: .leading, spacing: 8) {
                    ReviewRow(label: "Ignore app version", value: config.ignoreAppVersion ? "Yes" : "No")
                    ReviewRow(label: "Included apps", value: "\(config.bundleId) \(config.bundleVersion)")
                }
            }
            
            // Assignments
            ReviewSection(title: "Assignments") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Group mode")
                            .frame(width: 200, alignment: .leading)
                        Text("Group")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Required")
                            .frame(width: 200, alignment: .leading)
                            .padding(.leading, 20)
                        Text(config.requiredGroups.isEmpty ? "No assignments" : config.requiredGroups.map { $0.displayName ?? $0.id }.joined(separator: ", "))
                    }
                    
                    HStack {
                        Text("Available for enrolled devices")
                            .frame(width: 200, alignment: .leading)
                            .padding(.leading, 20)
                        Text(config.availableGroups.isEmpty ? "No assignments" : config.availableGroups.map { $0.displayName ?? $0.id }.joined(separator: ", "))
                    }
                }
                .font(.caption)
            }
        }
    }
}

// MARK: - Helper Views
struct FormField<Content: View>: View {
    let label: String
    var isRequired: Bool = false
    var info: Bool = false
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
                
                if info {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            content()
        }
    }
}

struct ReviewSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .font(.caption)
        }
    }
}

struct ReviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .frame(width: 150, alignment: .leading)
                .foregroundColor(.secondary)
            
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}