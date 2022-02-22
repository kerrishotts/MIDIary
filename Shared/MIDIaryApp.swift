//
//  MIDIaryApp.swift
//  Shared
//
//  Created by Kerri Shotts on 2/21/22.
//

import SwiftUI

@main
struct MIDIaryApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
