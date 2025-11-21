//
//  ClipListView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI

struct ClipListView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @Binding var selectedItem: ClipItem?

    var body: some View {
        List(selection: $selectedItem) {
            ForEach(viewModel.filteredItems) { item in
                ClipItemRow(item: item)
                    .tag(item)
                    .contextMenu {
                        ClipItemContextMenu(item: item)
                    }
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Clip Item Row

struct ClipItemRow: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    let item: ClipItem

    var body: some View {
        HStack(spacing: 12) {
            // Content preview (icon or thumbnail)
            contentPreview
                .frame(width: 48, height: 48)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(item.title)
                    .font(.body)
                    .lineLimit(2)

                // Preview text (not for images)
                if !item.content.isImage {
                    Text(item.content.previewString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Metadata
                HStack(spacing: 8) {
                    // Source app
                    if let sourceApp = item.sourceApp {
                        Label(sourceApp, systemImage: "app")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Timestamp
                    Label(item.relativeTimestamp, systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // Size
                    if item.content.estimatedSize > 1024 {
                        Label(item.sizeDescription, systemImage: "opticaldiscdrive")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Badges
            HStack(spacing: 4) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }

                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            viewModel.copyAndPaste(item)
        }
        .onTapGesture(count: 1) {
            viewModel.copyItem(item)
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.content {
        case .image(let data, _):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                iconView
            }

        case .file(let url):
            filePreview(for: url)

        case .color(let colorInfo):
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(
                    red: colorInfo.red,
                    green: colorInfo.green,
                    blue: colorInfo.blue,
                    opacity: colorInfo.alpha
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

        default:
            iconView
        }
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.1))
            Image(systemName: item.content.iconName)
                .font(.title2)
                .foregroundColor(.accentColor)
        }
    }

    private func filePreview(for url: URL) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.1))
            VStack(spacing: 2) {
                Image(systemName: fileIcon(for: url))
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Text(url.pathExtension.uppercased())
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
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

struct ClipItemContextMenu: View {
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
struct ClipListView_Previews: PreviewProvider {
    static var previews: some View {
        ClipListView(selectedItem: .constant(nil))
            .environmentObject(ClipboardViewModel.preview)
            .frame(width: 600, height: 500)
    }
}
#endif
