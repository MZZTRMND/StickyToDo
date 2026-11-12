import Foundation

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    var isImportant: Bool
    var categoryID: UUID?
    var doneAt: Date?
    let createdAt: Date
    /// The task's images, oldest first (see AttachmentStore), at most
    /// `maxAttachments`.
    var attachmentIDs: [UUID]

    static let maxAttachments = 4

    var hasAttachments: Bool { attachmentIDs.isEmpty == false }
    var canAddAttachment: Bool { attachmentIDs.count < Self.maxAttachments }

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        isImportant: Bool = false,
        categoryID: UUID? = nil,
        doneAt: Date? = nil,
        createdAt: Date = Date(),
        attachmentIDs: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.isImportant = isImportant
        self.categoryID = categoryID
        self.doneAt = doneAt
        self.createdAt = createdAt
        self.attachmentIDs = attachmentIDs
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isDone
        case isImportant
        case categoryID
        case doneAt
        case createdAt
        case attachmentIDs
        /// The single image of older versions. Still written (as the first
        /// image), so an older build keeps showing at least that one.
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
        if let ids = try container.decodeIfPresent([UUID].self, forKey: .attachmentIDs) {
            attachmentIDs = ids
        } else if let legacyID = try container.decodeIfPresent(UUID.self, forKey: .attachmentID) {
            attachmentIDs = [legacyID]
        } else {
            attachmentIDs = []
        }
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
        if attachmentIDs.isEmpty == false {
            try container.encode(attachmentIDs, forKey: .attachmentIDs)
        }
        try container.encodeIfPresent(attachmentIDs.first, forKey: .attachmentID)
    }
}
