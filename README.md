# TextLens（文镜）

<img src="Resources/AppIcon.png" alt="TextLens app icon" align="center" width="96">
    
一个简单好用的原生 macOS 菜单栏小工具：开启“划词自动弹出”后，在其他 App 中选中文本，TextLens 会读取当前选区并弹出翻译和 AI 解释。


## 功能

仅支持两个功能

- 划词弹出翻译和解释
- 支持原生apple 翻译引擎（建议下载，一次即可，翻译速度很快）
- 支持大模型翻译和解释

## 系统要求

- macOS 15 或更新版本
- 使用划词自动弹出需要授予 Accessibility 辅助功能权限

## 构建和运行

```bash
swift test
scripts/package-app.sh
open .build/TextLens.app
```

第一次运行后，在菜单栏点击“文镜”图标，选择“请求辅助功能权限”，然后到系统设置里允许 `TextLens` 使用辅助功能。

## 翻译和大模型配置

打开 TextLens 设置页，可以选择翻译引擎：

- `Apple`：默认选项，使用 macOS 系统翻译能力。
- `大模型`：使用 OpenAI-compatible Chat Completions 做翻译。

大模型用于 AI 解释，也作为 Apple 翻译不可用时的 fallback。需要填写：

- `Base URL`：例如 `https://api.openai.com` 或兼容 OpenAI Chat Completions 的服务地址
- `Model`：例如 `gpt-4.1-mini`
- `API Key`：保存到本机应用配置

## macOS 能力说明

- 选中文本读取使用 macOS Accessibility API，需要辅助功能权限。
- 默认翻译使用 Apple Translation framework。语言不可用、系统翻译失败或用户选择“大模型”时，翻译走 OpenAI-compatible fallback。
- AI 解释通过你配置的大模型完成。

## 隐私说明

TextLens 不包含遥测、广告 SDK、账号系统或远程日志上传。
划词翻译或解释时，选中文本会交给 Apple Translation 或你配置的 OpenAI-compatible 服务处理；API Key 只保存在本机配置中。

## 依赖

- [PermissionFlow](https://github.com/jaywcjlove/PermissionFlow)：用于引导用户授权 macOS 权限。

## 贡献

- 欢迎贡献，帮助更多的人，如果帮到了你还请不吝 Star🌟

## 许可证

TextLens 使用 [MIT License](LICENSE) 开源。
