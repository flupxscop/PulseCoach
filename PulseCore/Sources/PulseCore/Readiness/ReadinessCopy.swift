import Foundation

// User-facing Thai copy for readiness, kept next to the rules it describes.
// Plain language first ("ชีพจรขณะพัก"), technical term second.

extension ReadinessFlag {
    public var metricName: String {
        switch self {
        case .elevatedRestingHR: "ชีพจรขณะพัก"
        case .lowHRV: "ความผ่อนคลายของหัวใจ (HRV)"
        case .shortSleep: "การนอน"
        case .lowSpO2: "ออกซิเจนในเลือด"
        }
    }

    /// Short label for compact rows (Today card, watch).
    public var shortName: String {
        switch self {
        case .elevatedRestingHR: "ชีพจรขณะพัก"
        case .lowHRV: "ความผ่อนคลายหัวใจ"
        case .shortSleep: "การนอน"
        case .lowSpO2: "ออกซิเจนในเลือด"
        }
    }

    public var ruleDescription: String {
        switch self {
        case .elevatedRestingHR: "หัก 25 ถ้าสูงกว่าปกติ 7 ขึ้นไป"
        case .lowHRV: "หัก 25 ถ้าต่ำกว่า 80% ของปกติ"
        case .shortSleep: "หัก 15 ถ้าน้อยกว่า 6 ชั่วโมง"
        case .lowSpO2: "หัก 15 ถ้าต่ำกว่า 94%"
        }
    }

    public var systemImage: String {
        switch self {
        case .elevatedRestingHR: "heart.fill"
        case .lowHRV: "waveform.path.ecg"
        case .shortSleep: "moon.fill"
        case .lowSpO2: "drop.fill"
        }
    }

    /// Action-first notification text (never "diagnosed", never alarming).
    public var gentleAdvice: String {
        switch self {
        case .elevatedRestingHR: "ชีพจรขณะพักสูงกว่าปกติของคุณ วันนี้ลองออกกำลังกายเบาๆ"
        case .lowHRV: "ร่างกายยังฟื้นตัวไม่เต็มที่ วันนี้เน้นเบาๆ หรือพัก"
        case .shortSleep: "เมื่อคืนนอนน้อย วันนี้ลดความหนักลงหน่อย"
        case .lowSpO2: "ค่าออกซิเจนต่ำกว่าปกติ วันนี้พักก่อนดีกว่า"
        }
    }
}

extension ReadinessCheck {
    /// Formatted value for display, e.g. "58", "7 ชม. 24 น.", "97%".
    public var formattedValue: String {
        guard let value else { return "–" }
        switch flag {
        case .elevatedRestingHR, .lowHRV:
            return String(Int(value.rounded()))
        case .shortSleep:
            let totalMinutes = Int((value * 60).rounded())
            return "\(totalMinutes / 60) ชม. \(totalMinutes % 60) น."
        case .lowSpO2:
            return "\(Int((value * 100).rounded()))%"
        }
    }

    /// Short status chip text: "ปกติ", "↑ ดีขึ้น", "ต่ำกว่าปกติ", "ไม่มีข้อมูล".
    public var statusText: String {
        switch status {
        case .noData: return "ไม่มีข้อมูล"
        case .flagged: return flag == .elevatedRestingHR ? "สูงกว่าปกติ" : "ต่ำกว่าปกติ"
        case .ok:
            guard let value, let baseline else { return "ผ่าน" }
            switch flag {
            case .elevatedRestingHR: return value < baseline - 2 ? "↓ ดีขึ้น" : "ปกติ"
            case .lowHRV: return value > baseline * 1.05 ? "↑ ดีขึ้น" : "ปกติ"
            default: return "ผ่าน"
            }
        }
    }
}
