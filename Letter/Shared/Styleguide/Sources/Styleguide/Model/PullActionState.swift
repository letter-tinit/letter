//
//  PullActionState.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 13/10/26.
//

import SwiftUI

public enum PullActionState {
    /// The user is pulling but hasn't reached the threshold.
    case pulling

    /// The user has reached the threshold and can release.
    case ready

    /// The action is currently running.
    case performing
}
