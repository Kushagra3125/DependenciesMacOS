//
//  DependenciesMacOSApp.swift
//  DependenciesMacOS
//
//  Created by Kushagra Sharma on 23/04/26.
//

import SwiftUI

@main
struct DependenciesMacOSApp: App {
    var body: some Scene {
        WindowGroup {
                   AppRootView()
                       .frame(minWidth: 900, minHeight: 600)
               }
               .windowStyle(.titleBar)
               .windowToolbarStyle(.unified(showsTitle: true))
               .commands {
                   CommandGroup(replacing: .newItem) {
                       Button("Open Binary…") {
                           NotificationCenter.default.post(name: .openFilePicker, object: nil)
                       }
                       .keyboardShortcut("o")
                   }
               }
    }
}

extension Notification.Name {
    static let openFilePicker = Notification.Name("openFilePicker")
}
