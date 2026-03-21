import Foundation

enum LabKind: String, CaseIterable, Identifiable {
    case hemoglobin = "Hemoglobin"
    case hematocrit = "Hematocrit"
    case rbc = "RBC"
    case wbc = "WBC"
    case platelets = "Platelets"
    case crp = "CRP"
    case creatinine = "Creatinine"
    case custom = "Custom"

    var id: String { rawValue }

    var suggestedUnit: String {
        switch self {
        case .hemoglobin:
            "g/dL"
        case .hematocrit:
            "%"
        case .rbc:
            "10^6/uL"
        case .wbc:
            "10^3/uL"
        case .platelets:
            "10^3/uL"
        case .crp:
            "mg/L"
        case .creatinine:
            "mg/dL"
        case .custom:
            ""
        }
    }
}
