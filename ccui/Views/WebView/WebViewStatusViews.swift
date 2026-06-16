import SwiftUI

/// Shown over the WebView when the panel is still at `about:blank`,
/// inviting the user to enter a URL.
struct WebViewPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 20, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)
            Text("Enter a URL above to preview your dev server")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }
}

/// Shown over the WebView when the most recent navigation failed, offering
/// a retry action.
struct WebViewErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)
            Text(message)
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }
}
