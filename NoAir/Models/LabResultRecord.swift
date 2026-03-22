import Foundation
import SwiftData

@Model
final class LabResultRecord {
    var id: UUID
    var labName: String
    var value: Double
    var unit: String
    var referenceRange: String?
    var timestamp: Date
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        labName: String,
        value: Double,
        unit: String,
        referenceRange: String? = nil,
        timestamp: Date,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.labName = labName
        self.value = value
        self.unit = unit
        self.referenceRange = referenceRange
        self.timestamp = timestamp
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
