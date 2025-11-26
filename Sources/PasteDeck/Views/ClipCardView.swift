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
    let onClearFocus: () -> Void

    func makeNSView(context: Context) -> ClickableNSView {
        let view = ClickableNSView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        view.onClearFocus = onClearFocus
        return view
    }

    func updateNSView(_ nsView: ClickableNSView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
        nsView.onClearFocus = onClearFocus
    }

    class ClickableNSView: NSView {
        var onSingleClick: (() -> Void)?
        var onDoubleClick: (() -> Void)?
        var onClearFocus: (() -> Void)?

        override func mouseDown(with event: NSEvent) {
            // Clear focus first
            onClearFocus?()

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

struct ClipCardView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @EnvironmentObject var focusManager: FocusManager
    let item: ClipItem
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    private let cardSize: CGFloat = 180

    /// Unified brand blue color for all type badges (Paste style)
    private let badgeColor = Color(red: 0.2, green: 0.5, blue: 1.0)

    var body: some View {
        VStack(spacing: 0) {
            // Type badge at top (Paste style - full width)
            HStack(spacing: 8) {
                // Left: icon + type name
                HStack(spacing: 4) {
                    Image(systemName: item.content.iconName)
                        .font(.system(size: 11))
                    Text(item.content.typeName)
                        .font(.system(size: 11, weight: .medium))
                }

                Spacer()

                // Right: relative time
                Text(item.relativeTimestamp)
                    .font(.system(size: 11))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(badgeColor)
            .clipShape(RoundedCornerShape(corners: [.topLeft, .topRight], radius: 8))

            Spacer()

            // Content preview
            contentPreview
                .frame(width: cardSize - 16, height: cardSize - 90)
                .clipped()
                .padding(.horizontal, 8)

            Spacer()

            // Footer with size/character metadata
            HStack {
                Text(item.content.displayMetadata)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
        .frame(width: cardSize, height: cardSize)
        .contentShape(Rectangle())
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.accentColor : (isHovered ? Color.white.opacity(0.3) : Color.white.opacity(0.1)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.25 : 0.15), radius: isHovered ? 6 : 3, y: 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .overlay(
            // Use NSView-based click handler for instant response (no SwiftUI gesture delay)
            InstantClickHandler(
                onSingleClick: {
                    onSelect()
                },
                onDoubleClick: {
                    viewModel.copyAndPaste(item)
                },
                onClearFocus: {
                    focusManager.clearSearchFocus()
                }
            )
            .allowsHitTesting(true)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            ClipCardContextMenu(item: item)
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.content {
        case .text(let string, _):
            textPreview(string)

        case .image(let data, _):
            imagePreview(data)

        case .url(let url):
            urlPreview(url)

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
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(6)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(8)
    }

    private func imagePreview(_ data: Data) -> some View {
        Group {
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardSize - 16, height: cardSize - 90)
                    .clipped()
                    .contentShape(Rectangle())
            } else {
                iconPlaceholder("photo")
            }
        }
    }

    private func urlPreview(_ url: URL) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)

            Text(url.host ?? url.absoluteString)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
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

// MARK: - Context Menu

struct ClipCardContextMenu: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    let item: ClipItem

    var body: some View {
        Button("Copy") {
            viewModel.copyItem(item)
        }

        Button("Copy and Paste") {
            viewModel.copyAndPaste(item)
        }

        Divider()

        Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            viewModel.toggleFavorite(item)
        }

        Button(item.isPinned ? "Unpin" : "Pin to Top") {
            viewModel.togglePin(item)
        }

        Divider()

        Button("Delete", role: .destructive) {
            viewModel.deleteItem(item)
        }
    }
}

// MARK: - Custom Shape for Top Corners Only

struct RoundedCornerShape: Shape {
    var corners: Set<Corner>
    var radius: CGFloat

    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))

        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))

        // Top right corner
        if topRight > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                radius: topRight,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
        }

        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))

        // Bottom right corner
        if bottomRight > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                radius: bottomRight,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        }

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))

        // Bottom left corner
        if bottomLeft > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                radius: bottomLeft,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        }

        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))

        // Top left corner
        if topLeft > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                radius: topLeft,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }

        path.closeSubpath()
        return path
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
                onSelect: { }
            )

            ClipCardView(
                item: ClipItem(
                    content: .url(URL(string: "https://github.com")!),
                    sourceApp: "Safari",
                    isFavorite: true
                ),
                isSelected: true,
                onSelect: { }
            )
        }
        .padding()
        .environmentObject(ClipboardViewModel.preview)
    }
}
#endif
