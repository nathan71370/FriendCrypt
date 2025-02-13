//
//  NavigationRouter.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 13/02/2025.
//


import SwiftUI

final class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()
    
    func navigate(to link: DeepLink) {
        path.append(link)
    }
    
    func reset() {
        path.removeLast(path.count)
    }
}
