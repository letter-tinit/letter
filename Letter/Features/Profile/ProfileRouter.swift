//
//  ProfileRouter.swift
//  Letter
//
//  Created by TiniT on 25/5/26.
//

import Observation

enum ProfileRoute: Hashable {
    case editProfile
}

@Observable
final class ProfileRouter: AppRouter<ProfileRoute> {}
