import SwiftUI

/// Inline `attachment` part renderer. Image attachments preview via
/// `AsyncImage`; everything else falls back to a filename + mime-type row
/// with a download icon. `workspace://` URLs are rewritten to the API base
/// URL via `WorkspaceURL.resolve` (see IOS_MESSAGE_PARTS_PLAN §5.4).
struct AttachmentRow: View {
    let attachment: Attachment

    @Environment(\.openURL) private var openURL

    private var resolved: URL? { WorkspaceURL.resolve(attachment.url) }

    private var isImage: Bool {
        attachment.mimeType.lowercased().hasPrefix("image/")
    }

    private var icon: String {
        let mime = attachment.mimeType.lowercased()
        if mime.hasPrefix("image/")             { return "photo" }
        if mime.contains("pdf")                  { return "doc.richtext" }
        if mime.hasPrefix("video/")              { return "play.rectangle" }
        if mime.hasPrefix("audio/")              { return "waveform" }
        if mime.hasPrefix("text/")               { return "doc.text" }
        return "paperclip"
    }

    var body: some View {
        Button {
            if let url = resolved { openURL(url) }
        } label: {
            content
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(resolved == nil)
        .accessibilityLabel(attachment.name)
    }

    @ViewBuilder
    private var content: some View {
        if isImage, let url = resolved {
            imagePreview(url: url)
        } else {
            fileRow
        }
    }

    private func imagePreview(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    failedPlaceholder
                @unknown default:
                    placeholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(attachment.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let size = attachment.size {
                    Text("·").foregroundStyle(.tertiary)
                    Text(formatSize(size))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var fileRow: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(attachment.mimeType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let size = attachment.size {
                        Text("·").foregroundStyle(.tertiary)
                        Text(formatSize(size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.down.circle")
                .font(.body)
                .foregroundStyle(resolved == nil ? .tertiary : .secondary)
        }
        .cardStyle(.compact)
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.08)
            ProgressView().controlSize(.small)
        }
    }

    private var failedPlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.08)
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(attachment.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(8)
        }
    }

    private func formatSize(_ bytes: Int) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(bytes))
    }
}
