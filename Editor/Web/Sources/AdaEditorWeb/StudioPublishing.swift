import AdaStudioCore
import Foundation

extension StudioViewModel {
    /// A click publishes one captured source version; the agent has no access to this operation.
    func publish() async {
        guard publishingEnabled else { return }
        guard !isAgentRunning else { error = "Остановите агента перед публикацией."; return }
        guard let workspace, let snapshot = document?.snapshot else { return }
        do {
            let billing = try StudioValue.decode(await browser.request(path: "/v1/billing"))
            guard billing["pro"] == .bool(true) else { throw StudioError.unavailable("Для публикации нужна подписка Cloud Pro. Сохранять и скачивать проект можно без неё.") }
            publicationStatus = "Подготовка версии…"
            try snapshot.validate()
            let diagnostics = validateSources()
            guard diagnostics.isEmpty else { throw StudioError.invalid(diagnostics) }
            tab = .game; browser.editMode = false; isRunning = true; try await browser.load(snapshot)
            let cover = try await browser.capture()
            let media = try StudioValue.decode(await browser.perform("media.upload", .object(["image": .string(cover)])))
            let pageData: StudioValue = .object(["title": .string(String(snapshot.title.prefix(100))),
                "description": .string(snapshot.title + ". Создано в Ada Studio."), "cover": media["id"], "screenshots": .array([]), "tags": .array([.string("Ada Studio")])])
            let pageID: String
            if let existing = workspace.pageID {
                _ = try await browser.request(path: "/v1/pages/" + existing, method: "PATCH", body: pageData.encoded()); pageID = existing
            } else {
                let page = try StudioValue.decode(await browser.request(path: "/v1/pages", method: "POST", body: pageData.encoded()))
                guard let id = page["id"].string else { throw StudioError.invalid("Не удалось создать страницу игры.") }
                let linked = try StudioValue.decode(await browser.request(path: "/v1/workspaces/\(workspace.id)/publication-page", method: "POST", body: StudioValue.object(["pageID": .string(id)]).encoded()))
                guard let linkedID = linked["pageID"].string else { throw StudioError.invalid("Не удалось связать страницу игры.") }
                pageID = linkedID; self.workspace?.pageID = linkedID
            }
            var files = try snapshot.exportFiles()
            files.append(.init(path: "ada-game.json", data: try StudioValue.object(["formatVersion": .int(1), "runtime": .string("adascript"), "apiVersion": .int(StudioRuntimeCapabilities.communityPackageAPI)]).encoded()))
            let archive = try StudioArchive.encode(files)
            let digest = try StudioValue.decode(await browser.perform("digest", .string(archive.base64EncodedString())))
            let input: StudioValue = .object(["operationId": .string("studio:" + digest.text), "bytes": .int(archive.count), "mode": .string("ugc"), "pageId": .string(pageID)])
            var upload = try StudioValue.decode(await browser.request(path: "/v1/uploads", method: "POST", body: input.encoded()))
            guard let uploadID = upload["id"].string else { throw StudioError.invalid("Нет ID загрузки.") }
            if upload["status"].string == "created" {
                guard let url = upload["uploadURL"].string else { throw StudioError.invalid("Нет адреса загрузки.") }
                _ = try await browser.perform("upload", .object(["url": .string(url), "data": .string(archive.base64EncodedString())]))
                _ = try await browser.request(path: "/v1/uploads/\(uploadID)/complete", method: "POST", body: Data("{}".utf8))
            }
            for _ in 0..<120 {
                upload = try StudioValue.decode(await browser.request(path: "/v1/uploads/" + uploadID))
                if ["ready", "published", "submitted"].contains(upload["status"].string ?? "") { break }
                guard !["failed", "deleted"].contains(upload["status"].string ?? "") else { throw StudioError.invalid(upload["error"].string ?? "Проверка проекта не пройдена.") }
                publicationStatus = "Проверка версии…"
                try await Task.sleep(for: .seconds(1))
            }
            guard ["ready", "published", "submitted"].contains(upload["status"].string ?? "") else { throw StudioError.unavailable("Версия ещё обрабатывается. Повторите публикацию позже.") }
            let release = try StudioValue.decode(await browser.request(path: "/v1/uploads/\(uploadID)/publish", method: "POST", body: Data("{}".utf8)))
            publicationStatus = release["status"].string == "approved" ? "Игра опубликована" : "Версия отправлена на модерацию"
            await save(checkpoint: true)
        } catch { self.error = error.localizedDescription; publicationStatus = nil }
    }
}
