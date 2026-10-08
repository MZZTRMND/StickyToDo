import Foundation

struct TaskCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorHex: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}
