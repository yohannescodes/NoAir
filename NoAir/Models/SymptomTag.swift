import Foundation

enum SymptomTag: String, CaseIterable, Identifiable {
    case breathlessness = "Breathlessness"
    case chestTightness = "Chest Tightness"
    case dizziness = "Dizziness"
    case headache = "Headache"
    case fatigue = "Fatigue"
    case cough = "Cough"
    case palpitations = "Palpitations"

    var id: String { rawValue }
}
