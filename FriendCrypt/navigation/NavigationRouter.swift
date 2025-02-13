//
//  NavigationRouter.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 13/02/2025.
//


import SwiftUI

final class NavigationRouter: ObservableObject {
    static let shared = NavigationRouter()
    @Published var path = NavigationPath()
    
    // A pending deep link that gets processed on launch.
    var pendingDeepLink: DeepLink? {
        didSet {
            if let link = pendingDeepLink {
                path.append(link)
                pendingDeepLink = nil
            }
        }
    }
    
    func navigate(to link: DeepLink) {
        path.append(link)
    }
}
