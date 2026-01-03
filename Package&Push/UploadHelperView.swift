//
//  UploadHelperView.swift
//  Package&Push
//
//  Created by Somesh Pathak on 14/07/2025.
//

import SwiftUI
import AppKit

struct UploadHelperView: View {
    let config: IntuneAppConfiguration
    let onDone: () -> Void
    
    @State private var currentStep = 1
    @State private var pathCopied = false
    @State private var infoCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "safari")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Intune Upload Helper")
                        .font(.headline)
                    Text("Sign in with correct account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    // Open new private window
                    let script = """
                    tell application "Safari"
                        activate
                        tell application "System Events"
                            keystroke "n" using {command down, shift down}
                        end tell
                        delay 0.5
                        set URL of current tab of front window to "https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/AppsMacOsMenu/~/macOSApps"
                    end tell
                    """
                    if let appleScript = NSAppleScript(source: script) {
                        var error: NSDictionary?
                        appleScript.executeAndReturnError(&error)
                    }
                }) {
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Open new private window")
            }
            .padding(.bottom)
            
            // Steps
            VStack(alignment: .leading, spacing: 12) {
                StepView(number: 1, title: "Open Safari Private Window (⌘⇧N)", isActive: currentStep >= 1)
                StepView(number: 2, title: "Sign in with correct account", isActive: currentStep >= 2)
                StepView(number: 3, title: "Click '+ Add' button", isActive: currentStep >= 3)
                StepView(number: 4, title: "Select 'Line-of-business app'", isActive: currentStep >= 4)
                StepView(number: 5, title: "Click 'Select file' and paste this path:", isActive: currentStep >= 5)
                
                // Package path box
                GroupBox {
                    HStack {
                        Text(config.packageURL?.path ?? "")
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(config.packageURL?.path ?? "", forType: .string)
                            pathCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                pathCopied = false
                            }
                        }) {
                            Image(systemName: pathCopied ? "checkmark" : "doc.on.doc")
                                .foregroundColor(pathCopied ? .green : .blue)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                StepView(number: 6, title: "Fill in app information:", isActive: currentStep >= 6)
                
                // App info box
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Name:", value: config.displayName)
                        InfoRow(label: "Bundle ID:", value: config.bundleId)
                        InfoRow(label: "Version:", value: config.bundleVersion)
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                let info = """
                                Name: \(config.displayName)
                                Bundle ID: \(config.bundleId)
                                Version: \(config.bundleVersion)
                                """
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(info, forType: .string)
                                infoCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    infoCopied = false
                                }
                            }) {
                                Label(infoCopied ? "Copied!" : "Copy All",
                                      systemImage: infoCopied ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                StepView(number: 7, title: "Click 'Next' → 'Next' → 'Create'", isActive: currentStep >= 7)
            }
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                if currentStep < 7 {
                    Button(action: { currentStep += 1 }) {
                        Label("Next Step", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                Button(action: onDone) {
                    Label(currentStep >= 7 ? "Done" : "Skip to End",
                          systemImage: currentStep >= 7 ? "checkmark.circle.fill" : "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .foregroundColor(currentStep >= 7 ? .white : .blue)
                .background(currentStep >= 7 ? Color.blue : Color.clear)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let isActive: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                
                Text("\(number)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.system(size: 14, weight: isActive ? .medium : .regular))
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
