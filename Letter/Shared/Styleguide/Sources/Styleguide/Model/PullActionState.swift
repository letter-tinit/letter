//
//  PullActionState.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 16/10/26.
//

import Foundation

// MARK: - State
/// Trạng thái của thao tác kéo. `progress` được chuẩn hoá về 0...1.
public enum PullActionState: Equatable {
    case idle
    case pulling(progress: CGFloat)
    case armed   // đã vượt threshold – thả tay là action chạy
}
