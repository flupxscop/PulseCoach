import Foundation

/// One gym move with everything the watch and iPhone need to coach it.
public struct Exercise: Sendable, Codable, Equatable, Identifiable {
    public var id: String            // also the image prefix: "ex-<id>-1" / "ex-<id>-2"
    public var name: String
    public var shortName: String
    public var sets: Int
    public var reps: Int
    public var perSide: Bool
    public var muscle: String
    public var cue: String
    public var steps: [String]       // exactly 3 how-to steps
    public var defaultWeightKg: Double?

    public init(id: String, name: String, shortName: String, sets: Int, reps: Int, perSide: Bool = false,
                muscle: String, cue: String, steps: [String], defaultWeightKg: Double? = nil) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.sets = sets
        self.reps = reps
        self.perSide = perSide
        self.muscle = muscle
        self.cue = cue
        self.steps = steps
        self.defaultWeightKg = defaultWeightKg
    }

    /// Image asset names for the start and end frames.
    public var startImage: String { "ex-\(id)-1" }
    public var endImage: String { "ex-\(id)-2" }

    /// "3 เซ็ต × 10 ครั้ง/ข้าง"
    public var dose: String { "\(sets) เซ็ต × \(reps) ครั้ง\(perSide ? "/ข้าง" : "")" }

    public var weightText: String? {
        defaultWeightKg.map { $0.rounded() == $0 ? "\(Int($0)) กก." : String(format: "%.1f กก.", $0) }
    }
}

public enum ExerciseLibrary {
    public static let barbellRow = Exercise(
        id: "row", name: "Barbell Row", shortName: "Barbell", sets: 3, reps: 10,
        muscle: "หลังส่วนกลาง", cue: "หลังตรง ดึงศอกไปทางสะโพก",
        steps: ["ยืนเท้ากว้างเท่าสะโพก ก้มตัวจากสะโพกราว 45 องศา",
                "หลังตรง ดึงบาร์เข้าหาท้อง ศอกชิดลำตัว",
                "บีบสะบักค้าง 1 วินาที แล้วลดบาร์ลงช้าๆ"],
        defaultWeightKg: 40)

    public static let latPulldown = Exercise(
        id: "pulldown", name: "Lat Pulldown", shortName: "Pulldown", sets: 3, reps: 12,
        muscle: "หลัง · ปีก", cue: "อกเปิด ดึงบาร์ลงมาที่อกส่วนบน",
        steps: ["นั่งให้ต้นขาล็อกใต้เบาะ จับบาร์กว้างกว่าไหล่",
                "อกเปิด ดึงบาร์ลงมาที่อกส่วนบน",
                "ปล่อยบาร์ขึ้นช้าๆ จนแขนเหยียดสุด"],
        defaultWeightKg: 35)

    public static let seatedCableRow = Exercise(
        id: "cablerow", name: "Seated Cable Row", shortName: "Cable", sets: 3, reps: 12,
        muscle: "หลัง · สะบัก", cue: "ดึงด้ามจับเข้าหาท้อง ไม่เอนตัวมาก",
        steps: ["นั่งตัวตรง เท้ายันแป้น เข่างอเล็กน้อย",
                "ดึงด้ามจับเข้าหาท้อง ไม่เอนตัวไปด้านหลังมาก",
                "บีบสะบัก แล้วยืดแขนกลับอย่างควบคุม"],
        defaultWeightKg: 30)

    public static let dumbbellRow = Exercise(
        id: "dbrow", name: "One-Arm Dumbbell Row", shortName: "Dumbbell", sets: 3, reps: 10, perSide: true,
        muscle: "ปีก · หลังส่วนบน", cue: "ดึงดัมเบลเข้าหาสะโพก ศอกชิดลำตัว",
        steps: ["วางเข่าและมือข้างเดียวกันบนม้านั่ง หลังขนานพื้น",
                "ดึงดัมเบลขึ้นเข้าหาสะโพก ศอกชิดลำตัว",
                "ลดลงช้าๆ จนแขนเหยียด แล้วสลับข้าง"],
        defaultWeightKg: 14)

    public static let tBarRow = Exercise(
        id: "tbarrow", name: "T-Bar Row", shortName: "T-Bar", sets: 3, reps: 10,
        muscle: "หลังส่วนกลาง", cue: "ดึงบาร์เข้าหาอก ศอกไปด้านหลัง",
        steps: ["คร่อมบาร์ ก้มตัวจากสะโพก เข่างอเล็กน้อย",
                "ดึงบาร์เข้าหาอก ศอกไปด้านหลัง",
                "ลดบาร์ลงอย่างควบคุม หลังตรงตลอด"],
        defaultWeightKg: 25)

    public static let machineRow = Exercise(
        id: "machinerow", name: "Machine Row", shortName: "Machine", sets: 3, reps: 12,
        muscle: "หลังส่วนบน · ไหล่หลัง", cue: "ดึงด้ามจับไปด้านหลัง บีบสะบัก",
        steps: ["ปรับเบาะให้มือจับอยู่ระดับไหล่",
                "ดึงด้ามจับออกด้านข้างและไปด้านหลัง",
                "บีบสะบักค้างไว้ แล้วคืนกลับช้าๆ"],
        defaultWeightKg: 30)

    public static let closeGripPulldown = Exercise(
        id: "closepulldown", name: "Close-Grip Pulldown", shortName: "Close-Grip", sets: 3, reps: 12,
        muscle: "ปีก", cue: "ดึงด้ามจับลงมาที่อก ศอกชิดลำตัว",
        steps: ["นั่งบนม้านั่ง จับด้ามจับ V เหนือศีรษะ",
                "ดึงลงมาที่อกส่วนบน ศอกชิดลำตัว",
                "ปล่อยขึ้นช้าๆ จนแขนเหยียด"],
        defaultWeightKg: 35)

    public static let leverPulldown = Exercise(
        id: "leverpulldown", name: "Lever Pulldown", shortName: "Lever", sets: 3, reps: 12,
        muscle: "ปีก · หลังส่วนล่าง", cue: "ดึงด้ามจับลงถึงระดับไหล่",
        steps: ["นั่งตัวตรง จับด้ามจับทั้งสองข้างเหนือศีรษะ",
                "ดึงลงจนมือถึงระดับไหล่ ศอกลงและไปด้านหลัง",
                "คืนกลับช้าๆ อย่าปล่อยให้น้ำหนักกระแทก"],
        defaultWeightKg: 30)

    public static let plateLoadedRow = Exercise(
        id: "leverrow", name: "Plate-Loaded Row", shortName: "Plate", sets: 3, reps: 10,
        muscle: "หลัง · ไหล่หลัง", cue: "อกแนบเบาะ ดึงด้ามจับไปที่ซี่โครง",
        steps: ["นั่งให้อกแนบเบาะ จับด้ามจับแขนเหยียด",
                "ดึงด้ามจับไปที่ซี่โครง ศอกผ่านลำตัว",
                "บีบสะบัก แล้วคืนกลับอย่างควบคุม"],
        defaultWeightKg: 30)

    public static let all: [Exercise] = [
        barbellRow, latPulldown, seatedCableRow, dumbbellRow, tBarRow,
        machineRow, closeGripPulldown, leverPulldown, plateLoadedRow
    ]

    /// The 6-move back day from the design (เวทเทรนนิ่ง · วันเล่นหลัง).
    public static let backDay: [Exercise] = [
        barbellRow, latPulldown, seatedCableRow, dumbbellRow, tBarRow, machineRow
    ]

    public static func exercise(id: String) -> Exercise? { all.first { $0.id == id } }
}
