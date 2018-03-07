//
//  ArticleSync.swift
//  wallabag
//
//  Created by maxime marinel on 07/05/2017.
//  Copyright © 2017 maxime marinel. All rights reserved.
//

import Foundation
import WallabagKit
import CoreData
import RealmSwift

final class ArticleSync {
    enum State {
        case finished, running, error
    }
    private let syncQueue = DispatchQueue(label: "fr.district-web.wallabag.articleSyncQueue", qos: .background)
    private var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .background
        return queue
    }()
    private let group = DispatchGroup()

    let realm = try! Realm()

    static let sharedInstance: ArticleSync = ArticleSync()

    var wallabagApi: WallabagApi?
    var state: State = .finished
    var pageCompleted: Int = 1
    var maxPage: Int = 1

    var entriesSynced: [Int] = []

    private init() {}

    func initSession() {
        wallabagApi = WallabagApi(
            host: Setting.getHost()!,
            username: Setting.getUsername()!,
            password: Setting.getPassword(username: Setting.getUsername()!)!,
            clientId: Setting.getClientId()!,
            clientSecret: Setting.getClientSecret()!
        )
    }

    func sync(completion: @escaping (State) -> Void) {
        if state == .running {
            return
        }
        state = .running

        group.enter()

        wallabagApi?.entry(parameters: ["page": 1]) { result in
            switch result {
            case .success(let collection):
                self.handle(result: collection.items)
                self.maxPage = collection.last
                completion(.running)

                for page in 2...collection.last {
                    self.group.enter()

                    let syncOperation = SyncOperation(articleSync: self, page: page)
                    syncOperation.completionBlock = {
                        self.pageCompleted += 1
                        completion(.running)
                        self.group.leave()
                    }
                    self.operationQueue.addOperation(syncOperation)
                }
            case .error(let error):
                if error == .invalidAuth {
                    completion(.error)
                }
            }
            self.group.leave()
        }

        group.notify(queue: syncQueue) {
            self.state = .finished
            self.pageCompleted = 1
            completion(.finished)
            if 0 != self.entriesSynced.count {
                self.purge()
            }
        }
    }

    func handle(result: [WallabagEntry]) {
        DispatchQueue.global(qos: .background).async {
            let realm = try! Realm()

            realm.beginWrite()
            for wallabagEntry in result {
                self.entriesSynced.append(wallabagEntry.id)
                if let entry = realm.object(ofType: Entry.self, forPrimaryKey: wallabagEntry.id) {
                    self.update(entry: entry, from: wallabagEntry)
                } else {
                    self.insert(wallabagEntry, realm)
                }
            }
            try? realm.commitWrite()
        }
    }

    private func purge() {
        let realmPurge = try! Realm()
        try! realmPurge.write {
            let entries = realmPurge.objects(Entry.self).filter("NOT (id IN %@)", entriesSynced)
            realmPurge.delete(entries)
        }
    }

    func insert(_ wallabagEntry: WallabagEntry, _ realm: Realm) {
        let entry = Entry()
        NSLog("Insert article \(wallabagEntry.id)")
        entry.hydrate(from: wallabagEntry)
        realm.add(entry)
        spotLightIndex(entry)
    }

    private func update(entry: Entry, from article: WallabagEntry) {
        if entry.updatedAtDate != article.updatedAt {
            NSLog("Update article \(article.id)")
            if article.updatedAt > entry.updatedAtDate {
                NSLog("Update entry from server \(article.id)")
                entry.hydrate(from: article)
            } else {
                NSLog("Update article from entry \(article.id)")
                update(entry: entry)
            }
        }
    }

    /**
     * Push data to server
     */
    func update(entry: Entry) {
        let entryRef = ThreadSafeReference(to: entry)
        wallabagApi?.entry(update: Int(entry.id), parameters: [
            "archive": (entry.isArchived).hashValue,
            "starred": (entry.isStarred).hashValue
            ]
        ) { results in
            switch results {
            case .success(let wallabagEntry):
                let realm = try! Realm()
                let entry = realm.resolve(entryRef)!
                try? realm.write {
                    entry.setValue(wallabagEntry.updatedAt, forKey: "updatedAt")
                }
                break
            case .error: break
            }
        }
    }

    func delete(entry: Entry, callServer: Bool = true) {
        NSLog("Delete entry \(entry.id)")
        if callServer {
            wallabagApi?.entry(delete: Int(entry.id)) { _ in
            }
        }
        try! realm.write {
            spotLightDelete(entry)
            realm.delete(entry)
        }
    }

    func add(url: URL) {
        wallabagApi?.entry(add: url) { result in
            switch result {
            case .success(let wallabagEntry):
                try! self.realm.write {
                    self.insert(wallabagEntry, self.realm)
                }
            case .error:
                break
            }
        }
    }
}
