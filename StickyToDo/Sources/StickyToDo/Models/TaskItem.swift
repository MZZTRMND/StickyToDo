import Foundation

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    var isImportant: Bool
    var categoryID: UUID?
    var doneAt: Date?
    let createdAt: Date
    var attachmentID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        isImportant: Bool = false,
        categoryID: UUID? = nil,
        doneAt: Date? = nil,
        createdAt: Date = Date(),
        attachmentID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.isImportant = isImportant
        self.categoryID = categoryID
        self.doneAt = doneAt
        self.createdAt = createdAt
        self.attachmentID = attachmentID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isDone
        case isImportant
        case categoryID
        case doneAt
        case createdAt
        case attachmentID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        isImportant = try container.decodeIfPresent(Bool.self, forKey: .isImportant) ?? false
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        doneAt = try container.decodeIfPresent(Date.self, forKey: .doneAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        attachmentID = try container.decodeIfPresent(UUID.self, forKey: .attachmentID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(isDone, forKey: .isDone)
        try container.encode(isImportant, forKey: .isImportant)
        try container.encodeIfPresent(categoryID, forKey: .categoryID)
        try container.encodeIfPresent(doneAt, forKey: .doneAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(attachmentID, forKey: .attachmentID)
    }
}
