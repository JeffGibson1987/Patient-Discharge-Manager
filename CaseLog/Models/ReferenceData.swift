import Foundation

/// Pick lists copied from the "Dropdowns" sheet of
/// "Patient discharge list - Tristar CV Surgery - version 1.1.xlsm".
enum ReferenceData {
    static let surgeons = ["Gibson", "Nguyen", "Reddy", "Subramanian", "Todd"]

    static let procedures = [
        "CABG",
        "AV replacement",
        "MV replacement",
        "MV repair",
        "Aortic root",
        "Ascending aorta",
        "AV repair",
        "Afib procedure",
        "Septal myectomy",
        "ASD repair",
        "TV repair",
        "TV replacement",
        "Aortic arch procedure",
        "PV replacement",
        "Descending thoracic aorta",
        "Cardiac tumor resection",
        "Anomalous coronary artery",
        "Ventricular septal rupture repair",
        "LV aneurysm repair",
        "Surgery for pulmonary embolism",
        "Mechanical support surgery",
    ]

    struct EventCategory: Identifiable, Hashable {
        let name: String
        let subcategories: [String]
        var id: String { name }
    }

    /// In-hospital post-op events, in the spreadsheet's order.
    static let eventCategories: [EventCategory] = [
        EventCategory(name: "Atrial fibrillation", subcategories: []),
        EventCategory(name: "Surgical site complication", subcategories: [
            "Infectious superficial sternal wound",
            "Infectious deep sternal",
            "Infectious thoracotomy",
            "Infectious conduit harvest site",
            "Infectious cannulation site",
            "Non-infective superficial sternal wound",
            "Non-infective deep sternal",
        ]),
        EventCategory(name: "Operative", subcategories: [
            "ReOp for bleeding/tamponade",
            "ReOp for valvular dysfunction",
            "Unplanned coronary intervention",
            "Aortic reintervention",
            "ReOp for other cardiac reason",
            "Return to OR for other non-cardiac reason",
            "Open chest with planned delayed sternal closure",
        ]),
        EventCategory(name: "Infection", subcategories: ["Sepsis"]),
        EventCategory(name: "Neurologic, central", subcategories: [
            "Postoperative stroke",
            "Encephalopathy",
        ]),
        EventCategory(name: "Neurologic, peripheral", subcategories: [
            "Lower extremity paralysis > 24 hours",
            "Paresis > 24 hours",
            "Recurrent laryngeal nerve injury",
        ]),
        EventCategory(name: "Pulmonary", subcategories: [
            "Prolonged ventilation",
            "Pneumonia",
            "Pulmonary thromboembolism",
            "Pleural effusion requiring drainage",
            "Pneumothorax requiring intervention",
        ]),
        EventCategory(name: "Renal", subcategories: [
            "Renal failure",
            "Dialysis (newly required)",
            "Dialysis (required after hospital)",
        ]),
        EventCategory(name: "Vascular", subcategories: [
            "Iliac/femoral dissection",
            "Acute limb ischemia",
            "Deep venous thrombosis",
        ]),
        EventCategory(name: "Mechanical assist device complication", subcategories: [
            "Cannula insertion site issue",
            "Hemorrhagic",
            "Thrombotic/embolic",
            "Hemolytic",
            "Infection",
            "Other",
        ]),
        EventCategory(name: "Other", subcategories: [
            "Rhythm disturbance requiring pacemaker",
            "Cardiac arrest",
        ]),
        EventCategory(name: "Aortic complication", subcategories: [
            "Aortic dissection",
            "PostOp aortic endoleak",
            "Aortic side branch malperfusion",
            "Aortic stent graft-induced entry tear",
        ]),
        EventCategory(name: "Anticoagulant bleeding event", subcategories: [
            "Intracerebral",
            "Subdural",
            "Gastrointestinal",
        ]),
        EventCategory(name: "HIT (heparin-induced thrombocytopenia)", subcategories: []),
        EventCategory(name: "HITT (HIT with thrombosis)", subcategories: []),
        EventCategory(name: "Pericardiocentesis", subcategories: []),
        EventCategory(name: "Gastrointestinal event", subcategories: [
            "Ischemic bowel",
            "Gastrointestinal bleed",
            "Pancreatitis",
            "Cholecystitis",
            "Liver dysfunction/liver failure",
            "Ileus",
            "Other",
        ]),
    ]

    static func subcategories(for category: String) -> [String] {
        eventCategories.first { $0.name == category }?.subcategories ?? []
    }
}
