//
//  IntuneMobileAppUploader.swift
//  Package&Push
//
//  Created by Somesh Pathak on 12/07/2025.
//

import Foundation
import CryptoKit
import CommonCrypto

// Simple async semaphore for limiting concurrent operations
actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.count = value
    }
    
    func wait() async {
        if count > 0 {
            count -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
    
    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            count += 1
        }
    }
}

// Thread-safe progress counter
actor ProgressCounter {
    private var count: Int
    private let total: Int
    
    init(total: Int) {
        self.count = 0
        self.total = total
    }
    
    func increment() async -> Int {
        count += 1
        return count
    }
}

// Upload result for success screen
struct UploadResult {
    let appId: String
    let appName: String
    let appVersion: String
    let bundleId: String
    let requiredGroupsAssigned: Int
    let availableGroupsAssigned: Int
    let timestamp: Date
}

class IntuneMobileAppUploader: ObservableObject {
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading = false
    @Published var errorMessage: String?
    @Published var currentStep: String = ""
    @Published var currentStepNumber: Int = 0
    @Published var totalSteps: Int = 8 // Updated to include assignment step
    @Published var uploadResult: UploadResult? = nil
    @Published var uploadCompleted: Bool = false
    @Published var existingAppInfo: ExistingAppInfo? = nil
    @Published var showVersionUpdateConfirmation: Bool = false
    @Published var pendingVersionUpdate: (appId: String, appName: String, oldVersion: String, newVersion: String)? = nil
    
    private let config = AppConfiguration.shared
    private let graphEndpoint: String
    private var authManager: AuthenticationManager
    
    // Info about existing app found in Intune
    struct ExistingAppInfo {
        let appId: String
        let displayName: String
        let bundleId: String
        let version: String
        let isSameVersion: Bool
    }
    
    // Add task reference for cancellation
    private(set) var currentUploadTask: Task<Void, Error>?
    
    // URLSession with longer timeout for large file uploads
    private lazy var uploadSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 minutes
        configuration.timeoutIntervalForResource = 1800 // 30 minutes
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()
    
    func cancelUpload() {
        currentUploadTask?.cancel()
        isUploading = false
        errorMessage = "Upload cancelled"
    }
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        self.graphEndpoint = "\(config.graphEndpoint)/beta"
    }
    
    func uploadPackageToIntune(packageURL: URL, appName: String, version: String, bundleId: String? = nil) async throws {
        if Task.isCancelled { throw CancellationError() }
        let config = IntuneAppConfiguration()
        config.displayName = appName
        config.bundleVersion = version
        config.description = "Homebrew package: \(appName)"
        config.bundleId = bundleId ?? "com.homebrew.\(appName)"
        try await uploadConfiguredPackage(packageURL: packageURL, configuration: config)
    }
    
    // Check for existing app before upload - returns info if version update is needed
    func checkForVersionUpdate(bundleId: String, version: String) async throws -> ExistingAppInfo? {
        return try await checkForExistingApp(bundleId: bundleId, version: version)
    }
    
    // Proceed with upload after user confirms version update
    // Note: Assignments should already be fetched and populated by the UI before calling this
    func proceedWithVersionUpdate(packageURL: URL, configuration: IntuneAppConfiguration, existingAppId: String) async throws {
        // Assignments should already be fetched and populated by the UI before calling this
        // Now proceed with upload using existing app ID
        try await uploadConfiguredPackageWithExistingApp(packageURL: packageURL, configuration: configuration, existingAppId: existingAppId)
    }
    
    // Internal function to upload with existing app ID (skips app creation)
    private func uploadConfiguredPackageWithExistingApp(packageURL: URL, configuration: IntuneAppConfiguration, existingAppId: String) async throws {
        if Task.isCancelled { throw CancellationError() }
        
        // Create and store the task
        let task = Task {
            do {
                await MainActor.run {
                    self.isUploading = true
                    self.uploadProgress = 0.0
                    self.errorMessage = nil
                    self.currentStep = "Preparing upload..."
                    self.currentStepNumber = 0
                }
                
                // Step 1: Use existing app ID
                if Task.isCancelled { throw CancellationError() }
                let appId = existingAppId
                await MainActor.run {
                    self.currentStep = "Updating existing app in Intune..."
                    self.currentStepNumber = 1
                    self.uploadProgress = 0.05
                }
                print("[Upload] Step 1: Using existing app ID: \(appId)")
                
                // Continue with rest of upload steps (same as regular upload)
                // Step 2: Create content version
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Creating content version..."
                    self.currentStepNumber = 2
                    self.uploadProgress = 0.10
                }
                print("[Upload] Step 2: Creating content version...")
                let contentVersionId = try await createContentVersion(appId: appId)
                print("[Upload] Step 2: Content version created: \(contentVersionId)")
                
                // Step 3: Create content file
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Encrypting and preparing file..."
                    self.currentStepNumber = 3
                    self.uploadProgress = 0.15
                }
                print("[Upload] Step 3: Creating content file...")
                let fileInfo = try await createContentFile(appId: appId, contentVersionId: contentVersionId, packageURL: packageURL)
                print("[Upload] Step 3: Content file created: \(fileInfo.id)")
                
                // Step 4: Upload encrypted file
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Uploading to Azure Storage..."
                    self.currentStepNumber = 4
                    self.uploadProgress = 0.20
                }
                print("[Upload] Step 4: Uploading encrypted file to Azure Storage...")
                try await uploadFile(packageURL: fileInfo.encryptedFileURL, azureStorageUri: fileInfo.azureStorageUri)
                print("[Upload] Step 4: File upload completed")
                
                // Clean up encrypted file after upload
                try? FileManager.default.removeItem(at: fileInfo.encryptedFileURL)
                
                // Step 5: Wait for file to be ready (Azure Storage processing)
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Processing file in Azure..."
                    self.currentStepNumber = 5
                    self.uploadProgress = 0.75
                }
                print("[Upload] Step 5: Waiting for Azure Storage to process file...")
                try await waitForFileUploadState(appId: appId, contentVersionId: contentVersionId, fileId: fileInfo.id)
                print("[Upload] Step 5: File ready for commit")
                
                // Step 6: Commit file with encryption info
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Committing file..."
                    self.currentStepNumber = 6
                    self.uploadProgress = 0.80
                }
                print("[Upload] Step 6: Committing file...")
                try await commitContentFile(appId: appId, contentVersionId: contentVersionId, fileId: fileInfo.id, encryptionInfo: fileInfo.encryptionInfo)
                print("[Upload] Step 6: File commit request sent")
                
                // Step 6.5: Wait until service reports file commit success
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Waiting for file commit..."
                    self.uploadProgress = 0.85
                }
                print("[Upload] Step 6.5: Waiting for file commit to complete...")
                try await waitForFileCommitSuccess(appId: appId, contentVersionId: contentVersionId, fileId: fileInfo.id)
                print("[Upload] Step 6.5: File commit successful")
                
                // Step 7: Commit app
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Finalizing app in Intune..."
                    self.currentStepNumber = 7
                    self.uploadProgress = 0.90
                }
                print("[Upload] Step 7: Committing app...")
                try await commitApp(appId: appId, contentVersionId: contentVersionId, packageURL: packageURL, configuration: configuration, isVersionUpdate: true)
                print("[Upload] Step 7: App commit successful")
                
                // Step 8: Assign groups (assignments should already be populated from fetch)
                if Task.isCancelled { throw CancellationError() }
                var requiredAssigned = 0
                var availableAssigned = 0
                
                if !configuration.requiredGroups.isEmpty || !configuration.availableGroups.isEmpty {
                    await MainActor.run {
                        self.currentStep = "Assigning groups..."
                        self.currentStepNumber = 8
                        self.uploadProgress = 0.95
                    }
                    print("[Upload] Step 8: Assigning groups...")
                    
                    // Assign required groups
                    for group in configuration.requiredGroups {
                        do {
                            print("[Upload] Attempting to assign group \(group.displayName ?? group.id) (ID: \(group.id)) as required...")
                            try await assignAppToGroup(appId: appId, groupId: group.id, intent: .required)
                            requiredAssigned += 1
                            print("[Upload] ✓ Assigned \(group.displayName ?? group.id) as required")
                        } catch {
                            print("[Upload] ✗ Failed to assign \(group.displayName ?? group.id) as required: \(error)")
                        }
                    }
                    
                    // Assign available groups
                    for group in configuration.availableGroups {
                        do {
                            print("[Upload] Attempting to assign group \(group.displayName ?? group.id) (ID: \(group.id)) as available...")
                            try await assignAppToGroup(appId: appId, groupId: group.id, intent: .available)
                            availableAssigned += 1
                            print("[Upload] ✓ Assigned \(group.displayName ?? group.id) as available")
                        } catch {
                            print("[Upload] ✗ Failed to assign \(group.displayName ?? group.id) as available: \(error)")
                        }
                    }
                    print("[Upload] Step 8: Group assignments complete (\(requiredAssigned) required, \(availableAssigned) available)")
                }
                
                // Clean up original package file from temp directory
                let tempPath = packageURL.path
                if tempPath.contains("/var/folders/") || tempPath.contains("/tmp/") || tempPath.contains("Temporary") {
                    try? FileManager.default.removeItem(at: packageURL)
                    print("[Upload] Cleaned up temp package file: \(packageURL.lastPathComponent)")
                }
                
                let result = UploadResult(
                    appId: appId,
                    appName: configuration.displayName,
                    appVersion: configuration.bundleVersion,
                    bundleId: configuration.bundleId,
                    requiredGroupsAssigned: requiredAssigned,
                    availableGroupsAssigned: availableAssigned,
                    timestamp: Date()
                )

                await MainActor.run {
                    self.currentStep = "Upload complete!"
                    self.uploadProgress = 1.0
                    self.uploadResult = result
                    self.uploadCompleted = true
                    self.isUploading = false
                }
                print("[Upload] Upload completed successfully!")
            } catch is CancellationError {
                print("[Upload] Upload cancelled")
                await MainActor.run {
                    self.isUploading = false
                    self.errorMessage = "Upload cancelled"
                }
                throw CancellationError()
            } catch {
                print("[Upload] Upload failed: \(error)")
                if let uploadError = error as? UploadError {
                    print("[Upload] Error type: \(uploadError)")
                }
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isUploading = false
                }
                throw error
            }
        }
        
        currentUploadTask = task
        try await task.value
    }
    
    func uploadConfiguredPackage(packageURL: URL, configuration: IntuneAppConfiguration) async throws {
        if Task.isCancelled { throw CancellationError() }
        
        // Create and store the task
        let task = Task {
            do {
                await MainActor.run {
                    self.isUploading = true
                    self.uploadProgress = 0.0
                    self.errorMessage = nil
                    self.currentStep = "Preparing upload..."
                    self.currentStepNumber = 0
                }
                
                // Step 0: Check if app already exists
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Checking for existing app..."
                    self.currentStepNumber = 0
                    self.uploadProgress = 0.02
                }
                print("[Upload] Step 0: Checking for existing app with bundle ID: \(configuration.bundleId), version: \(configuration.bundleVersion)...")
                let existingApp = try await checkForExistingApp(bundleId: configuration.bundleId, version: configuration.bundleVersion)
                
                if let existing = existingApp {
                    await MainActor.run {
                        self.existingAppInfo = existing
                    }
                    if existing.isSameVersion {
                        print("[Upload] Warning: App with same bundle ID and version already exists: \(existing.displayName) (ID: \(existing.appId))")
                        throw UploadError.duplicateAppVersion(existingAppId: existing.appId, existingAppName: existing.displayName)
                    } else {
                        // Different version - throw error to trigger confirmation dialog
                        print("[Upload] Info: App with same bundle ID but different version exists: \(existing.displayName) (ID: \(existing.appId), Version: \(existing.version))")
                        throw UploadError.versionUpdateRequired(existingAppId: existing.appId, existingAppName: existing.displayName, oldVersion: existing.version, newVersion: configuration.bundleVersion)
                    }
                } else {
                    await MainActor.run {
                        self.existingAppInfo = nil
                    }
                    print("[Upload] No existing app found, will create new app")
                }
                
                // Step 1: Create app entry
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Creating app entry in Intune..."
                    self.currentStepNumber = 1
                    self.uploadProgress = 0.05
                }
                print("[Upload] Step 1: Creating new app entry...")
                let appId = try await createMacOSLobApp(packageURL: packageURL, configuration: configuration)
                print("[Upload] Step 1: App created with ID: \(appId)")
                
                // Step 2: Create content version
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Creating content version..."
                    self.currentStepNumber = 2
                    self.uploadProgress = 0.10
                }
                print("[Upload] Step 2: Creating content version...")
                let contentVersionId = try await createContentVersion(appId: appId)
                print("[Upload] Step 2: Content version created: \(contentVersionId)")
                
                // Step 3: Create content file
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Encrypting and preparing file..."
                    self.currentStepNumber = 3
                    self.uploadProgress = 0.15
                }
                print("[Upload] Step 3: Creating content file...")
                let fileInfo = try await createContentFile(appId: appId, contentVersionId: contentVersionId, packageURL: packageURL)
                print("[Upload] Step 3: Content file created: \(fileInfo.id)")
                
                // Step 4: Upload encrypted file
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Uploading to Azure Storage..."
                    self.currentStepNumber = 4
                    self.uploadProgress = 0.20
                }
                print("[Upload] Step 4: Uploading encrypted file to Azure Storage...")
                try await uploadFile(packageURL: fileInfo.encryptedFileURL, azureStorageUri: fileInfo.azureStorageUri)
                print("[Upload] Step 4: File upload completed")
                
                // Clean up encrypted file after upload
                try? FileManager.default.removeItem(at: fileInfo.encryptedFileURL)
                
                // Step 5: Wait for file to be ready (Azure Storage processing)
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Processing file in Azure..."
                    self.currentStepNumber = 5
                    self.uploadProgress = 0.75
                }
                print("[Upload] Step 5: Waiting for Azure Storage to process file...")
                try await waitForFileUploadState(appId: appId, contentVersionId: contentVersionId, fileId: fileInfo.id)
                print("[Upload] Step 5: File ready for commit")
                
                // Step 6: Commit file with encryption info
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Committing file..."
                    self.currentStepNumber = 6
                    self.uploadProgress = 0.80
                }
                print("[Upload] Step 6: Committing file...")
                try await commitContentFile(appId: appId, contentVersionId: contentVersionId, fileId: fileInfo.id, encryptionInfo: fileInfo.encryptionInfo)
                print("[Upload] Step 6: File commit request sent")
                
                // Step 6.5: Wait until service reports file commit success
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Waiting for file commit..."
                    self.uploadProgress = 0.85
                }
                print("[Upload] Step 6.5: Waiting for file commit to complete...")
                try await waitForFileCommitSuccess(appId: appId, contentVersionId: contentVersionId, fileId: fileInfo.id)
                print("[Upload] Step 6.5: File commit successful")
                
                // Step 7: Commit app
                if Task.isCancelled { throw CancellationError() }
                await MainActor.run {
                    self.currentStep = "Finalizing app in Intune..."
                    self.currentStepNumber = 7
                    self.uploadProgress = 0.90
                }
                print("[Upload] Step 7: Committing app...")
                try await commitApp(appId: appId, contentVersionId: contentVersionId, packageURL: packageURL, configuration: configuration)
                print("[Upload] Step 7: App commit successful")
                
                // Wait a moment for the app to be fully ready before assigning
                print("[Upload] Waiting for app to be ready for assignments...")
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Step 8: Assign groups
                if Task.isCancelled { throw CancellationError() }
                var requiredAssigned = 0
                var availableAssigned = 0
                
                if !configuration.requiredGroups.isEmpty || !configuration.availableGroups.isEmpty {
                    await MainActor.run {
                        self.currentStep = "Assigning groups..."
                        self.currentStepNumber = 8
                        self.uploadProgress = 0.95
                    }
                    print("[Upload] Step 8: Assigning groups...")
                    
                    // Assign required groups
                    for group in configuration.requiredGroups {
                        do {
                            print("[Upload] Attempting to assign group \(group.displayName ?? group.id) (ID: \(group.id)) as required...")
                            try await assignAppToGroup(appId: appId, groupId: group.id, intent: .required)
                            requiredAssigned += 1
                            print("[Upload] ✓ Assigned \(group.displayName ?? group.id) as required")
                        } catch {
                            print("[Upload] ✗ Failed to assign \(group.displayName ?? group.id) as required: \(error)")
                        }
                    }
                    
                    // Assign available groups
                    for group in configuration.availableGroups {
                        do {
                            print("[Upload] Attempting to assign group \(group.displayName ?? group.id) (ID: \(group.id)) as available...")
                            try await assignAppToGroup(appId: appId, groupId: group.id, intent: .available)
                            availableAssigned += 1
                            print("[Upload] ✓ Assigned \(group.displayName ?? group.id) as available")
                        } catch {
                            print("[Upload] ✗ Failed to assign \(group.displayName ?? group.id) as available: \(error)")
                        }
                    }
                    print("[Upload] Step 8: Group assignments complete (\(requiredAssigned) required, \(availableAssigned) available)")
                }
                
                // Clean up original package file from temp directory
                let tempPath = packageURL.path
                if tempPath.contains("/var/folders/") || tempPath.contains("/tmp/") || tempPath.contains("Temporary") {
                    try? FileManager.default.removeItem(at: packageURL)
                    print("[Upload] Cleaned up temp package file: \(packageURL.lastPathComponent)")
                }
                
                let result = UploadResult(
                    appId: appId,
                    appName: configuration.displayName,
                    appVersion: configuration.bundleVersion,
                    bundleId: configuration.bundleId,
                    requiredGroupsAssigned: requiredAssigned,
                    availableGroupsAssigned: availableAssigned,
                    timestamp: Date()
                )

                await MainActor.run {
                    self.currentStep = "Upload complete!"
                    self.uploadProgress = 1.0
                    self.uploadResult = result
                    self.uploadCompleted = true
                    self.isUploading = false
                }
                print("[Upload] Upload completed successfully!")
            } catch is CancellationError {
                print("[Upload] Upload cancelled")
                await MainActor.run {
                    self.isUploading = false
                    self.errorMessage = "Upload cancelled"
                }
                throw CancellationError()
            } catch {
                print("[Upload] Upload failed: \(error)")
                if let uploadError = error as? UploadError {
                    print("[Upload] Error type: \(uploadError)")
                }
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isUploading = false
                }
                throw error
            }
        }
        
        currentUploadTask = task
        try await task.value
    }
    
    // MARK: - App Existence Check & Assignment Fetching
    
    // Make this function public so UI can call it directly
    func fetchAndPopulateAssignments(appId: String, configuration: IntuneAppConfiguration) async throws {
        let token = try await authManager.getToken()
        let url = URL(string: "\(graphEndpoint)/deviceAppManagement/mobileApps/\(appId)/assignments")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("[Upload] Warning: Could not fetch existing assignments (HTTP \(response as? HTTPURLResponse)?.statusCode ?? 0)")
            return // Don't fail if we can't fetch assignments, just continue without them
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assignments = json["value"] as? [[String: Any]] else {
            print("[Upload] No existing assignments found")
            return
        }
        
        // Log the raw assignment response for debugging
        if let jsonData = try? JSONSerialization.data(withJSONObject: assignments, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[Upload] Raw assignments response: \(jsonString)")
        }
        
        var requiredGroups: [AzureADGroup] = []
        var availableGroups: [AzureADGroup] = []
        
        // Well-known Azure AD group IDs for All Users and All Devices
        let allUsersGroupId = "e2361a68-7ee7-4b4c-9a7e-1b2c7c6a7b5a"
        let allDevicesGroupId = "b1e5c6c7-7e7e-4b4c-9a7e-1b2c7c6a7b5b"
        
        // Fetch group details for each assignment
        for assignment in assignments {
            guard let target = assignment["target"] as? [String: Any],
                  let intent = assignment["intent"] as? String else {
                print("[Upload] Skipping assignment - missing target or intent: \(assignment)")
                continue
            }
            
            let targetType = target["@odata.type"] as? String ?? ""
            print("[Upload] Processing assignment - intent: \(intent), target type: \(targetType)")
            
            var group: AzureADGroup?
            
            // Handle different assignment target types
            if targetType == "#microsoft.graph.groupAssignmentTarget" {
                // Regular group assignment
                guard let groupId = target["groupId"] as? String else {
                    print("[Upload] Skipping group assignment - missing groupId")
                    continue
                }
                
                // Fetch group details to get display name
                if let fetchedGroup = try? await fetchGroupDetails(groupId: groupId) {
                    group = fetchedGroup
                } else {
                    // If we can't fetch group details, create a group with just the ID
                    group = AzureADGroup(id: groupId, displayName: nil)
                }
            } else if targetType == "#microsoft.graph.allLicensedUsersAssignmentTarget" {
                // "All users" assignment
                print("[Upload] Found 'All users' assignment")
                group = AzureADGroup(id: allUsersGroupId, displayName: "All Users")
            } else if targetType == "#microsoft.graph.allDevicesAssignmentTarget" {
                // "All devices" assignment
                print("[Upload] Found 'All devices' assignment")
                group = AzureADGroup(id: allDevicesGroupId, displayName: "All Devices")
            } else {
                print("[Upload] Unknown assignment target type: \(targetType), skipping")
                continue
            }
            
            guard let finalGroup = group else {
                continue
            }
            
            if intent == "required" {
                requiredGroups.append(finalGroup)
                print("[Upload] Added required group: \(finalGroup.displayName ?? finalGroup.id)")
            } else if intent == "available" {
                availableGroups.append(finalGroup)
                print("[Upload] Added available group: \(finalGroup.displayName ?? finalGroup.id)")
            }
        }
        
        // Populate configuration with fetched assignments
        await MainActor.run {
            configuration.requiredGroups = requiredGroups
            configuration.availableGroups = availableGroups
        }
        
        print("[Upload] Fetched and populated \(requiredGroups.count) required and \(availableGroups.count) available group assignments")
    }
    
    private func fetchGroupDetails(groupId: String) async throws -> AzureADGroup {
        let token = try await authManager.getToken()
        let url = URL(string: "\(graphEndpoint)/groups/\(groupId)")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UploadError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let displayName = json["displayName"] as? String
        
        return AzureADGroup(id: groupId, displayName: displayName)
    }
    
    private func checkForExistingApp(bundleId: String, version: String) async throws -> ExistingAppInfo? {
        let token = try await authManager.getToken()
        
        // Query Graph API for all mobile apps
        // We'll filter by @odata.type and bundle ID in code since Graph API
        // doesn't support filtering by derived type properties
        var urlComponents = URLComponents(string: "\(graphEndpoint)/deviceAppManagement/mobileApps")!
        // Limit results to reduce payload size - we'll check first page only
        urlComponents.queryItems = [
            URLQueryItem(name: "$top", value: "100")
        ]
        
        let url = urlComponents.url!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[Upload] Failed to check for existing app: Invalid response")
            return nil
        }
        
        guard httpResponse.statusCode == 200 else {
            if let responseStr = String(data: data, encoding: .utf8) {
                print("[Upload] Failed to check for existing app (HTTP \(httpResponse.statusCode)): \(responseStr)")
            }
            return nil
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let apps = json["value"] as? [[String: Any]] else {
            print("[Upload] No existing app found with bundle ID: \(bundleId)")
            return nil
        }
        
        // Filter apps by type (macOS PKG) and bundle ID in code
        for app in apps {
            // Check if it's a macOS PKG app
            guard let odataType = app["@odata.type"] as? String,
                  odataType == "#microsoft.graph.macOSPkgApp" else {
                continue
            }
            
            guard let appId = app["id"] as? String,
                  let displayName = app["displayName"] as? String,
                  let appBundleId = app["primaryBundleId"] as? String,
                  appBundleId == bundleId else {
                continue
            }
            
            let appVersion = app["primaryBundleVersion"] as? String ?? ""
            let isSameVersion = appVersion == version
            
            print("[Upload] Found existing app: \(displayName) (ID: \(appId), Bundle ID: \(appBundleId), Version: \(appVersion))")
            
            return ExistingAppInfo(
                appId: appId,
                displayName: displayName,
                bundleId: appBundleId,
                version: appVersion,
                isSameVersion: isSameVersion
            )
        }
        
        print("[Upload] No existing app found with bundle ID: \(bundleId)")
        return nil
    }
    
    private func createMacOSLobApp(packageURL: URL, configuration: IntuneAppConfiguration) async throws -> String {
        let token = try await authManager.getToken()
        
        let appData: [String: Any] = [
            "@odata.type": "#microsoft.graph.macOSPkgApp",
            "displayName": configuration.displayName,
            "description": configuration.description,
            "publisher": configuration.publisher,
            "fileName": packageURL.lastPathComponent,
            "informationUrl": configuration.informationUrl.isEmpty ? nil : configuration.informationUrl,
            "privacyInformationUrl": configuration.privacyUrl.isEmpty ? nil : configuration.privacyUrl,
            "developer": configuration.developer.isEmpty ? nil : configuration.developer,
            "owner": configuration.owner.isEmpty ? nil : configuration.owner,
            "notes": configuration.notes.isEmpty ? nil : configuration.notes,
            "roleScopeTagIds": [],
            "primaryBundleId": configuration.bundleId,
            "primaryBundleVersion": configuration.bundleVersion,
            "includedApps": [
                [
                    "bundleId": configuration.bundleId,
                    "bundleVersion": configuration.bundleVersion
                ]
            ],
            "minimumSupportedOperatingSystem": configuration.minimumOS.apiValue,
            "ignoreVersionDetection": configuration.ignoreAppVersion,
            "preInstallScript": configuration.preInstallScript.isEmpty ? nil : [
                "scriptContent": Data(configuration.preInstallScript.utf8).base64EncodedString()
            ],
            "postInstallScript": configuration.postInstallScript.isEmpty ? nil : [
                "scriptContent": Data(configuration.postInstallScript.utf8).base64EncodedString()
            ]
        ].compactMapValues { $0 }
        
        let url = URL(string: "\(graphEndpoint)/deviceAppManagement/mobileApps")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: appData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.failedToCreateApp
        }
        
        guard httpResponse.statusCode == 201 else {
            if let responseStr = String(data: data, encoding: .utf8) {
                print("[Upload] Failed to create app (HTTP \(httpResponse.statusCode)): \(responseStr)")
            }
            throw UploadError.failedToCreateApp
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let appId = json["id"] as? String else {
            throw UploadError.invalidResponse
        }
        
        await MainActor.run {
            self.uploadProgress = 0.1
        }
        
        return appId
    }
    
    private func createContentVersion(appId: String) async throws -> String {
        let token = try await authManager.getToken()
        
        let url = URL(string: "\(graphEndpoint)/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.failedToCreateContentVersion
        }
        
        guard httpResponse.statusCode == 201 else {
            if let responseStr = String(data: data, encoding: .utf8) {
                print("[Upload] Failed to create content version (HTTP \(httpResponse.statusCode)): \(responseStr)")
            }
            throw UploadError.failedToCreateContentVersion
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let contentVersionId = json["id"] as? String else {
            throw UploadError.invalidResponse
        }
        
        await MainActor.run {
            self.uploadProgress = 0.2
        }
        
        return contentVersionId
    }
    
    private func createContentFile(appId: String, contentVersionId: String, packageURL: URL) async throws -> (id: String, azureStorageUri: String, encryptedFileURL: URL, encryptionInfo: FileEncryptionInfo) {
        let token = try await authManager.getToken()
        
        // Encrypt the file first - Intune requires encrypted uploads
        print("[Upload] Encrypting file for upload...")
        let (encryptedFileURL, encryptionInfo) = try await encryptFile(at: packageURL)
        let encryptedFileSize = try FileManager.default.attributesOfItem(atPath: encryptedFileURL.path)[.size] as! Int64
        let originalFileSize = try FileManager.default.attributesOfItem(atPath: packageURL.path)[.size] as! Int64
        print("[Upload] File encrypted: \(originalFileSize) bytes -> \(encryptedFileSize) bytes")
        
        let fileData: [String: Any] = [
            "@odata.type": "#microsoft.graph.mobileAppContentFile",
            "name": packageURL.lastPathComponent,
            "size": originalFileSize,
            "sizeEncrypted": encryptedFileSize,
            "manifest": NSNull(),
            "isDependency": false
        ]
        
        let url = URL(string: "\(graphEndpoint)/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions/\(contentVersionId)/files")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: fileData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.failedToCreateContentFile
        }
        
        guard httpResponse.statusCode == 201 else {
            if let responseStr = String(data: data, encoding: .utf8) {
                print("[Upload] Failed to create content file (HTTP \(httpResponse.statusCode)): \(responseStr)")
            }
            throw UploadError.failedToCreateContentFile
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let fileId = json["id"] as? String else {
            throw UploadError.invalidResponse
        }
        
        // Wait for Azure Storage URI
        let azureUri = try await waitForAzureStorageUri(appId: appId, contentVersionId: contentVersionId, fileId: fileId)
        
        await MainActor.run {
            self.uploadProgress = 0.3
        }
        
        return (fileId, azureUri, encryptedFileURL, encryptionInfo)
    }
    
    // File encryption info structure
    struct FileEncryptionInfo {
        let encryptionKey: Data
        let macKey: Data
        let initializationVector: Data
        let mac: Data
        let fileDigest: Data
        let profileIdentifier: String = "ProfileVersion1"
    }
    
    private func encryptFile(at fileURL: URL) async throws -> (encryptedURL: URL, encryptionInfo: FileEncryptionInfo) {
        let fileData = try Data(contentsOf: fileURL)
        
        // Generate random encryption key (32 bytes for AES-256)
        var encryptionKey = Data(count: 32)
        _ = encryptionKey.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        
        // Generate random HMAC key (32 bytes)
        var hmacKey = Data(count: 32)
        _ = hmacKey.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        
        // Generate random IV (16 bytes for AES)
        var iv = Data(count: 16)
        _ = iv.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        
        // Compute file digest (SHA256 of original file)
        let fileDigest = Data(SHA256.hash(data: fileData))
        
        // Encrypt using AES-256-CBC with PKCS7 padding
        let encryptedData = try aesEncrypt(data: fileData, key: encryptionKey, iv: iv)
        
        // Intune expects the file format: [HMAC placeholder (32 bytes)][IV (16 bytes)][Encrypted Data]
        // Then HMAC is computed over everything from position 32 onwards (IV + encrypted data)
        // and written at the beginning
        
        // Build the data to compute MAC over: IV + encrypted content
        var dataToMac = iv
        dataToMac.append(encryptedData)
        
        // Compute HMAC-SHA256 over (IV + encrypted data)
        let mac = Data(HMAC<SHA256>.authenticationCode(for: dataToMac, using: SymmetricKey(data: hmacKey)))
        
        // Build final file: [MAC (32 bytes)][IV (16 bytes)][Encrypted Data]
        var finalData = mac         // 32 bytes HMAC at the beginning
        finalData.append(iv)        // 16 bytes IV
        finalData.append(encryptedData)  // Encrypted content
        
        // Write encrypted file to temp location
        let encryptedURL = fileURL.deletingPathExtension().appendingPathExtension("encrypted.bin")
        try finalData.write(to: encryptedURL)
        
        print("[Upload] Encryption details - MAC: \(mac.prefix(8).map { String(format: "%02x", $0) }.joined())..., IV: \(iv.prefix(8).map { String(format: "%02x", $0) }.joined())...")
        
        let encryptionInfo = FileEncryptionInfo(
            encryptionKey: encryptionKey,
            macKey: hmacKey,
            initializationVector: iv,
            mac: mac,
            fileDigest: fileDigest
        )
        
        return (encryptedURL, encryptionInfo)
    }
    
    private func aesEncrypt(data: Data, key: Data, iv: Data) throws -> Data {
        // Use CommonCrypto for AES encryption
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted: size_t = 0
        
        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            bufferPtr.baseAddress, bufferSize,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw UploadError.encryptionFailed
        }
        
        return buffer.prefix(numBytesEncrypted)
    }
    
    private func waitForAzureStorageUri(appId: String, contentVersionId: String, fileId: String) async throws -> String {
        let token = try await authManager.getToken()
        let url = URL(string: "\(graphEndpoint)/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions/\(contentVersionId)/files/\(fileId)")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        for attempt in 0..<60 { // Poll for up to 60 seconds (increased from 30)
            if Task.isCancelled { throw CancellationError() }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                if attempt < 5 {
                    print("[Upload] WaitForAzureStorageUri: Invalid response type")
                }
                try await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }
            
            guard httpResponse.statusCode == 200 else {
                if attempt < 5 { // Only log first few errors
                    if let responseStr = String(data: data, encoding: .utf8) {
                        print("[Upload] WaitForAzureStorageUri: HTTP \(httpResponse.statusCode) - \(responseStr)")
                    } else {
                        print("[Upload] WaitForAzureStorageUri: HTTP \(httpResponse.statusCode)")
                    }
                }
                try await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            
            if let azureStorageUri = json["azureStorageUri"] as? String {
                print("[Upload] Azure Storage URI received (attempt \(attempt + 1))")
                return azureStorageUri
            }
            
            if attempt % 5 == 0 {
                print("[Upload] Waiting for Azure Storage URI (attempt \(attempt + 1)/60)...")
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        print("[Upload] Timeout waiting for Azure Storage URI")
        throw UploadError.azureStorageUriTimeout
    }
    
    private func uploadFile(packageURL: URL, azureStorageUri: String) async throws {
        let fileData = try Data(contentsOf: packageURL)
        let fileSizeMB = Double(fileData.count) / (1024 * 1024)
        print("[Upload] File size: \(String(format: "%.2f", fileSizeMB)) MB")
        
        // Validate Azure Storage URI
        guard let baseURL = URL(string: azureStorageUri) else {
            print("[Upload] Invalid Azure Storage URI")
            throw UploadError.invalidAzureStorageUri
        }
        print("[Upload] Azure Storage host: \(baseURL.host ?? "unknown")")
        
        // Use 100MB chunks for faster uploads
        // Azure supports up to 100MB per block, using maximum size for best performance
        let chunkSize = 100 * 1024 * 1024 // 100MB chunks (Azure maximum)
        let chunks = fileData.chunked(into: chunkSize)
        print("[Upload] Uploading in \(chunks.count) chunk(s) of \(chunkSize / (1024 * 1024))MB each...")
        
        // Upload chunks in parallel for better performance
        // Use a semaphore to limit concurrent uploads (4 at a time for optimal throughput)
        let maxConcurrentUploads = 4
        let semaphore = AsyncSemaphore(value: maxConcurrentUploads)
        var uploadTasks: [Task<Void, Error>] = []
        let totalChunks = chunks.count
        let progressCounter = ProgressCounter(total: totalChunks)
        
        for (index, chunk) in chunks.enumerated() {
            if Task.isCancelled { throw CancellationError() }
            
            let task = Task {
                await semaphore.wait()
                
                if Task.isCancelled { 
                    await semaphore.signal()
                    throw CancellationError() 
                }
                
                let chunkMB = Double(chunk.count) / (1024 * 1024)
                print("[Upload] Uploading chunk \(index + 1)/\(totalChunks) (\(String(format: "%.1f", chunkMB)) MB)...")
                
                do {
                    try await uploadChunk(chunk, to: azureStorageUri, blockId: String(format: "%06d", index))
                    
                    let completed = await progressCounter.increment()
                    await MainActor.run {
                        // Upload progress goes from 0.20 to 0.70 (50% of total progress)
                        self.uploadProgress = 0.20 + (0.50 * Double(completed) / Double(totalChunks))
                        self.currentStep = "Uploading to Azure Storage... (\(completed)/\(totalChunks) chunks)"
                    }
                    print("[Upload] ✓ Chunk \(index + 1)/\(totalChunks) completed")
                    await semaphore.signal()
                } catch {
                    await semaphore.signal()
                    throw error
                }
            }
            uploadTasks.append(task)
        }
        
        // Wait for all uploads to complete
        for task in uploadTasks {
            try await task.value
        }
        
        print("[Upload] All chunks uploaded successfully")
        
        // Commit blocks
        try await commitBlocks(to: azureStorageUri, blockCount: chunks.count)
    }
    
    private func uploadChunk(_ data: Data, to azureUri: String, blockId: String) async throws {
        let blockIdBase64 = blockId.data(using: .utf8)!.base64EncodedString()
        
        // URL-encode the base64 block ID for the query string
        let encodedBlockId = blockIdBase64.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? blockIdBase64
        let url = URL(string: "\(azureUri)&comp=block&blockid=\(encodedBlockId)")!
        
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            if Task.isCancelled { throw CancellationError() }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            
            // Required Azure Storage headers for Put Block
            request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
            request.setValue("2020-10-02", forHTTPHeaderField: "x-ms-version")
            
            // Format date according to RFC 1123
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            request.setValue(dateFormatter.string(from: Date()), forHTTPHeaderField: "x-ms-date")
            
            request.httpBody = data
            request.timeoutInterval = 300 // 5 minutes per chunk
            
            do {
                let (responseData, response) = try await uploadSession.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw UploadError.chunkUploadFailed
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let errorStr = String(data: responseData, encoding: .utf8) {
                        print("[Upload] Chunk \(blockId) upload failed (HTTP \(httpResponse.statusCode)): \(errorStr)")
                    }
                    throw UploadError.chunkUploadFailed
                }
                
                // Success - return immediately
                if attempt > 0 {
                    print("[Upload] Chunk \(blockId) uploaded successfully on retry attempt \(attempt + 1)")
                }
                return
                
            } catch {
                lastError = error
                let errorDescription = error.localizedDescription
                
                // Check if it's a network error that we should retry
                let isRetryableError = errorDescription.contains("Connection reset") ||
                                     errorDescription.contains("timed out") ||
                                     errorDescription.contains("network") ||
                                     (error as NSError).code == NSURLErrorTimedOut ||
                                     (error as NSError).code == NSURLErrorNetworkConnectionLost ||
                                     (error as NSError).code == NSURLErrorNotConnectedToInternet
                
                if isRetryableError && attempt < maxRetries - 1 {
                    let delay = Double(attempt + 1) * 2.0 // Exponential backoff: 2s, 4s, 6s
                    print("[Upload] Chunk \(blockId) upload failed (attempt \(attempt + 1)/\(maxRetries)): \(errorDescription). Retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    // Not retryable or out of retries
                    print("[Upload] Chunk \(blockId) upload failed: \(errorDescription)")
                    throw error
                }
            }
        }
        
        // If we get here, all retries failed
        throw lastError ?? UploadError.chunkUploadFailed
    }
    
    private func commitBlocks(to azureUri: String, blockCount: Int) async throws {
        var blockList = "<?xml version=\"1.0\" encoding=\"utf-8\"?><BlockList>"
        for i in 0..<blockCount {
            let blockId = String(format: "%06d", i).data(using: .utf8)!.base64EncodedString()
            blockList += "<Latest>\(blockId)</Latest>"
        }
        blockList += "</BlockList>"
        
        let blockListData = blockList.data(using: .utf8)!
        
        print("[Upload] Committing \(blockCount) blocks to Azure Storage...")
        
        let url = URL(string: "\(azureUri)&comp=blocklist")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.setValue(String(blockListData.count), forHTTPHeaderField: "Content-Length")
        request.setValue("2020-10-02", forHTTPHeaderField: "x-ms-version")
        request.setValue("application/octet-stream", forHTTPHeaderField: "x-ms-blob-content-type")
        
        // Format date according to RFC 1123
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        request.setValue(dateFormatter.string(from: Date()), forHTTPHeaderField: "x-ms-date")
        
        request.httpBody = blockListData
        request.timeoutInterval = 60 // 1 minute for block commit
        
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            if Task.isCancelled { throw CancellationError() }
            
            do {
                let (responseData, response) = try await uploadSession.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw UploadError.blockCommitFailed
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let errorStr = String(data: responseData, encoding: .utf8) {
                        print("[Upload] Block commit failed (HTTP \(httpResponse.statusCode)): \(errorStr)")
                    }
                    throw UploadError.blockCommitFailed
                }
                
                print("[Upload] Blocks committed successfully")
                return
                
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = Double(attempt + 1) * 2.0
                    print("[Upload] Block commit failed (attempt \(attempt + 1)/\(maxRetries)): \(error.localizedDescription). Retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    print("[Upload] Block commit failed after \(maxRetries) attempts: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        throw lastError ?? UploadError.blockCommitFailed
    }
    
    private func waitForFileUploadState(appId: String, contentVersionId: String, fileId: String) async throws {
        let token = try await authManager.getToken()
        let url = URL(string: "\(graphEndpoint)/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions/\(contentVersionId)/files/\(fileId)")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        for attempt in 0..<120 { // Wait up to 2 minutes (increased from 60 seconds)
            if Task.isCancelled { throw CancellationError() }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UploadError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("[Upload] WaitForFileUploadState: HTTP \(httpResponse.statusCode) - \(responseStr)")
                }
                throw UploadError.invalidResponse
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            
            if let uploadState = json["uploadState"] as? String {
                print("[Upload] File upload state (attempt \(attempt + 1)/120): \(uploadState)")
                
                // After uploading to Azure Storage, we wait for the file to be ready for commit
                // The state should be "azureStorageUriRequestSuccess" or similar indicating the file is ready
                if uploadState == "azureStorageUriRequestSuccess" || uploadState == "success" {
                    print("[Upload] File is ready for commit")
                    return
                } else if uploadState == "commitFileSuccess" {
                    // Already committed, skip to next step
                    print("[Upload] File already committed, skipping commit step")
                    return
                } else if uploadState == "commitFileFailed" || uploadState == "azureStorageUriRequestFailed" || uploadState == "failed" {
                    if let errorDetails = json["uploadErrorCode"] as? String {
                        print("[Upload] Upload failed with error code: \(errorDetails)")
                    }
                    throw UploadError.fileCommitFailed
                }
            } else {
                print("[Upload] No uploadState in response (attempt \(attempt + 1)/120)")
            }
            
            // Update progress during wait
            await MainActor.run {
                self.uploadProgress = 0.8 + (0.05 * Double(attempt) / 120.0)
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        print("[Upload] Timeout waiting for file upload state")
        throw UploadError.fileCommitTimeout
    }

    private func waitForFileCommitSuccess(appId: String, contentVersionId: String, fileId: String) async throws {
        let token = try await authManager.getToken()
        let url = URL(string: "\(graphEndpoint)/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions/\(contentVersionId)/files/\(fileId)")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        for attempt in 0..<180 { // wait up to 3 minutes (increased from 2 minutes)
            if Task.isCancelled { throw CancellationError() }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UploadError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("[Upload] WaitForFileCommitSuccess: HTTP \(httpResponse.statusCode) - \(responseStr)")
                }
                throw UploadError.invalidResponse
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            
            if let state = json["uploadState"] as? String {
                print("[Upload] File commit state (attempt \(attempt + 1)/180): \(state)")
                
                if state == "commitFileSuccess" {
                    print("[Upload] File commit successful!")
                    return
                }
                if state == "commitFileFailed" || state == "failed" {
                    if let errorDetails = json["uploadErrorCode"] as? String {
                        print("[Upload] File commit failed with error code: \(errorDetails)")
                    }
                    throw UploadError.fileCommitFailed
                }
            } else {
                print("[Upload] No uploadState in response (attempt \(attempt + 1)/180)")
            }
            
            // Update progress during wait
            await MainActor.run {
                self.uploadProgress = 0.9 + (0.05 * Double(attempt) / 180.0)
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        print("[Upload] Timeout waiting for file commit success")
        throw UploadError.fileCommitTimeout
    }
    
    private func commitContentFile(appId: String, contentVersionId: String, fileId: String, encryptionInfo: FileEncryptionInfo) async throws {
        let token = try await authManager.getToken()
        
        let commitData: [String: Any] = [
            "fileEncryptionInfo": [
                "@odata.type": "#microsoft.graph.fileEncryptionInfo",
                "encryptionKey": encryptionInfo.encryptionKey.base64EncodedString(),
                "macKey": encryptionInfo.macKey.base64EncodedString(),
                "initializationVector": encryptionInfo.initializationVector.base64EncodedString(),
                "mac": encryptionInfo.mac.base64EncodedString(),
                "profileIdentifier": encryptionInfo.profileIdentifier,
                "fileDigest": encryptionInfo.fileDigest.base64EncodedString(),
                "fileDigestAlgorithm": "SHA256"
            ]
        ]
        
        print("[Upload] Commit data - fileDigest: \(encryptionInfo.fileDigest.base64EncodedString().prefix(20))...")
        
        let url = URL(string: "\(graphEndpoint)/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions/\(contentVersionId)/files/\(fileId)/commit")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: commitData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.fileCommitFailed
        }
        
        // Log the response for debugging
        if let responseStr = String(data: data, encoding: .utf8), !responseStr.isEmpty {
            print("[Upload] Commit response (HTTP \(httpResponse.statusCode)): \(responseStr)")
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            if let responseStr = String(data: data, encoding: .utf8) {
                print("[Upload] Commit file error (HTTP \(httpResponse.statusCode)): \(responseStr)")
            }
            throw UploadError.fileCommitFailed
        }
        
        await MainActor.run {
            self.uploadProgress = 0.9
        }
    }
    
    private func commitApp(appId: String, contentVersionId: String, packageURL: URL, configuration: IntuneAppConfiguration, isVersionUpdate: Bool = false) async throws {
        let token = try await authManager.getToken()
        
        var commitData: [String: Any] = [
            "@odata.type": "#microsoft.graph.macOSPkgApp",
            "committedContentVersion": contentVersionId
        ]
        
        if isVersionUpdate {
            // For version updates, only update version-related fields to preserve existing metadata
            commitData["versionNumber"] = configuration.bundleVersion
            commitData["primaryBundleVersion"] = configuration.bundleVersion
            commitData["includedApps"] = [
                [
                    "@odata.type": "#microsoft.graph.macOSIncludedApp",
                    "bundleId": configuration.bundleId,
                    "bundleVersion": configuration.bundleVersion
                ]
            ]
            print("[Upload] Committing version update (preserving existing metadata)...")
        } else {
            // For new apps, include all fields
            commitData["displayName"] = configuration.displayName
            commitData["description"] = configuration.description
            commitData["publisher"] = configuration.publisher
            commitData["fileName"] = packageURL.lastPathComponent
            commitData["primaryBundleId"] = configuration.bundleId
            commitData["bundleId"] = configuration.bundleId
            commitData["versionNumber"] = configuration.bundleVersion
            commitData["primaryBundleVersion"] = configuration.bundleVersion
            commitData["minimumSupportedOperatingSystem"] = configuration.minimumOS.apiValue
            commitData["includedApps"] = [
                [
                    "@odata.type": "#microsoft.graph.macOSIncludedApp",
                    "bundleId": configuration.bundleId,
                    "bundleVersion": configuration.bundleVersion
                ]
            ]
            
            // Add optional fields if not empty
            if !configuration.informationUrl.isEmpty {
                commitData["informationUrl"] = configuration.informationUrl
            }
            print("[Upload] Committing new app with all metadata...")
        }
        
        print("[Upload] Commit app data: \(commitData)")
        
        let url = URL(string: "\(graphEndpoint)/deviceAppManagement/mobileApps/\(appId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: commitData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.appCommitFailed
        }
        
        guard (200...204).contains(httpResponse.statusCode) else {
            if let responseStr = String(data: data, encoding: .utf8) {
                print("[Upload] App commit failed (HTTP \(httpResponse.statusCode)): \(responseStr)")
            } else {
                print("[Upload] App commit failed with HTTP status: \(httpResponse.statusCode)")
            }
            throw UploadError.appCommitFailed
        }
        
        await MainActor.run {
            self.uploadProgress = 1.0
        }
    }
    
    // MARK: - Group Assignment
    
    enum AssignmentIntent: String {
        case required = "required"
        case available = "available"
        case uninstall = "uninstall"
    }
    
    private func assignAppToGroup(appId: String, groupId: String, intent: AssignmentIntent) async throws {
        let token = try await authManager.getToken()
        
        // Build assignment payload per Microsoft Graph API
        // For macOS PKG apps, we don't include settings as they're not supported
        // https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileapp-assign
        let assignmentData: [String: Any] = [
            "mobileAppAssignments": [
                [
                    "@odata.type": "#microsoft.graph.mobileAppAssignment",
                    "target": [
                        "@odata.type": "#microsoft.graph.groupAssignmentTarget",
                        "groupId": groupId
                    ],
                    "intent": intent.rawValue
                ]
            ]
        ]
        
        // Log the assignment payload for debugging
        if let jsonData = try? JSONSerialization.data(withJSONObject: assignmentData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[Upload] Assignment payload: \(jsonString)")
        }
        
        let url = URL(string: "\(graphEndpoint)/deviceAppManagement/mobileApps/\(appId)/assign")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: assignmentData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.assignmentFailed
        }
        
        // Log the response for debugging
        if let responseStr = String(data: data, encoding: .utf8), !responseStr.isEmpty {
            print("[Upload] Assignment response (HTTP \(httpResponse.statusCode)): \(responseStr)")
        } else {
            print("[Upload] Assignment response: HTTP \(httpResponse.statusCode) (no body)")
        }
        
        // 200, 201, or 204 are all success codes for assignment
        guard (200...204).contains(httpResponse.statusCode) else {
            if let responseStr = String(data: data, encoding: .utf8) {
                print("[Upload] Assignment failed (HTTP \(httpResponse.statusCode)): \(responseStr)")
            }
            throw UploadError.assignmentFailed
        }
        
        // Verify the assignment was actually created by fetching assignments
        try await verifyAssignment(appId: appId, groupId: groupId, intent: intent)
        
        print("[Upload] Successfully assigned app to group \(groupId) with intent \(intent.rawValue)")
    }
    
    private func verifyAssignment(appId: String, groupId: String, intent: AssignmentIntent) async throws {
        let token = try await authManager.getToken()
        let url = URL(string: "\(graphEndpoint)/deviceAppManagement/mobileApps/\(appId)/assignments")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Wait a moment for the assignment to propagate
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("[Upload] Warning: Could not verify assignment (HTTP \(response as? HTTPURLResponse)?.statusCode ?? 0)")
            return // Don't fail if verification fails, just log a warning
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let assignments = json["value"] as? [[String: Any]] {
            let matchingAssignment = assignments.first { assignment in
                guard let target = assignment["target"] as? [String: Any],
                      let assignmentGroupId = target["groupId"] as? String,
                      let assignmentIntent = assignment["intent"] as? String else {
                    return false
                }
                return assignmentGroupId == groupId && assignmentIntent == intent.rawValue
            }
            
            if matchingAssignment != nil {
                print("[Upload] Assignment verified successfully")
            } else {
                print("[Upload] Warning: Assignment not found in verification. Found \(assignments.count) total assignments.")
                if let assignmentsJson = try? JSONSerialization.data(withJSONObject: assignments, options: .prettyPrinted),
                   let assignmentsStr = String(data: assignmentsJson, encoding: .utf8) {
                    print("[Upload] Current assignments: \(assignmentsStr)")
                }
            }
        }
    }
}

enum UploadError: LocalizedError {
    case failedToCreateApp
    case failedToCreateContentVersion
    case failedToCreateContentFile
    case invalidResponse
    case invalidAzureStorageUri
    case azureStorageUriTimeout
    case chunkUploadFailed
    case blockCommitFailed
    case fileCommitFailed
    case fileCommitTimeout
    case appCommitFailed
    case encryptionFailed
    case assignmentFailed
    case duplicateAppVersion(existingAppId: String, existingAppName: String)
    case versionUpdateRequired(existingAppId: String, existingAppName: String, oldVersion: String, newVersion: String)
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateApp: return "Failed to create app in Intune"
        case .failedToCreateContentVersion: return "Failed to create content version"
        case .failedToCreateContentFile: return "Failed to create content file"
        case .invalidResponse: return "Invalid response from server"
        case .invalidAzureStorageUri: return "Invalid Azure Storage URI received from Intune"
        case .azureStorageUriTimeout: return "Timeout waiting for Azure Storage URI"
        case .chunkUploadFailed: return "Failed to upload file chunk"
        case .blockCommitFailed: return "Failed to commit file blocks"
        case .fileCommitFailed: return "Failed to commit content file"
        case .fileCommitTimeout: return "Timeout waiting for file upload to complete"
        case .appCommitFailed: return "Failed to commit app"
        case .encryptionFailed: return "Failed to encrypt file for upload"
        case .assignmentFailed: return "Failed to assign app to group"
        case .duplicateAppVersion(let appId, let appName):
            return "An app with the same bundle ID and version already exists in Intune: \(appName) (ID: \(appId)). Please use a different version or update the existing app."
        case .versionUpdateRequired(let appId, let appName, let oldVersion, let newVersion):
            return "An app with the same bundle ID but different version exists: \(appName) (ID: \(appId)). Current version: \(oldVersion), New version: \(newVersion). This will update the existing app."
        }
    }
}

extension Data {
    func chunked(into size: Int) -> [Data] {
        return stride(from: 0, to: count, by: size).map {
            self.subdata(in: $0..<Swift.min($0 + size, count))
        }
    }
}
