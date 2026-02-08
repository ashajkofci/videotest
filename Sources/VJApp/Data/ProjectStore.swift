import Foundation

enum ProjectStoreError: Error {
    case invalidURL
    case decodeFailed
    case encodeFailed
}

final class ProjectStore {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var autosaveTimer: Timer?

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func load(from url: URL) throws -> Project {
        let data = try Data(contentsOf: url)
        let project = try decoder.decode(Project.self, from: data)
        return project
    }

    func save(_ project: Project, to url: URL) throws {
        let data = try encoder.encode(project)
        try data.write(to: url, options: [.atomic])
    }

    func startAutosave(project: @escaping () -> Project, to url: URL, interval: TimeInterval = 10.0) {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            do {
                try self.save(project(), to: url)
            } catch {
                NSLog("Autosave failed: \(error)")
            }
        }
    }

    func stopAutosave() {
        autosaveTimer?.invalidate()
        autosaveTimer = nil
    }

    func relink(media item: MediaItem, newURL: URL) -> MediaItem {
        var updated = item
        updated.resolvedPath = newURL.path
        return updated
    }

    func collectMedia(for project: Project, into folderURL: URL) throws -> Project {
        var updatedProject = project
        for index in updatedProject.media.indices {
            let item = updatedProject.media[index]
            let sourcePath = item.resolvedPath ?? item.path
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let targetURL = folderURL.appendingPathComponent(sourceURL.lastPathComponent)
            if fileManager.fileExists(atPath: sourceURL.path) {
                _ = try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
                if !fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.copyItem(at: sourceURL, to: targetURL)
                }
                updatedProject.media[index].resolvedPath = targetURL.path
            }
        }
        return updatedProject
    }
}
