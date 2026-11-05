import SwiftUI

/// A row of everything tried this session, newest on the right. Click one to bring it back.
struct VersionsStrip: View {
    @Environment(EditorModel.self) private var model

    /// The newest version whose design matches the cover on the canvas.
    private var currentID: UUID? {
        model.versions.versions.last { VersionHistory.sameDesign($0.document, model.document) }?.id
    }

    var body: some View {
        let versions = model.versions.versions
        let current = currentID
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Versions")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(versions.isEmpty ? "Nothing yet" : "\(versions.count) tried")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                Button("Clear") { model.versions.clear() }
                    .buttonStyle(.link)
                    .font(.system(size: 10))
                    .disabled(versions.count < 2)
                    .help("Forget the versions tried this session")
            }
            .frame(width: 72, alignment: .leading)
            .padding(.leading, 14)
            .padding(.vertical, 10)
            Divider().padding(.vertical, 10)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 10) {
                        if versions.isEmpty {
                            Text("Randomize, apply a template, polish or repair, and each result lands here so you can go back to it.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 360, alignment: .leading)
                                .padding(.top, 8)
                        }
                        ForEach(versions) { v in
                            VersionCard(version: v, isCurrent: v.id == current, isPinned: model.versions.isPinned(v.id))
                                .id(v.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onAppear {
                    if let l = versions.last { proxy.scrollTo(l.id, anchor: .trailing) }
                }
                .onChange(of: versions.count) { _, _ in
                    if let l = versions.last { withAnimation { proxy.scrollTo(l.id, anchor: .trailing) } }
                }
            }
        }
        .frame(height: 134)
        .background(.bar)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }
}

private struct VersionCard: View {
    @Environment(EditorModel.self) private var model
    let version: VersionHistory.Version
    let isCurrent: Bool
    let isPinned: Bool
    @State private var hover = false

    private static let thumbHeight: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            thumbnail
                .frame(height: VersionCard.thumbHeight)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(isCurrent ? Theme.accent : Color.primary.opacity(0.12), lineWidth: isCurrent ? 2 : 1))
                .overlay(alignment: .topTrailing) {
                    if hover || isPinned {
                        Button { model.versions.togglePin(version.id) } label: {
                            Image(systemName: isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(isPinned ? Theme.accent : Color.white)
                                .padding(5)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .help(isPinned ? "Unpin: this version may be dropped when the strip is full" : "Pin: keep this version even when the strip is full")
                        .accessibilityLabel(isPinned ? "Unpin version" : "Pin version")
                    }
                }
                .shadow(color: .black.opacity(hover ? 0.3 : 0.15), radius: hover ? 6 : 2, y: 2)
            HStack(spacing: 4) {
                Text(version.reason)
                    .font(.system(size: 10, weight: isCurrent ? .semibold : .medium))
                    .foregroundStyle(isCurrent ? Theme.accent : .primary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                if let s = version.score {
                    Text("\(Int(s.rounded()))")
                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                        .help("Design score when this version was taken")
                }
            }
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                Text(VersionCard.ago(version.date, now: ctx.date))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(width: max(64, VersionCard.thumbHeight / CGFloat(version.document.canvas.aspect)))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { model.restoreVersion(version.id) }
        .contextMenu {
            Button("Restore") { model.restoreVersion(version.id) }
            Button(isPinned ? "Unpin" : "Pin") { model.versions.togglePin(version.id) }
            Button("Compare with Current") { model.compareVersion(version.id) }
                .disabled(version.thumbnail == nil)
            Divider()
            Button("Remove", role: .destructive) { model.versions.remove(version.id) }
        }
        .help(isCurrent ? "The cover as it is now" : "Click to bring this version back (undoable)")
        .animation(.easeOut(duration: 0.15), value: hover)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let t = version.thumbnail {
            Image(decorative: t, scale: 1)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fit)
        } else {
            Rectangle().fill(Color.primary.opacity(0.06))
                .aspectRatio(1 / version.document.canvas.aspect, contentMode: .fit)
                .overlay(ProgressView().controlSize(.mini))
        }
    }

    static func ago(_ date: Date, now: Date) -> String {
        let s = Int(now.timeIntervalSince(date))
        if s < 45 { return "just now" }
        if s < 3600 { return "\(max(1, s / 60)) min ago" }
        if s < 86_400 { return "\(s / 3600) h ago" }
        return "\(s / 86_400) d ago"
    }
}
