//
//  ContentView.swift
//  MixStorage
//
//  Created by Eric Long on 2022/9/27.
//

import SwiftUI

struct User: Codable {
    var id: Int
    var name: String

    static func random() -> Self {
        let id = Int.random(in: 1..<100)
        return User(id: id, name: "user_\(id)")
    }
}

struct ContentView: View {

    @Storable(wrappedValue: nil, key: .init("user_storage"), mode: .keychain)
    var user: User?

    @State var auser: User?

    init() {
        _auser = .init(wrappedValue: self.user)
    }

    var body: some View {
        VStack {
            Text("user: \(auser?.name ?? "")")
            Button {
                user = User.random()
                auser = user
            } label: {
                Text("Reset User")
            }
            .padding(.top, 20)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
