//
//  SettingsView.swift
//  FightTheLandlord
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker("分数颜色", selection: $settings.greenWin) {
                        Text("绿色为赢").tag(true)
                        Text("红色为赢").tag(false)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("预览")
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        ScoreText(value: 300, size: 17)
                        Text("/").foregroundStyle(AppTheme.textTertiary)
                        ScoreText(value: -150, size: 17)
                    }
                    Picker("列表分数", selection: $settings.scorePerGame) {
                        Text("每局得分").tag(true)
                        Text("累计总分").tag(false)
                    }
                } header: {
                    Text("显示")
                } footer: {
                    Text("红色在中国传统里代表喜庆，可按习惯选择哪种颜色代表赢。")
                }

                Section {
                    Picker("自动结束对局", selection: $settings.autoFinishHours) {
                        ForEach(AppSettings.autoFinishOptions, id: \.hours) { option in
                            Text(option.label).tag(option.hours)
                        }
                    }
                    Toggle("触感反馈", isOn: $settings.hapticsEnabled)
                } header: {
                    Text("对局")
                } footer: {
                    Text("离开 App 时当前对局会自动保存到历史。超过设定时间没有新记录，对局会自动结束；之后仍可在历史中继续这场对局。")
                }

                Section {
                    Toggle("使用深色海报", isOn: $settings.shareDarkTheme)
                } header: {
                    Text("分享")
                }

                SyncSettingsSection()

                Section("关于") {
                    LabeledContent("版本") {
                        Text(AppInfo.versionString).foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

enum AppInfo {
    static var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let build = build, !build.isEmpty { return "\(version) (\(build))" }
        return version
    }
}
