import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            EncryptionSettingsView()
                .tabItem {
                    Label("Encryption", systemImage: "lock.fill")
                }
        }
        .frame(width: 450, height: 300)
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

            Section("Connecting to a NAS") {
                Text("When setting up a backup, browse to your mounted NAS volume as the destination folder. If it's not mounted yet, open it in Finder first — Finder will handle authentication and mounting.")
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
