import AppKit
import SwiftUI
import TextLensCore

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { model.settings.selectionPopupEnabled },
                set: { model.setPopupEnabled($0) }
            )) {
                Label("划词自动弹出", systemImage: "bolt.circle")
            }

            if !permissionPresentation.isActionDisabled {
                Button {
                    model.requestAccessibilityPermission()
                } label: {
                    Label("授权辅助功能", systemImage: permissionPresentation.systemImage)
                }
            }

            if let statusMessage = MenuBarStatusPolicy.displayMessage(for: model.statusMessage) {
                Divider()

                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
            } else {
                Divider()
            }

            Button {
                model.openSettings()
            } label: {
                Label("设置", systemImage: "gearshape")
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            model.refreshAccessibilityTrust()
        }
    }

    private var permissionPresentation: PermissionStatusPresentation {
        PermissionStatusPresentation.accessibility(isTrusted: model.accessibilityTrusted)
    }
}
