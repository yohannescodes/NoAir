import Foundation
import SwiftData

@Model
final class TreatmentEvent {
    var id: UUID
    var timestamp: Date
    var typeRawValue: String
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        timestamp: Date,
        type: TreatmentType,
        note: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.timestamp = timestamp
        self.typeRawValue = type.rawValue
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: TreatmentType {
        get { TreatmentType(rawValue: typeRawValue) ?? .custom }
        set { typeRawValue = newValue.rawValue }
    }
}
