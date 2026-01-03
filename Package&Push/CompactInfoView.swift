//
//  CompactInfoView.swift
//  Package&Push
//
//  Created by Somesh Pathak on 15/07/2025.
//


//
//  CompactInfoView.swift
//  Package&Push
//

import SwiftUI

struct CompactInfoView: View {
    let packagePath: String
    let displayName: String
    let bundleId: String
    let version: String
    let onDone: () -> Void
    
    @State private var copiedField: String? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Package Info")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Copyable fields
            CopyableField(label: "Path", value: packagePath, copiedField: $copiedField)
            CopyableField(label: "Name", value: displayName, copiedField: $copiedField)
            CopyableField(label: "Bundle", value: bundleId, copiedField: $copiedField)
            CopyableField(label: "Version", value: version, copiedField: $copiedField)
            
            HStack {
                Button("Open Folder") {
                    NSWorkspace.shared.selectFile(packagePath, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Done") {
                    onDone()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 300)
    }
}

struct CopyableField: View {
    let label: String
    let value: String
    @Binding var copiedField: String?
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                copiedField = label
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copiedField = nil
                }
            }) {
                Image(systemName: copiedField == label ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(copiedField == label ? .green : .blue)
            }
            .buttonStyle(.plain)
        }
    }
}