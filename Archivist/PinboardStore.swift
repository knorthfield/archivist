import Foundation
import Observation

enum PinboardColour: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink, grey
}

/// A named list of items that stay in the history.
struct Pinboard: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var colour: PinboardColour
    var itemIDs: [UUID] = []
}

/// The pinboards, in `pinboards.json`.
@MainActor
@Observable
final class PinboardStore {
    private(set) var pinboards: [Pinboard] = []

    @ObservationIgnored private let file: URL

    init(root: URL = ItemStore.defaultRoot) {
        file = root.appending(path: "pinboards.json")
        if let data = try? Data(contentsOf: file) {
            pinboards = (try? JSONDecoder().decode([Pinboard].self, from: data)) ?? []
        }
    }

    var pinnedIDs: Set<UUID> {
        Set(pinboards.flatMap(\.itemIDs))
    }

    func pinboard(_ id: UUID) -> Pinboard? {
        pinboards.first { $0.id == id }
    }

    func pinboard(with itemID: UUID) -> Pinboard? {
        pinboards.first { $0.itemIDs.contains(itemID) }
    }

    @discardableResult
    func add(name: String, colour: PinboardColour) -> Pinboard {
        let pinboard = Pinboard(name: name, colour: colour)
        pinboards.append(pinboard)
        save()
        return pinboard
    }

    func update(_ id: UUID, name: String, colour: PinboardColour) {
        guard let index = pinboards.firstIndex(where: { $0.id == id }) else { return }
        pinboards[index].name = name
        pinboards[index].colour = colour
        save()
    }

    func delete(_ id: UUID) {
        pinboards.removeAll { $0.id == id }
        save()
    }

    /// Moves a pinboard to the position of a different pinboard.
    func move(_ id: UUID, toPositionOf otherID: UUID) {
        guard let from = pinboards.firstIndex(where: { $0.id == id }),
              let to = pinboards.firstIndex(where: { $0.id == otherID }) else { return }
        pinboards.insert(pinboards.remove(at: from), at: to)
        save()
    }

    /// An item is in one pinboard at a time: this removes the items from all other pinboards.
    func pin(_ itemIDs: [UUID], to id: UUID) {
        guard let index = pinboards.firstIndex(where: { $0.id == id }) else { return }
        let new = itemIDs.filter { !pinboards[index].itemIDs.contains($0) }
        removeItems(Set(new))
        pinboards[index].itemIDs.append(contentsOf: new)
        save()
    }

    func unpin(_ itemIDs: Set<UUID>) {
        removeItems(itemIDs)
        save()
    }

    /// Moves an item to the position of a different item in the same pinboard.
    func moveItem(_ itemID: UUID, toPositionOf otherID: UUID) {
        guard let index = pinboards.firstIndex(where: { $0.itemIDs.contains(itemID) && $0.itemIDs.contains(otherID) }),
              let from = pinboards[index].itemIDs.firstIndex(of: itemID),
              let to = pinboards[index].itemIDs.firstIndex(of: otherID) else { return }
        pinboards[index].itemIDs.insert(pinboards[index].itemIDs.remove(at: from), at: to)
        save()
    }

    private func removeItems(_ itemIDs: Set<UUID>) {
        for index in pinboards.indices {
            pinboards[index].itemIDs.removeAll { itemIDs.contains($0) }
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(pinboards) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }
}
