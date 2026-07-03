import TextLensCore
@preconcurrency import Translation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    permissionSection
                    selectionSection
                    modelSection
                }
                .padding(20)
            }
        }
        .frame(width: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            model.refreshAccessibilityTrust()
        }
        .task {
            model.refreshSelectedAppleLanguageAvailability()
        }
        .translationTask(model.appleLanguageDownloadConfiguration) { session in
            guard let request = model.currentAppleLanguageDownloadRequest() else { return }
            do {
                try await AppleTranslationService().prepare(request, using: session)
                let verifiedStatus = await AppleTranslationService().downloadStatus(
                    sourceLanguage: request.sourceLanguage,
                    targetLanguage: request.targetLanguage
                )
                model.completeAppleLanguageDownload(request, verifiedStatus: verifiedStatus)
            } catch {
                model.failAppleLanguageDownload(request, error: error)
            }
        }
    }

    private var targetLanguageBinding: Binding<String> {
        Binding(
            get: { model.settings.targetLanguage },
            set: { model.setTargetLanguage($0) }
        )
    }

    private var translationEngineBinding: Binding<TranslationEngine> {
        Binding(
            get: { model.settings.translationEngine },
            set: { model.setTranslationEngine($0) }
        )
    }

    private var appleLanguageDownloadPresentation: AppleLanguageDownloadControlPresentation? {
        AppleLanguageDownloadControlPresentation.make(
            translationEngine: model.settings.translationEngine,
            targetLanguage: model.settings.targetLanguage,
            status: model.appleLanguageDownloadStatus
        )
    }

    private var permissionPresentation: PermissionStatusPresentation {
        PermissionStatusPresentation.accessibility(isTrusted: model.accessibilityTrusted)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.tint)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("文镜")
                    .font(.system(size: 18, weight: .semibold))
                Text(model.accessibilityTrusted ? "已准备读取选区" : "需要辅助功能权限")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var permissionSection: some View {
        SettingsCard(title: "权限") {
            HStack(spacing: 12) {
                PermissionStatusIcon(presentation: permissionPresentation)

                VStack(alignment: .leading, spacing: 3) {
                    Text(permissionPresentation.title)
                        .font(.system(size: 13, weight: .medium))
                    Text(permissionPresentation.status)
                        .font(.caption)
                        .foregroundStyle(model.accessibilityTrusted ? .green : .secondary)
                }

                Spacer()

                Button {
                    model.requestAccessibilityPermission()
                } label: {
                    Label(permissionPresentation.actionTitle, systemImage: permissionPresentation.systemImage)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(permissionPresentation.isActionDisabled)
            }
        }
    }

    private var selectionSection: some View {
        SettingsCard(title: "划词") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { model.settings.selectionPopupEnabled },
                    set: { model.setPopupEnabled($0) }
                )) {
                    Label("划词自动弹出", systemImage: "cursorarrow.rays")
                }

                Divider()

                LabeledContent("目标语言") {
                    HStack(spacing: 8) {
                        Picker("", selection: targetLanguageBinding) {
                            ForEach(TargetLanguageOption.common, id: \.code) { option in
                                Text("\(option.name)  \(option.code)")
                                    .tag(option.code)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 210)

                        if let presentation = appleLanguageDownloadPresentation {
                            Button {
                                model.prepareSelectedAppleLanguage()
                            } label: {
                                Label(presentation.title, systemImage: presentation.systemImageName)
                            }
                            .controlSize(.small)
                            .frame(width: 132)
                            .disabled(presentation.isDisabled)
                            .help(presentation.helpText)
                        }
                    }
                }

                LabeledContent("翻译引擎") {
                    Picker("", selection: translationEngineBinding) {
                        Text("Apple")
                            .tag(TranslationEngine.appleTranslation)
                        Text("大模型")
                            .tag(TranslationEngine.openAICompatible)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 210)
                }

            }
        }
    }

    private var modelSection: some View {
        SettingsCard(title: "大模型") {
            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        SettingsFieldLabel("Base URL")
                        TextField("https://api.openai.com", text: $model.baseURLDraft)
                    }

                    GridRow {
                        SettingsFieldLabel("Model")
                        TextField("gpt-4.1-mini", text: $model.modelDraft)
                    }

                    GridRow {
                        SettingsFieldLabel("API Key")
                        SecureField("sk-...", text: $model.apiKeyDraft)
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    Button {
                        model.saveSettingsFromDrafts()
                        model.saveAPIKey()
                    } label: {
                        Label("保存", systemImage: "tray.and.arrow.down")
                    }
                    .controlSize(.small)

                    Button {
                        model.saveSettingsFromDrafts()
                        model.saveAPIKey()
                        model.testModelConnection()
                    } label: {
                        Label("测试", systemImage: "network")
                    }
                    .controlSize(.small)

                    if !model.modelStatusMessage.isEmpty {
                        Text(model.modelStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                content
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            )
        }
    }
}

private struct PermissionStatusIcon: View {
    var presentation: PermissionStatusPresentation

    var body: some View {
        Image(systemName: presentation.systemImage)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(presentation.isActionDisabled ? .green : .blue)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill((presentation.isActionDisabled ? Color.green : Color.blue).opacity(0.12))
            )
    }
}

private struct SettingsFieldLabel: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 72, alignment: .leading)
    }
}
