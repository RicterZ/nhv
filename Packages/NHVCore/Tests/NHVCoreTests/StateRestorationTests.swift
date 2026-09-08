import Foundation
import Testing
@testable import NHVCore

@MainActor private func isolatedDefaults() -> UserDefaults {
    UserDefaults(suiteName: "StateRestorationTests.\(UUID().uuidString)")!
}

@MainActor private func savedSession(_ defaults: UserDefaults, _ credentials: MemoryCredentials,
                                    _ transport: any HTTPTransport) -> SessionStore {
    SessionStore(credentials: credentials, defaults: defaults) { key in
        NHentaiAPI(client: APIClient(key: key, transport: transport))
    }
}

@Test @MainActor func cachedSessionAppearsBeforeNetworkAndKeepsIdentity() async throws {
    let defaults = isolatedDefaults()
    let credentials = MemoryCredentials()
    let original = savedSession(defaults, credentials, StubTransport(minimalUser))
    await original.restore()
    await original.signIn(key: "test-key")
    let transport = SuspendedTransport()
    let reopened = savedSession(defaults, credentials, transport)
    guard case .authenticated(let before) = reopened.phase else { Issue.record("Must restore synchronously"); return }
    #expect(reopened.restoredFromCache)
    #expect(before.user.id == 1)
    let task = Task { await reopened.restore() }
    await transport.waitUntilStarted()
    guard case .authenticated = reopened.phase else { Issue.record("Validation hid restored UI"); return }
    await transport.resume()
    await task.value
    guard case .authenticated(let after) = reopened.phase else { Issue.record("Lost session"); return }
    #expect(before.id == after.id)
    let data = try #require(defaults.data(forKey: "session.savedAccount"))
    #expect(!String(decoding: data, as: UTF8.self).contains("test-key"))
}

@Test @MainActor func cachedSessionSurvivesOfflineAndRejectsExpiredKey() async throws {
    let defaults = isolatedDefaults()
    let credentials = MemoryCredentials(try APIKey("test-key"))
    await savedSession(defaults, credentials, StubTransport(minimalUser)).restore()
    let offline = savedSession(defaults, credentials, StubTransport("", status: 503))
    await offline.restore()
    guard case .authenticated = offline.phase else { Issue.record("Offline must keep cached UI"); return }
    #expect(credentials.key != nil)
    let expired = savedSession(defaults, credentials, StubTransport("", status: 401))
    await expired.restore()
    guard case .signedOut = expired.phase else { Issue.record("Invalid key must show login"); return }
    #expect(defaults.data(forKey: "session.savedAccount") == nil)
    #expect(credentials.key == nil)
}

@Test @MainActor func unrelatedKeyCannotRestoreCachedAccount() async throws {
    let defaults = isolatedDefaults()
    let credentials = MemoryCredentials(try APIKey("test-key"))
    await savedSession(defaults, credentials, StubTransport(minimalUser)).restore()
    credentials.key = try APIKey("different-key")
    let changed = savedSession(defaults, credentials, StubTransport(minimalUser))
    #expect(!changed.restoredFromCache)
    guard case .restoring = changed.phase else { Issue.record("Cached account leaked to another key"); return }
}

@Test @MainActor func anyAuthenticatedRequestCanInvalidateRestoredSession() async throws {
    let defaults = isolatedDefaults()
    let credentials = MemoryCredentials(try APIKey("test-key"))
    await savedSession(defaults, credentials, StubTransport(minimalUser)).restore()
    let reopened = savedSession(defaults, credentials, StubTransport("", status: 401))
    guard case .authenticated(let account) = reopened.phase else { Issue.record("Missing cached session"); return }
    _ = try? await account.api.search(query: "test")
    for _ in 0..<100 {
        if case .signedOut = reopened.phase { break }
        await Task.yield()
    }
    guard case .signedOut = reopened.phase else { Issue.record("401 did not invalidate session"); return }
    #expect(credentials.key == nil)
}

@Test @MainActor func signOutDuringCachedValidationCannotRestoreAccount() async throws {
    let defaults = isolatedDefaults()
    let credentials = MemoryCredentials(try APIKey("test-key"))
    await savedSession(defaults, credentials, StubTransport(minimalUser)).restore()
    let transport = SuspendedTransport()
    let reopened = savedSession(defaults, credentials, transport)
    let validation = Task { await reopened.validate() }
    await transport.waitUntilStarted()
    reopened.signOut()
    await transport.resume()
    await validation.value
    guard case .signedOut = reopened.phase else { Issue.record("Late validation restored signed-out account"); return }
    #expect(defaults.data(forKey: "session.savedAccount") == nil)
}

@Test @MainActor func navigationRestoresNestedSearchAndBackPathWithoutNewVisits() throws {
    let defaults = isolatedDefaults()
    let navigation = AppNavigation(accountID: 1, defaults: defaults)
    navigation.selectedTab = .search
    navigation.saveSearch(.init(terms: ["keyword A"], input: "draft", sort: .week), key: "root")
    navigation.openGallery(id: 42)
    let tag = AppNavigation.Route(.search("tag:\"B\""))
    navigation.push(tag)
    navigation.saveSearch(.init(terms: ["tag:\"B\"", "language:chinese"], sort: .popular), key: tag.id.uuidString)
    navigation.openGallery(id: 99)
    let restored = AppNavigation(accountID: 1, defaults: defaults)
    #expect(restored.selectedTab == .search)
    #expect(restored.path(for: .search).map(\.kind) == [.gallery(42), .search("tag:\"B\""), .gallery(99)])
    #expect(restored.path(for: .search).allSatisfy { !$0.recordsVisit })
    #expect(restored.searchState("root").sort == .week)
    #expect(restored.searchState("root").input == "draft")
    #expect(restored.searchState(tag.id.uuidString).terms == ["tag:\"B\"", "language:chinese"])
    restored.setPath(Array(restored.path(for: .search).dropLast()), for: .search)
    #expect(AppNavigation(accountID: 1, defaults: defaults).path(for: .search).last?.kind == tag.kind)
    #expect(AppNavigation(accountID: 2, defaults: defaults).path(for: .search).isEmpty)
}

@Test @MainActor func readerRestoresPageAndDismissalClearsSavedReader() throws {
    let defaults = isolatedDefaults()
    let navigation = AppNavigation(accountID: 1, defaults: defaults)
    let pages = try JSONDecoder().decode([GalleryPage].self, from: Data(#"[{"number":1,"path":"/1.webp","width":20,"height":30,"thumbnail":"/1t.webp","thumbnailWidth":2,"thumbnailHeight":3},{"number":2,"path":"/2.webp","width":20,"height":30,"thumbnail":"/2t.webp","thumbnailWidth":2,"thumbnailHeight":3}]"#.utf8))
    navigation.openGallery(id: 42)
    navigation.reader = .init(galleryID: 42, pages: pages, initialIndex: 0)
    navigation.updateReaderPage(1)
    let restored = AppNavigation(accountID: 1, defaults: defaults)
    #expect(restored.reader?.galleryID == 42)
    #expect(restored.reader?.initialIndex == 1)
    #expect(restored.isReading)
    restored.reader = nil
    let closed = AppNavigation(accountID: 1, defaults: defaults)
    #expect(closed.reader == nil)
    #expect(closed.path(for: .home).last?.kind == .gallery(42))
}

@Test @MainActor func historyAndFavoriteFiltersRestoreAndCorruptionFallsBack() {
    let defaults = isolatedDefaults()
    let navigation = AppNavigation(accountID: 1, defaults: defaults)
    navigation.selectedTab = .settings
    navigation.push(.init(.history))
    navigation.historyQuery = "title"
    navigation.favoritesInput = "draft"
    navigation.favoritesQuery = "artist:test"
    let restored = AppNavigation(accountID: 1, defaults: defaults)
    #expect(restored.historyQuery == "title")
    #expect(restored.favoritesInput == "draft")
    #expect(restored.favoritesQuery == "artist:test")
    #expect(restored.path(for: .settings).last?.kind == .history)
    defaults.set(Data("broken".utf8), forKey: "navigation.account.1")
    #expect(AppNavigation(accountID: 1, defaults: defaults).selectedTab == .home)
}
