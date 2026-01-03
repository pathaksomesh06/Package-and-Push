<div align="center">
  <img src="icon.png" alt="Package & Push Icon" width="128" height="128">
  <h1>Package & Push</h1>
  <p>A native macOS application for building macOS packages from Homebrew formulas and deploying them to Microsoft Intune.</p>
</div>

## Features

- 🔍 **Search Homebrew Packages**: Browse and search Homebrew formulas
- 📦 **Build macOS Packages**: Automatically build `.pkg` installers from Homebrew formulas
- 🚀 **Deploy to Intune**: Upload packages directly to Microsoft Intune with full configuration
- 🔐 **Azure AD Integration**: Authenticate with Microsoft Entra ID and manage group assignments
- 📋 **App Configuration**: Configure app metadata, requirements, detection rules, and assignments
- 🔄 **Version Management**: Automatically detect existing apps and handle version updates
- ✅ **Assignment Preservation**: Automatically fetch and preserve existing group assignments during updates

## Requirements

- macOS 12.0 or later
- Xcode 14.0 or later
- Microsoft Entra ID account with Intune permissions
- Homebrew installed

## Installation

### From Source

1. Clone the repository:
```bash
git clone https://github.com/pathaksomesh06/Package-Push.git
cd Package-Push
```

2. Open the project in Xcode:
```bash
open Package&Push.xcodeproj
```

3. Build and run the project (⌘R)

### From Package

Download the latest `.pkg` installer from the [Releases](https://github.com/pathaksomesh06/Package-Push/releases) page.

## Screenshots

### Main Screen 
Welcome screen with Microsoft Entra ID authentication
<img width="1069" height="864" alt="Screenshot 2026-01-03 at 01 35 59" src="https://github.com/user-attachments/assets/086da778-2200-46f7-9127-e19abf01a750" />


### Package Search
Search and browse Homebrew packages with real-time filtering
<img width="1069" height="864" alt="Screenshot 2026-01-03 at 02 00 59" src="https://github.com/user-attachments/assets/2810f3c9-c888-40bd-8201-14b8b31c996c" />

### Package Details
View package information including version, homepage, and build status
<img width="1069" height="844" alt="Screenshot 2026-01-02 at 23 13 31" src="https://github.com/user-attachments/assets/59d5d7e8-9876-41e8-be12-2b3469376dae" />

### App Configuration
Configure app metadata, requirements, detection rules, and assignments
<img width="1069" height="856" alt="Screenshot 2026-01-02 at 23 14 16" src="https://github.com/user-attachments/assets/9b63b6b9-baf8-4cf5-ac27-0e8122bbaffb" />

### Deployment Progress
Real-time progress tracking during package upload to Intune
<img width="1069" height="844" alt="Screenshot 2026-01-02 at 23 15 26" src="https://github.com/user-attachments/assets/4686073e-3d99-4bb5-9303-4a54d54255c4" />
<img width="1069" height="844" alt="Screenshot 2026-01-03 at 00 33 14" src="https://github.com/user-attachments/assets/02c06678-c7bb-493a-87d9-b8e28faf97c5" />

### Version Update Detection
Automatic detection of existing apps with version update confirmation
<img width="1069" height="844" alt="Screenshot 2026-01-02 at 23 14 51" src="https://github.com/user-attachments/assets/9107ec9c-7131-4188-bae6-93441eb33cb8" />

### Success Screen
Deployment completion with app details and assignment summary
<img width="1069" height="844" alt="Screenshot 2026-01-03 at 00 02 39" src="https://github.com/user-attachments/assets/1643dc50-fdeb-4a30-84a8-9171a4f93027" />

## Usage

1. **Launch the Application**: Open Package & Push from Applications
2. **Sign In**: Authenticate with your Microsoft Entra ID account
3. **Search for Packages**: Use the search bar to find Homebrew packages
4. **Build Package**: Select a package and click "Build Package"
5. **Configure App**: Fill in app details, requirements, and assignments
6. **Deploy to Intune**: Click "Deploy to Intune" to upload the package

## Features in Detail

### Package Building
- Automatically extracts Homebrew formulas
- Builds signed `.pkg` installers
- Handles dependencies and requirements

### Intune Integration
- Creates macOS LOB (Line of Business) apps
- Configures app metadata and properties
- Sets up detection rules
- Manages group assignments (Required/Available)
- Handles version updates with assignment preservation

### Assignment Management
- Supports Azure AD group assignments
- Handles "All Users" and "All Devices" assignments
- Automatically fetches existing assignments during updates
- Preserves assignments when updating app versions

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **MSAL (Microsoft Authentication Library)**: Azure AD authentication
- **Microsoft Graph API**: Intune and Azure AD integration
- **Homebrew API**: Package information and formula access

## Project Structure

```
Package&Push/
├── Package&Push/          # Main application code
│   ├── AuthenticationManager.swift
│   ├── IntuneMobileAppUploader.swift
│   ├── HomebrewManager.swift
│   ├── PackageBuilder.swift
│   └── ...
├── Package&Push.xcodeproj/
└── README.md
```

## Configuration

The app uses `Config.plist` for configuration. Key settings include:
- Microsoft Graph API endpoint
- Azure AD tenant configuration
- App-specific settings

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

**Somesh Pathak**
- GitHub: [@pathaksomesh06](https://github.com/pathaksomesh06)
- Blog: [Intune in Real Life](https://intuneinreallife.com)
- Microsoft MVP: Enterprise Mobility

## Acknowledgments

- Microsoft Intune team for the Graph API
- Homebrew project for package management
- SwiftUI and Apple frameworks

## Related Projects

- [MISA](https://github.com/pathaksomesh06/MISA) - macOS Intune Support Assistant
- [ABMate](https://github.com/pathaksomesh06/ABMate) - Apple Business Manager client
- [Intune-Log-Reader](https://github.com/pathaksomesh06/Intune-Log-Reader) - Intune log analysis tool

