//
//  MainView.swift
//  wallabag
//
//  Created by Marinel Maxime on 18/07/2019.
//

import SwiftUI
import WallabagKit
import Combine

class WallaSession: ObservableObject {
    enum State {
        case unknown
        case connected
    }
    let willChange = PassthroughSubject<Void, Never>()
    
    @Published var state: State = .unknown
    var session: WallabagKit?
    
    func requestSession() {
        let kit = WallabagKit(
                    host: WallabagUserDefaults.host,
                    clientID: WallabagUserDefaults.clientId,
                    clientSecret: WallabagUserDefaults.clientSecret
                )
                kit.requestAuth(
                    username: WallabagUserDefaults.login,
                    password: WallabagUserDefaults.password
                ) { auth in
                    switch auth {
                    case .success(_):
                        self.state = .connected
                    @unknown default:
                        self.state = .unknown
                    }
        }
    }
}

class AppSync: ObservableObject {
    let willChange = PassthroughSubject<Void, Never>()
    
    let session: WallaSession
    
    init() {
        self.session = WallaSession()
    }
    
    var inProgress = false
    
    func requestSync() {
        inProgress = true
        _ = session.$state.sink { state in
            if(state == .connected){
                self.sync()
            }
        }
        session.requestSession()
    }
    
    private func sync() {
        
    }
}

struct MainView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        let appSync = AppSync()
        return ViewBuilder.buildBlock(
            appState.registred ?
            ViewBuilder.buildEither(second: ArticleListView().environmentObject(appSync)) :
            ViewBuilder.buildEither(first: RegistrationView().environmentObject(appState))
        )
    }
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        Text("nothing")
    }
}
#endif
