import AppKit
import SwiftUI

/// Lets the user drag out a rectangle over the page, then crops a snapshot of
/// the page to that rectangle and sends it to the agent's terminal as a
/// pasted image. Shown only while `WebViewStore.isRegionCaptureActive` is true.
struct RegionCaptureOverlayView: View {
    let worktree: Worktree
    let store: WebViewStore
    let session: any TerminalSession
    @Environment(TerminalSessionStore.self) private var terminalSessionStore

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.2)

                if let rect = selectionRect {
                    Rectangle()
                        .fill(Color.accent.opacity(0.15))
                        .overlay(Rectangle().stroke(Color.accent, lineWidth: 1.5))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .local)
                    .onChanged { value in
                        if dragStart == nil { dragStart = value.startLocation }
                        dragCurrent = value.location
                    }
                    .onEnded { _ in
                        guard let rect = selectionRect, rect.width > 4, rect.height > 4 else {
                            cancel()
                            return
                        }
                        capture(rect: rect, viewSize: proxy.size)
                    }
            )
        }
        .onExitCommand { cancel() }
    }

    private var selectionRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    private func cancel() {
        dragStart = nil
        dragCurrent = nil
        store.isRegionCaptureActive = false
    }

    private func capture(rect: CGRect, viewSize: CGSize) {
        Task {
            if let snapshot = await store.captureSnapshot(),
               let cropped = Self.crop(snapshot, to: rect, viewSize: viewSize) {
                pasteIfStillCurrent(cropped)
            }
            cancel()
        }
    }

    /// The snapshot capture is asynchronous, so the worktree's session may
    /// have been replaced or terminated by the time it completes. Re-resolve
    /// the session and only paste if it's still the same running process —
    /// otherwise the image could land in a stale or dead terminal.
    private func pasteIfStillCurrent(_ image: NSImage) {
        guard let current = terminalSessionStore.session(for: worktree),
              current.id == session.id,
              current.isProcessRunning else { return }
        current.pasteImage(image)
    }

    /// Crops `image` to the portion corresponding to `rect` in a view of size
    /// `viewSize`. `rect` uses a top-left origin (SwiftUI convention); NSImage
    /// drawing uses a bottom-left origin, so the y-axis is flipped.
    private static func crop(_ image: NSImage, to rect: CGRect, viewSize: CGSize) -> NSImage? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        let scaleX = image.size.width / viewSize.width
        let scaleY = image.size.height / viewSize.height

        let sourceRect = CGRect(
            x: rect.minX * scaleX,
            y: image.size.height - rect.maxY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )

        let result = NSImage(size: sourceRect.size)
        result.lockFocus()
        defer { result.unlockFocus() }
        image.draw(at: .zero, from: sourceRect, operation: .copy, fraction: 1)
        return result
    }
}
