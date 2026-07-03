# Privacy

TextLens is a local macOS utility. It does not include analytics, telemetry, crash reporting, advertising SDKs, or a remote account system.

## What TextLens Reads

When the selection popup is enabled, TextLens listens for global mouse and keyboard selection gestures and uses macOS Accessibility APIs to read the selected text from the frontmost app.

TextLens does not try to read documents, windows, browsing history, files, or clipboard history. Clipboard fallback is only used for supported selection paths when the selected text is not exposed through Accessibility.

## Where Text Goes

Selected text can be processed in these places:

- On device, inside TextLens, for selection filtering and display.
- Apple Translation, when the Apple translation engine is selected or available as the default translation path.
- The OpenAI-compatible provider configured by the user, when using AI explanation, model translation, or fallback translation.

If you configure a third-party AI provider, the selected text and request prompt are sent to that provider's API endpoint. Review that provider's privacy policy before using it with sensitive text.

## API Keys

API keys are stored in TextLens local app preferences on this Mac. They are not written to the repository, logs, or README examples.

## Permissions

TextLens needs Accessibility permission to read selected text from other apps. Without that permission, automatic selection capture cannot work reliably.

PermissionFlow guides users to the macOS Accessibility settings and helps TextLens detect when authorization is granted. It does not bypass macOS privacy controls, and TextLens still appears in the system Accessibility app list.

## Data Retention

TextLens does not intentionally persist selected text. Translation and explanation results are held in app memory for the current interaction.

If you use an external AI provider, that provider may process or retain requests according to its own policy.
