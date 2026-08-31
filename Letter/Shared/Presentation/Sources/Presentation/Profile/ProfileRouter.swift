//
//  ProfileRouter.swift
//  Letter
//
//  Created by TiniT on 25/5/26.
//

import Observation
import Domain
import Utility
import Styleguide

public enum ProfileRoute: Hashable {
    case editProfile
}

@Observable
public final class ProfileRouter: AppRouter<ProfileRoute> {}
