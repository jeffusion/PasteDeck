//
//  ClipCardView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI

struct ClipCardView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    let item: ClipItem
    let isSelected: Bool

    @State private var isHovered = false

    private let cardSize: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            // Content preview
            contentPreview
                .frame(width: cardSize, height: cardSize - 30)
                .clipped()

            // Footer with metadata
            HStack(spacing: 4) {
                Image(systemName: item.content.iconName)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(item.relativeTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                // Badges
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                }
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        }
        .frame(width: cardSize, height: cardSize)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? Color.accentColor : (isHovered ? Color.secondary.opacity(0.5) : Color.clear),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 8 : 4, y: 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            viewModel.copyAndPaste(item)
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
                isSelected: false
            )

            ClipCardView(
                item: ClipItem(
                    content: .url(URL(string: "https://github.com")!),
                    sourceApp: "Safari",
                    isFavorite: true
                ),
                isSelected: true
            )
        }
        .padding()
        .environmentObject(ClipboardViewModel.preview)
    }
}
#endif
