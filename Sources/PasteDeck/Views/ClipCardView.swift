//
//  ClipCardView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI
import AppKit

// MARK: - Instant Click Handler (No Delay)

struct InstantClickHandler: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> ClickableNSView {
        let view = ClickableNSView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: ClickableNSView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
    }

    class ClickableNSView: NSView {
        var onSingleClick: (() -> Void)?
        var onDoubleClick: (() -> Void)?

        override func mouseDown(with event: NSEvent) {
            // Check for double click first
            if event.clickCount == 2 {
                // Double click - only trigger double click action
                onDoubleClick?()
            } else {
                // Single click - immediately trigger selection (no delay)
                onSingleClick?()
            }
        }
    }
}

struct ClipCardView: View, Equatable {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let item: ClipItem
    let isSelected: Bool
    let onAction: (ClipCardAction) -> Void

    @State private var isHovered = false
    @State private var preview: CardPreviewCache.Preview?

    private let cardSize: CGFloat = 180
    private let headerHeight: CGFloat = 46
    private let footerHeight: CGFloat = 24
    private let cornerRadius: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            cardHeader

            contentPreview
                .frame(width: cardSize, height: contentHeight)
                .clipped()

            cardFooter
        }
        .frame(width: cardSize, height: cardSize)
        .contentShape(Rectangle())
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor :
                        (isHovered ? Color.secondary.opacity(0.55) : Color(nsColor: .separatorColor)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(isSelected ? 0.20 : 0.14), radius: 4, y: 2)
        .overlay(
            InstantClickHandler(
                onSingleClick: { onAction(.select) },
                onDoubleClick: { onAction(.copyAndPaste) }
            )
            .allowsHitTesting(true)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            ClipCardContextMenu(
                item: item,
                onAction: onAction
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityValue(cardAccessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: Text("复制")) {
            onAction(.copy)
        }
        .accessibilityAction(named: Text("复制并粘贴")) {
            onAction(.copyAndPaste)
        }
        .accessibilityAction(named: Text(item.isPinned ? "取消置顶" : "置顶")) {
            onAction(.togglePin)
        }
        .accessibilityAction(named: Text(item.isFavorite ? "取消收藏" : "收藏")) {
            onAction(.toggleFavorite)
        }
        .task(id: item.id) {
            let loadedPreview = await CardPreviewCache.shared.preview(for: item)
            guard !Task.isCancelled else { return }
            preview = loadedPreview
        }
    }

    static func == (lhs: ClipCardView, rhs: ClipCardView) -> Bool {
        lhs.item.id == rhs.item.id &&
        lhs.item.isPinned == rhs.item.isPinned &&
        lhs.item.isFavorite == rhs.item.isFavorite &&
        lhs.isSelected == rhs.isSelected
    }

    private var contentHeight: CGFloat {
        cardSize - headerHeight - footerHeight
    }

    private var cardHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: item.content.iconName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))

                    Text(item.content.typeName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if item.isPinned || item.isFavorite {
                        cardStatusIndicators
                    }
                }

                Text(item.relativeTimestamp)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.76))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            SourceAppBadge(sourceApp: item.sourceApp)
        }
        .padding(.horizontal, 11)
        .frame(height: headerHeight)
        .background(headerColor)
        .clipped()
    }

    private var cardStatusIndicators: some View {
        HStack(spacing: 3) {
            if item.isPinned {
                statusIcon(
                    systemName: "pin.fill",
                    foregroundColor: .white,
                    help: "已置顶"
                )
            }

            if item.isFavorite {
                statusIcon(
                    systemName: "star.fill",
                    foregroundColor: Color(red: 1.0, green: 0.88, blue: 0.52),
                    help: "已收藏"
                )
            }
        }
        .animation(pinAnimation, value: item.isPinned)
        .animation(pinAnimation, value: item.isFavorite)
    }

    private func statusIcon(
        systemName: String,
        foregroundColor: Color,
        help: String
    ) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(foregroundColor)
            .transition(pinTransition)
            .help(help)
            .frame(width: 12, height: 12)
            .accessibilityHidden(true)
    }

    private var cardFooter: some View {
        Text(preview?.metadata ?? "")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 10)
            .frame(height: footerHeight)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .top) {
                Divider()
            }
    }

    private var headerColor: Color {
        switch item.content {
        case .text:
            return Color(red: 0.09, green: 0.22, blue: 0.40)
        case .image:
            return Color(red: 0.11, green: 0.43, blue: 0.40)
        case .file, .multipleFiles:
            return Color(red: 0.31, green: 0.35, blue: 0.40)
        case .color:
            return Color(red: 0.65, green: 0.36, blue: 0.08)
        }
    }

    private var cardAccessibilityLabel: Text {
        Text("\(item.content.typeName)，\(item.title)")
    }

    private var cardAccessibilityValue: Text {
        var values = [item.relativeTimestamp]
        if let sourceApp = item.sourceApp?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sourceApp.isEmpty {
            values.append("来源 \(sourceApp)")
        }
        if item.isPinned {
            values.append("已置顶")
        }
        if item.isFavorite {
            values.append("已收藏")
        }
        if isSelected {
            values.append("已选中")
        }
        return Text(values.joined(separator: "，"))
    }

    private var pinTransition: AnyTransition {
        accessibilityReduceMotion ? .opacity : .scale(scale: 0.75).combined(with: .opacity)
    }

    private var pinAnimation: Animation {
        .easeOut(duration: accessibilityReduceMotion ? 0.12 : 0.16)
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.content {
        case .text(let string, _):
            textPreview(string)

        case .image:
            imagePreview()

        case .file(let url):
            filePreview(url)

        case .multipleFiles(let urls):
            multipleFilesPreview(urls)

        case .color(let colorInfo):
            colorPreview(colorInfo)
        }
    }

    private func textPreview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(5)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(11)
    }

    private func imagePreview() -> some View {
        Group {
            if let image = preview?.image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardSize, height: contentHeight)
                    .clipped()
                    .contentShape(Rectangle())
            } else {
                iconPlaceholder("photo")
            }
        }
    }

    private func filePreview(_ url: URL) -> some View {
        VStack(spacing: 8) {
            Image(systemName: fileIcon(for: url))
                .font(.system(size: 28))
                .foregroundColor(.accentColor)

            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }

    private func multipleFilesPreview(_ urls: [URL]) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)

            Text("\(urls.count) files")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func colorPreview(_ colorInfo: ClipContent.ColorInfo) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(
                    red: colorInfo.red,
                    green: colorInfo.green,
                    blue: colorInfo.blue,
                    opacity: colorInfo.alpha
                ))
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Text(colorInfo.hexString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func iconPlaceholder(_ iconName: String) -> some View {
        VStack {
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "ppt", "pptx": return "slider.horizontal.below.rectangle"
        case "zip", "rar", "7z": return "doc.zipper"
        case "mp3", "wav", "m4a": return "music.note"
        case "mp4", "mov", "avi": return "film"
        case "jpg", "jpeg", "png", "gif": return "photo"
        default: return "doc.fill"
        }
    }
}

private struct SourceAppBadge: View {
    let sourceApp: String?
    @State private var resolvedIcon: NSImage?

    var body: some View {
        ZStack(alignment: .leading) {
            if let resolvedIcon {
                Image(nsImage: resolvedIcon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 62, height: 62)
                    .offset(x: -7)
            } else if let initial {
                Text(initial)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.90))
                    .lineLimit(1)
                    .frame(width: 34, height: 34)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.80))
                    .frame(width: 34, height: 34)
            }
        }
        .frame(width: 34, height: 34, alignment: .leading)
        .help(sourceName ?? "未知来源")
        .accessibilityHidden(true)
        .task(id: sourceName) {
            guard let sourceName else {
                resolvedIcon = nil
                return
            }

            let result = await SourceAppIconResolver.shared.icon(for: sourceName)
            guard !Task.isCancelled else { return }
            resolvedIcon = result.image
        }
    }

    private var sourceName: String? {
        guard let sourceApp else { return nil }
        let trimmed = sourceApp.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var initial: String? {
        sourceName?.first.map { String($0).uppercased() }
    }
}

private struct SourceAppIconResult: @unchecked Sendable {
    let image: NSImage?
}

private actor SourceAppIconResolver {
    static let shared = SourceAppIconResolver()

    private enum CacheEntry {
        case icon(NSImage)
        case missing
    }

    private var cache: [String: CacheEntry] = [:]

    func icon(for sourceName: String) async -> SourceAppIconResult {
        let cacheKey = sourceName.lowercased()
        if let cached = cache[cacheKey] {
            switch cached {
            case .icon(let image):
                return SourceAppIconResult(image: image)
            case .missing:
                return SourceAppIconResult(image: nil)
            }
        }

        let result = await Self.loadIcon(for: sourceName)
        if let image = result.image {
            cache[cacheKey] = .icon(image)
        } else {
            cache[cacheKey] = .missing
        }
        return result
    }

    private static func loadIcon(for sourceName: String) async -> SourceAppIconResult {
        let runningResult = await MainActor.run { () -> SourceAppIconResult in
            let application = NSWorkspace.shared.runningApplications
                .first { $0.localizedName?.localizedCaseInsensitiveCompare(sourceName) == .orderedSame }
            return SourceAppIconResult(image: application?.icon as? NSImage)
        }
        if runningResult.image != nil {
            return runningResult
        }

        let appURL = await Task.detached(priority: .utility) {
            let safeName = sourceName.replacingOccurrences(of: "/", with: "")
            let appName = "\(safeName).app"
            let directories = [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Applications", isDirectory: true),
                URL(fileURLWithPath: "/System/Applications", isDirectory: true),
                URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
                URL(fileURLWithPath: "/System/Library/CoreServices", isDirectory: true)
            ]

            return directories
                .map { $0.appendingPathComponent(appName, isDirectory: true) }
                .first { FileManager.default.fileExists(atPath: $0.path) }
        }.value

        guard let appURL else {
            return SourceAppIconResult(image: nil)
        }

        return await MainActor.run {
            SourceAppIconResult(image: NSWorkspace.shared.icon(forFile: appURL.path))
        }
    }
}

// MARK: - Context Menu

struct ClipCardContextMenu: View {
    let item: ClipItem
    let onAction: (ClipCardAction) -> Void

    var body: some View {
        Button("Copy") {
            onAction(.copy)
        }

        Button("Copy and Paste") {
            onAction(.copyAndPaste)
        }

        Divider()

        Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            onAction(.toggleFavorite)
        }

        Button(item.isPinned ? "Unpin" : "Pin to Top") {
            onAction(.togglePin)
        }

        Divider()

        Button("Delete", role: .destructive) {
            onAction(.delete)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ClipCardView_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            ClipCardView(
                item: ClipItem(
                    content: .text("Hello, World! This is a sample text that might be longer.", isRTF: false),
                    sourceApp: "TextEdit"
                ),
                isSelected: false,
                onAction: { _ in }
            )

            ClipCardView(
                item: ClipItem(
                    content: .text("https://github.com", isRTF: false),
                    sourceApp: "Safari",
                    isFavorite: true
                ),
                isSelected: true,
                onAction: { _ in }
            )
        }
        .padding()
    }
}
#endif
