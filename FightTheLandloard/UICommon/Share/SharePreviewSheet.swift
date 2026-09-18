//
//  SharePreviewSheet.swift
//  FightTheLandlord
//
//  Preview of a poster with theme toggle, save-to-Photos and the system share sheet.
//

import SwiftUI
import Photos
import UniformTypeIdentifiers

@MainActor
struct SharePreviewSheet: View {
    let content: ShareContent

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var dark = false
    @State private var image: UIImage?
    @State private var didInitialize = false
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    Group {
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.fill)
                                .frame(height: 480)
                                .overlay(ProgressView())
                        }
                    }
                    .padding(20)
                }
                .background(AppTheme.background)

                VStack(spacing: 12) {
                    Picker("主题", selection: $dark) {
                        Text("浅色").tag(false)
                        Text("深色").tag(true)
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        Button {
                            saveToPhotos()
                        } label: {
                            Label("保存到相册", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(image == nil)

                        if let image = image {
                            ShareLink(
                                item: PosterFile(image: image, name: content.fileName),
                                preview: SharePreview(content.title, image: Image(uiImage: image))
                            ) {
                                Label("分享", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        } else {
                            Button {} label: {
                                Label("分享", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(true)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.bar)
            }
            .navigationTitle(content.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .overlay(alignment: .top) {
                if let toast = toast {
                    Text(toast)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear {
                if !didInitialize {
                    didInitialize = true
                    dark = settings.shareDarkTheme
                }
                render()
            }
            .onChange(of: dark) { _, value in
                settings.shareDarkTheme = value
                render()
            }
        }
    }

    private func render() {
        image = ShareRenderer.render(content, dark: dark)
    }

    private func saveToPhotos() {
        guard let image = image else { return }
        PhotoSaver.save(image) { result in
            switch result {
            case .success:
                Haptics.success()
                showToast("已保存到相册")
            case .failure(let error):
                Haptics.warning()
                showToast(error.localizedDescription)
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = nil }
        }
    }
}

/// PNG file for the share sheet (keeps a readable file name in AirDrop / Files).
struct PosterFile: Transferable {
    let image: UIImage
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { poster in
            guard let data = poster.image.pngData() else { throw CocoaError(.fileWriteUnknown) }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(poster.name).png")
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

enum PhotoSaver {
    enum SaveError: LocalizedError {
        case denied
        var errorDescription: String? { "没有相册权限，请在设置中允许添加照片。" }
    }

    static func save(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        let finish: (Result<Void, Error>) -> Void = { result in
            DispatchQueue.main.async { completion(result) }
        }
        let perform = {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if success {
                    finish(.success(()))
                } else {
                    finish(.failure(error ?? SaveError.denied))
                }
            }
        }
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            perform()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                if status == .authorized || status == .limited { perform() } else { finish(.failure(SaveError.denied)) }
            }
        default:
            finish(.failure(SaveError.denied))
        }
    }
}
