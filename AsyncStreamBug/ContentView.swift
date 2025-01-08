//
//  ContentView.swift
//  AsyncStreamBug
//
//  Created by Cory Tripathy on 12/17/24.
//

import SwiftUI
import AVFoundation
import Combine

class Thing: ObservableObject {
    let actorThing = ActorThing()
    @Published var num = 0
    func changeNumber() {
        num += 1
    }
    func run() {
        Task {
            await actorThing.run()
        }
    }
    init() {
        Task {
            await actorThing.setClosure(to: changeNumber)
        }
    }
}

class CustomTimer {
    lazy var timer = Timer.publish(every: 0.5, on: .current, in: .common)
        .autoconnect()
        .sink { _ in
            DispatchQueue.global().async {
                self.callback()
            }
        }
    var callback: (() -> Void) = { }
    init() {
        _ = timer
    }
}

actor ActorThing {
    var closure: (@MainActor () -> Void)?
    func setClosure(to closure: (@MainActor () -> Void)? = nil) {
        self.closure = closure
    }
    var stream: AsyncStream<Void>?
    let customTimer = CustomTimer()
    func run() {
        var stream: AsyncStream<Void> {
            AsyncStream { continuation in
                customTimer.callback = {
                    Task {
                        let closure = self.closure
                        /// this has an erroneous compiler error
//                        await closure?()
                        /// if you call it like this, it will run on a concurrent thread
                        self.closure?()
                        continuation.yield()
                    }
                }
            }
        }
        self.stream = stream
        Task {
            guard let stream = self.stream else { return }
            for await _ in stream {
                await self.closure?()
            }
        }
    }
}

struct ContentView: View {
    @StateObject var thing = Thing()
    var body: some View {
        Button("current num: \(thing.num)") {
            thing.run()
        }
    }
}


#Preview {
    ContentView()
}
