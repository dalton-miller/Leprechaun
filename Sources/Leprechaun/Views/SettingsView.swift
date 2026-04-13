import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            RemoteSettingsView()
                .tabItem {
                    Label("Remotes", systemImage: "server.rack")
                }
                .tag(1)

            EncryptionSettingsView()
                .tabItem {
                    Label("Encryption", systemImage: "lock.fill")
                }
                .tag(2)
        }
        .frame(width: 450)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("rclone") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("v1.73.4 (bundled)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("SMB / NAS") {
                Button("Mount NAS in Finder…") {
                    KeychainService.promptMountInFinder(server: "nas.local", share: "backups")
                }
                Text("If your NAS credentials aren't saved, mount the share in Finder first. We'll read them from the Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Logs") {
                Button("Open Logs Folder") {
                    NSWorkspace.shared.open(StorageService.logDirectory)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Remote Settings

struct RemoteSettingsView: View {
    @State private var server: String = ""
    @State private var share: String = ""
    @State private var username: String = ""
    @State private var password: String = ""

    var body: some View {
        Form {
            Section("SMB Connection") {
                TextField("Server (e.g. nas.local)", text: $server)
                TextField("Share name (e.g. backups)", text: $share)
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
            }

            Section {
                Button("Save to Keychain") {
                    let context = KeychainService.SMBContext(
                        server: server,
                        share: share,
                        username: username,
                        password: password
                    )
                    if KeychainService.saveCredentials(context) {
                        // TODO: Show success alert
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Remove from Keychain") {
                    _ = KeychainService.deleteCredentials(server: server, username: username)
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Encryption Settings

struct EncryptionSettingsView: View {
    @State private var enableEncryption = false
    @State private var encryptionPassword = ""
    @State private var passwordRemember = ""

    var body: some View {
        Form {
            Section("rclone Crypt Remote") {
                Toggle("Enable encryption", isOn: $enableEncryption)
                Text("Encrypts files before uploading. Uses rclone's crypt remote.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if enableEncryption {
                Section("Encryption Password") {
                    SecureField("Password", text: $encryptionPassword)
                    SecureField("Password remember (optional)", text: $passwordRemember)
                    Text("These passwords are used by rclone to encrypt/decrypt your files. Store them safely.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
