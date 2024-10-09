//
//  AddColumnViewModel.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import Foundation

extension Int {
    var point: String {
        switch self {
        case 1: return "1分"
        case 2: return "2分"
        case 3: return "3分"
        default: return "不叫"
        }
    }
}

extension String {
    var point: Int {
        switch self {
        case "1分": return 1
        case "2分": return 2
        case "3分": return 3
        default: return 0
        }
    }
}

class AddColumnViewModel: ObservableObject {
    @Published var bombs: String = ""
    @Published var apoint: String = "不叫"
    @Published var bpoint: String = "不叫"
    @Published var cpoint: String = "不叫"
    @Published var showAlert: Bool = false
    @Published var errorMessage: String = ""
    @Published var landlordResult: String = "赢了"
    let results: [String] = ["赢了", "输了"]
    @Published var basepoint: Int = 100
    @Published var setting: GameSetting
    
    init(setting: GameSetting = GameSetting()) {
        self.setting = setting
        bombs = setting.bombs == 0 ? "":setting.bombs.description
        apoint = setting.apoint.point
        bpoint = setting.bpoint.point
        cpoint = setting.cpoint.point
    }
    
    @Published var points: [String] = ["不叫", "1分", "2分", "3分"]
    
    private func validate() -> Bool {
        
        errorMessage = ""
        if apoint == "3分" {
            guard bpoint != "3分" && cpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            setting.landlord = 1
            basepoint = 300
        }
        else if bpoint == "3分" {
            guard apoint != "3分" && cpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            setting.landlord = 2
            basepoint = 300
        }
        else if cpoint == "3分" {
            guard apoint != "3分" && bpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            setting.landlord = 3
            basepoint = 300
        }
        else if apoint == "2分" {
            guard bpoint != "2分" && cpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 1
            basepoint = 200
        }
        else if bpoint == "2分" {
            guard apoint != "2分" && cpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 2
            basepoint = 200
        }
        else if cpoint == "2分" {
            guard apoint != "2分" && bpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 3
            basepoint = 200
        }
        else if apoint == "1分" {
            guard bpoint != "1分" && cpoint != "1分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 1
        }
        else if bpoint == "1分" {
            guard apoint != "1分" && cpoint != "1分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 2
        }
        else if cpoint == "1分" {
            guard apoint != "1分" && bpoint != "1分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 3
        }
        else {
            errorMessage = "没有人叫分"
            return false
        }
        return true
    }
    
    public func add() -> Bool {
        guard validate() else {
            showAlert = true
            return false
        }
        let xrate: Int = Int(bombs) ?? 0
        basepoint <<= xrate
        var a: Int, b: Int, c: Int
        switch setting.landlord {
        case 1:
            if setting.adouble {
                basepoint *= 2
            }
            b = (setting.bdouble) ? basepoint*2 : basepoint
            c = (setting.cdouble) ? basepoint*2 : basepoint
            a = b + c
            if landlordResult == "赢了" {
                b *= -1
                c *= -1
            }
            else {a *= -1}
        case 2:
            if setting.bdouble {
                basepoint *= 2
            }
            a = (setting.adouble) ? basepoint*2 : basepoint
            c = (setting.cdouble) ? basepoint*2 : basepoint
            b = a + c
            if landlordResult == "赢了" {
                a *= -1
                c *= -1
            }
            else {b *= -1}
        default:
            if setting.cdouble {
                basepoint *= 2
            }
            b = (setting.bdouble) ? basepoint*2 : basepoint
            a = (setting.adouble) ? basepoint*2 : basepoint
            c = b + a
            if landlordResult == "赢了" {
                b *= -1
                a *= -1
            }
            else {c *= -1}
        }
        setting.bombs = Int(bombs) ?? 0
        setting.apoint = apoint.point
        setting.bpoint = bpoint.point
        setting.cpoint = cpoint.point
        setting.landlordResult = landlordResult=="赢了"
        setting.A = a
        setting.B = b
        setting.C = c
        return true
    }
    
}
