import Foundation

enum MedicalSpecialty: String, CaseIterable, Identifiable, Codable {
    case obgyn = "OB/GYN"
    case familyMedicine = "Family Medicine"
    case internalMedicine = "Internal Medicine"
    case pediatrics = "Pediatrics"
    case emergencyMedicine = "Emergency Medicine"
    case cardiology = "Cardiology"
    case orthopedics = "Orthopedics"
    case psychiatry = "Psychiatry"
    case neurology = "Neurology"
    case generalSurgery = "General Surgery"
    case urology = "Urology"
    case pulmonology = "Pulmonology"
    case gastroenterology = "Gastroenterology"
    case nephrology = "Nephrology"
    case oncology = "Oncology"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .obgyn: return "figure.and.child.holdinghands"
        case .familyMedicine: return "house.and.flag"
        case .internalMedicine: return "stethoscope"
        case .pediatrics: return "figure.and.child.holdinghands"
        case .emergencyMedicine: return "cross.case"
        case .cardiology: return "heart"
        case .orthopedics: return "figure.walk"
        case .psychiatry: return "brain.head.profile"
        case .neurology: return "brain"
        case .generalSurgery: return "scissors"
        case .urology: return "drop"
        case .pulmonology: return "lungs"
        case .gastroenterology: return "stomach"
        case .nephrology: return "kidney"
        case .oncology: return "cross.vial"
        case .other: return "stethoscope"
        }
    }
}

// MARK: - Field Visibility

extension MedicalSpecialty {
    /// Whether to show the OB Status field
    var showsOBStatus: Bool {
        self == .obgyn
    }

    /// Whether to show pediatric age/weight fields
    var showsPediatricFields: Bool {
        self == .pediatrics
    }

    /// Whether to show safety concerns field (psychiatry)
    var showsSafetyConcerns: Bool {
        self == .psychiatry
    }

    /// Custom field label for chief complaint
    var chiefComplaintLabel: String {
        switch self {
        case .psychiatry: return "Presenting Concern"
        case .orthopedics: return "Injury / Complaint"
        default: return "Chief Complaint"
        }
    }
}

// MARK: - Disposition Options

extension MedicalSpecialty {
    var dispositionOptions: [String] {
        var common = [
            "Advised home care",
            "Scheduled office visit",
            "Called in Rx",
            "Referred to specialist",
            "Sent to ER"
        ]

        switch self {
        case .obgyn:
            common.insert("Sent to L&D", at: 4)
            common.append("Sent to ultrasound")
        case .pediatrics:
            common[4] = "Sent to Children's ER"
            common.append("Advised urgent care")
        case .cardiology:
            common.append("Sent to cath lab")
            common.append("Direct admit to CCU")
        case .psychiatry:
            common.append("Crisis intervention")
            common.append("Sent to psychiatric ER")
            common.append("Scheduled urgent eval")
        case .orthopedics:
            common.append("Sent to ortho urgent care")
            common.append("Surgical consult scheduled")
        case .emergencyMedicine:
            common = ["Managed in ED", "Admitted", "Discharged", "Transferred", "Left AMA"]
        case .neurology:
            common.append("Sent for stat imaging")
            common.append("Direct admit for stroke eval")
        case .pulmonology:
            common.append("Sent for chest imaging")
            common.append("Direct admit for respiratory failure")
        case .gastroenterology:
            common.append("Scheduled urgent endoscopy")
            common.append("Direct admit for GI bleed")
        case .generalSurgery:
            common.append("Surgical consult scheduled")
            common.append("Direct to OR")
        default:
            break
        }

        common.append("Other")
        return common
    }
}

// MARK: - Suggested Tags

extension MedicalSpecialty {
    var suggestedTags: [String] {
        switch self {
        case .obgyn:
            return ["postpartum", "labor", "bleeding", "pregnancy", "contraception",
                    "infection", "pain", "breast", "newborn"]
        case .pediatrics:
            return ["fever", "respiratory", "GI", "rash", "injury", "newborn",
                    "behavioral", "feeding", "vaccination"]
        case .cardiology:
            return ["chest pain", "arrhythmia", "CHF", "hypertension", "syncope",
                    "device", "anticoagulation", "post-cath"]
        case .psychiatry:
            return ["anxiety", "depression", "psychosis", "medication", "crisis",
                    "insomnia", "substance use", "safety concern"]
        case .orthopedics:
            return ["fracture", "post-op", "pain", "swelling", "wound",
                    "cast/splint", "hardware", "infection"]
        case .neurology:
            return ["headache", "seizure", "stroke", "weakness", "numbness",
                    "vertigo", "confusion", "tremor"]
        case .pulmonology:
            return ["SOB", "cough", "asthma", "COPD", "pneumonia",
                    "oxygen", "sleep apnea", "chest pain"]
        case .gastroenterology:
            return ["abdominal pain", "nausea", "GI bleed", "diarrhea", "constipation",
                    "liver", "reflux", "swallowing"]
        case .familyMedicine, .internalMedicine:
            return ["acute", "chronic", "medication", "follow-up", "preventive",
                    "labs", "imaging", "referral"]
        case .emergencyMedicine:
            return ["trauma", "chest pain", "respiratory", "altered mental status",
                    "abdominal", "overdose", "laceration"]
        case .generalSurgery:
            return ["post-op", "wound", "abscess", "hernia", "appendicitis",
                    "gallbladder", "obstruction", "bleeding"]
        case .urology:
            return ["UTI", "kidney stone", "hematuria", "retention", "incontinence",
                    "prostate", "catheter", "post-op"]
        case .nephrology:
            return ["dialysis", "CKD", "electrolytes", "hypertension", "edema",
                    "AKI", "transplant", "access"]
        case .oncology:
            return ["chemo side effects", "fever", "pain", "nausea", "counts",
                    "transfusion", "hospice", "new symptoms"]
        case .other:
            return ["urgent", "routine", "follow-up", "medication", "test results"]
        }
    }
}

// MARK: - Priority Suggestions

extension MedicalSpecialty {
    func suggestedPriority(for complaint: String) -> Priority {
        let lowercased = complaint.lowercased()

        switch self {
        case .cardiology:
            if lowercased.contains("chest pain") || lowercased.contains("stemi") ||
               lowercased.contains("syncope") || lowercased.contains("cardiac arrest") {
                return .emergent
            }
            if lowercased.contains("palpitations") || lowercased.contains("shortness of breath") {
                return .urgent
            }
        case .obgyn:
            if lowercased.contains("heavy bleeding") || lowercased.contains("decreased fetal movement") ||
               lowercased.contains("contractions") || lowercased.contains("water broke") ||
               lowercased.contains("preeclampsia") || lowercased.contains("eclampsia") {
                return .emergent
            }
            if lowercased.contains("bleeding") || lowercased.contains("pain") {
                return .urgent
            }
        case .psychiatry:
            if lowercased.contains("suicidal") || lowercased.contains("overdose") ||
               lowercased.contains("homicidal") || lowercased.contains("self-harm") ||
               lowercased.contains("psychosis") {
                return .emergent
            }
            if lowercased.contains("crisis") || lowercased.contains("panic") {
                return .urgent
            }
        case .pediatrics:
            if lowercased.contains("difficulty breathing") || lowercased.contains("not responsive") ||
               lowercased.contains("seizure") || lowercased.contains("unresponsive") ||
               lowercased.contains("blue") || lowercased.contains("choking") {
                return .emergent
            }
            if lowercased.contains("high fever") || lowercased.contains("dehydration") {
                return .urgent
            }
        case .neurology:
            if lowercased.contains("stroke") || lowercased.contains("seizure") ||
               lowercased.contains("sudden weakness") || lowercased.contains("altered") ||
               lowercased.contains("worst headache") {
                return .emergent
            }
        case .orthopedics:
            if lowercased.contains("open fracture") || lowercased.contains("compartment") ||
               lowercased.contains("no pulse") || lowercased.contains("neurovascular") {
                return .emergent
            }
            if lowercased.contains("fracture") || lowercased.contains("dislocation") {
                return .urgent
            }
        case .emergencyMedicine:
            if lowercased.contains("cardiac arrest") || lowercased.contains("unresponsive") ||
               lowercased.contains("not breathing") || lowercased.contains("severe bleeding") {
                return .emergent
            }
        case .pulmonology:
            if lowercased.contains("can't breathe") || lowercased.contains("severe sob") ||
               lowercased.contains("respiratory failure") || lowercased.contains("coughing blood") {
                return .emergent
            }
        case .gastroenterology:
            if lowercased.contains("gi bleed") || lowercased.contains("vomiting blood") ||
               lowercased.contains("black stool") || lowercased.contains("severe abdominal") {
                return .emergent
            }
        default:
            break
        }

        return .routine
    }
}

// MARK: - Parser Instructions

extension MedicalSpecialty {
    var parserInstructions: String {
        let base = """
            You are a medical triage message parser for a \(rawValue) on-call service.
            Extract structured data from unformatted answering service text messages.
            Fix misspellings and normalize formatting.
            """

        let specialtyContext: String
        switch self {
        case .obgyn:
            specialtyContext = """
                OBGYN-specific patterns:
                - OB status: "OB", "NOT OB", "POSTPARTUM", "PP", "PREGNANT"
                - Gestational ages: "32WKS", "32 WEEKS", "32W", "GA 32"
                - Common complaints: labor, contractions, bleeding, leaking fluid,
                  decreased fetal movement, preeclampsia symptoms, mastitis
                - Abbreviations: PP = postpartum, ROM = rupture of membranes,
                  PIH = pregnancy-induced hypertension, PPROM, SROM, AROM
                """
        case .pediatrics:
            specialtyContext = """
                Pediatrics-specific patterns:
                - Age formats: "3yo", "3 year old", "18mo", "6 week old", "newborn"
                - Weight may be mentioned: "22 lbs", "10 kg"
                - Common complaints: fever, rash, vomiting, diarrhea, cough,
                  difficulty breathing, ear pain, not eating
                - Abbreviations: yo = year old, mo = months old, FTT = failure to thrive
                """
        case .cardiology:
            specialtyContext = """
                Cardiology-specific patterns:
                - Cardiac symptoms: chest pain, palpitations, syncope, dyspnea, edema
                - Device mentions: pacemaker, ICD, AICD, stent
                - Medications: anticoagulants, beta blockers, ACE inhibitors
                - Abbreviations: CP = chest pain, SOB = shortness of breath,
                  STEMI, NSTEMI, AFib, CHF, EF
                """
        case .psychiatry:
            specialtyContext = """
                Psychiatry-specific patterns:
                - Safety concerns: SI (suicidal ideation), HI (homicidal ideation),
                  self-harm, overdose
                - Symptoms: anxiety, panic, psychosis, mania, depression, insomnia
                - Medication issues: ran out of meds, side effects, need refill
                - Abbreviations: SI = suicidal ideation, HI = homicidal ideation,
                  AH = auditory hallucinations, VH = visual hallucinations
                """
        case .orthopedics:
            specialtyContext = """
                Orthopedics-specific patterns:
                - Injury descriptions: fracture, dislocation, sprain, post-op
                - Body parts: specific joint/bone names
                - Symptoms: pain, swelling, inability to bear weight, numbness
                - Abbreviations: fx = fracture, ORIF, TKA, THA, ROM = range of motion
                """
        case .neurology:
            specialtyContext = """
                Neurology-specific patterns:
                - Stroke symptoms: sudden weakness, speech difficulty, facial droop
                - Seizure descriptions: type, duration, post-ictal state
                - Headache: worst of life, sudden onset, associated symptoms
                - Abbreviations: CVA = stroke, TIA, LOC = loss of consciousness,
                  AMS = altered mental status
                """
        case .pulmonology:
            specialtyContext = """
                Pulmonology-specific patterns:
                - Respiratory symptoms: dyspnea, cough, wheezing, hemoptysis
                - Oxygen requirements: home O2, BiPAP, CPAP
                - Conditions: COPD, asthma, pneumonia, PE
                - Abbreviations: SOB = shortness of breath, DOE = dyspnea on exertion,
                  O2 sat, FEV1
                """
        case .gastroenterology:
            specialtyContext = """
                Gastroenterology-specific patterns:
                - GI symptoms: abdominal pain, nausea, vomiting, diarrhea, constipation
                - Bleeding: hematemesis, melena, hematochezia
                - Conditions: GERD, IBD, cirrhosis, pancreatitis
                - Abbreviations: N/V = nausea/vomiting, BM = bowel movement,
                  BRBPR = bright red blood per rectum
                """
        case .familyMedicine, .internalMedicine:
            specialtyContext = """
                General medicine patterns:
                - Broad range of complaints: acute illness, chronic disease management
                - Medication refills and side effects
                - Test results and referral questions
                - Common abbreviations for vital signs and symptoms
                """
        case .emergencyMedicine:
            specialtyContext = """
                Emergency medicine patterns:
                - Trauma: mechanism of injury, vital signs
                - Acuity indicators: altered mental status, hemodynamic instability
                - Time-sensitive conditions: chest pain, stroke symptoms
                - Triage categories and disposition planning
                """
        default:
            specialtyContext = """
                General medical patterns:
                - Common symptoms and complaints
                - Standard medical abbreviations
                - Medication names and dosages
                """
        }

        return base + "\n\n" + specialtyContext
    }
}
