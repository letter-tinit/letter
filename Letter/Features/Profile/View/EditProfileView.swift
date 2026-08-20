//
//  EditProfileView.swift
//  Letter
//
//  Created by TiniT on 25/5/26.
//

import SwiftUI
import PhotosUI
import UIKit

private struct AvatarEditorItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct EditProfileView: View {
    @Environment(ProfileRouter.self) private var router
    @Environment(HabitViewModel.self) private var habitViewModel
    @State private var displayName: String = ""
    @State private var avatarOriginalData: Data?
    @State private var avatarData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarEditorItem: AvatarEditorItem?
    @State private var title = "habit.profile.edit".localized
    
    var body: some View {
        BaseScreen($title) {
            AppScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    avatarEditorSection
                    nameEditorSection
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("common.save".localized) {
                    habitViewModel.updateProfile(
                        displayName: trimmedDisplayName,
                        avatarOriginalData: avatarOriginalData,
                        avatarData: avatarData
                    )
                    router.pop()
                }
                .fontWeight(.semibold)
                .disabled(trimmedDisplayName.isEmpty)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                await loadAvatar(from: item)
            }
        }
        .sheet(item: $avatarEditorItem) { item in
            AvatarAdjustmentSheetView(image: item.image) { adjustedData in
                avatarOriginalData = avatarOriginalData ?? adjustedData
                avatarData = adjustedData
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .onAppear {
            displayName = habitViewModel.userProfile?.displayName ?? "habit.profile.defaultName".localized
            avatarOriginalData = habitViewModel.userProfile?.avatarOriginalData ?? habitViewModel.userProfile?.avatarData
            avatarData = habitViewModel.userProfile?.avatarData
        }
    }
    
    private var avatarEditorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("habit.profile.avatar".localized)
                .customFont(.headline)
            
            VStack(spacing: 14) {
                Button {
                    openAvatarEditorFromCurrentAvatar()
                } label: {
                    editableAvatarView
                }
                .buttonStyle(.plain)
                
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text("habit.profile.choosePhoto".localized)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .borderedBackground(cornerRadius: 16)
            .overlay(alignment: .topTrailing) {
                if avatarData != nil {
                    Button("habit.profile.removePhoto".localized) {
                        avatarOriginalData = nil
                        avatarData = nil
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
            }
        }
    }
    
    private var editableAvatarView: some View {
        Group {
            if let avatarData,
               let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(module: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(18)
            }
        }
        .frame(width: 132, height: 132)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .borderedBackground(cornerRadius: 66)
    }
    
    private var nameEditorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("habit.profile.name".localized)
                .customFont(.headline)
            
            TextField("habit.profile.name".localized, text: $displayName)
                .textInputAutocapitalization(.words)
                .padding()
                .borderedBackground(cornerRadius: 12)
        }
    }
    
    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func openAvatarEditorFromCurrentAvatar() {
        let sourceData = avatarOriginalData ?? avatarData
        guard let sourceData,
              let image = UIImage(data: sourceData)
        else {
            return
        }
        
        avatarEditorItem = AvatarEditorItem(image: image)
    }
    
    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self)
        else {
            return
        }
        
        await MainActor.run {
            selectedPhoto = nil
        }
        
        try? await Task.sleep(nanoseconds: 250_000_000)
        
        await MainActor.run {
            guard let image = UIImage(data: data) else {
                return
            }
            
            avatarOriginalData = data
            avatarEditorItem = AvatarEditorItem(image: image)
        }
    }
}

private struct AvatarAdjustmentSheetView: View {
    let image: UIImage
    let onSave: (Data) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    
    private let previewSize: CGFloat = 260
    private let outputSize: CGFloat = 512
    
    var body: some View {
        /// Implement NavigationStack for using Toolbar and it's title
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(width: previewSize, height: previewSize)
                            .clipShape(Circle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let proposedOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        offset = clampedOffset(proposedOffset, scale: scale)
                                    }
                                    .onEnded { _ in
                                        offset = clampedOffset(offset, scale: scale)
                                        lastOffset = offset
                                    }
                            )
                        
                        Circle()
                            .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                            .frame(width: previewSize, height: previewSize)
                    }
                    .frame(width: previewSize, height: previewSize)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("habit.profile.zoom".localized)
                            .customFont(.subheadline)
                            .fontWeight(.semibold)
                        
                        Slider(value: $scale, in: 1...3)
                            .onChange(of: scale) { _, newValue in
                                offset = clampedOffset(offset, scale: newValue)
                                lastOffset = offset
                            }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("habit.common.reset".localized) {
                        scale = 1
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.save".localized) {
                        if let data = adjustedAvatarData() {
                            onSave(data)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func adjustedAvatarData() -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSize, height: outputSize),
            format: format
        )
        
        let renderedImage = renderer.image { _ in
            let baseScale = max(outputSize / image.size.width, outputSize / image.size.height)
            let drawScale = baseScale * scale
            let drawSize = CGSize(
                width: image.size.width * drawScale,
                height: image.size.height * drawScale
            )
            let offsetMultiplier = outputSize / previewSize
            let drawOrigin = CGPoint(
                x: (outputSize - drawSize.width) / 2 + offset.width * offsetMultiplier,
                y: (outputSize - drawSize.height) / 2 + offset.height * offsetMultiplier
            )
            
            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
        
        return renderedImage.jpegData(compressionQuality: 0.82)
    }
    
    private func clampedOffset(_ proposedOffset: CGSize, scale: Double) -> CGSize {
        let displayedSize = displayedImageSize(scale: scale)
        let maxX = max((displayedSize.width - previewSize) / 2, 0)
        let maxY = max((displayedSize.height - previewSize) / 2, 0)
        
        return CGSize(
            width: min(max(proposedOffset.width, -maxX), maxX),
            height: min(max(proposedOffset.height, -maxY), maxY)
        )
    }
    
    private func displayedImageSize(scale: Double) -> CGSize {
        let baseScale = max(previewSize / image.size.width, previewSize / image.size.height)
        let drawScale = baseScale * scale
        
        return CGSize(
            width: image.size.width * drawScale,
            height: image.size.height * drawScale
        )
    }
}

#Preview {
    EditProfileView()
        .environment(ProfileRouter())
}
