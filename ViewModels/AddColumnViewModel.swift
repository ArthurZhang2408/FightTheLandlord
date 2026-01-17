//
//  AddColumnViewModel.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import Foundation
import SwiftUI

extension Int {
    var point: String {
        switch self {
        case 1: return "1分"
        case 2: return "2分"
        case 3: return "3分"
        default: return "不叫"
        }
    }
    
    var bombs: String {
        switch self {
        case 0: return ""
        default: return self.description
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
    let results: [String] = ["地主赢了", "地主输了"]
    var basepoint: Int = 100
    @Published var setting: GameSetting
    @Published var aC: Color = .white
    @Published var bC: Color = .white
    @Published var cC: Color = .white
    var gameIdx: Int
    var instance: DataSingleton = DataSingleton.instance
    
    init(idx: Int) {
        gameIdx = idx
        setting = gameIdx == -1 ? GameSetting() : instance.games[gameIdx]
        bombs = setting.bombs.bombs
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
                errorMessage = "多人叫1分"
                return false
            }
            setting.landlord = 1
        }
        else if bpoint == "1分" {
            guard apoint != "1分" && cpoint != "1分" else {
                errorMessage = "多人叫1分"
                return false
            }
            setting.landlord = 2
        }
        else if cpoint == "1分" {
            guard apoint != "1分" && bpoint != "1分" else {
                errorMessage = "多人叫1分"
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
        
        // Apply spring multiplier (doubles the score)
        if setting.spring {
            basepoint *= 2
        }
        
        var a: Int, b: Int, c: Int
        setting.aC = "white"
        setting.bC = "white"
        setting.cC = "white"
        switch setting.landlord {
        case 1:
            if setting.adouble {
                basepoint *= 2
            }
            b = (setting.bdouble) ? basepoint*2 : basepoint
            c = (setting.cdouble) ? basepoint*2 : basepoint
            a = b + c
            if setting.landlordResult {
                b *= -1
                c *= -1
                aC = .green
                setting.aC = "green"
            }
            else {
                a *= -1
                aC = .red
                setting.aC = "red"
            }
        case 2:
            if setting.bdouble {
                basepoint *= 2
            }
            a = (setting.adouble) ? basepoint*2 : basepoint
            c = (setting.cdouble) ? basepoint*2 : basepoint
            b = a + c
            if setting.landlordResult {
                a *= -1
                c *= -1
                bC = .green
                setting.bC = "green"
            }
            else {
                b *= -1
                bC = .red
                setting.bC = "red"
            }
        default:
            if setting.cdouble {
                basepoint *= 2
            }
            b = (setting.bdouble) ? basepoint*2 : basepoint
            a = (setting.adouble) ? basepoint*2 : basepoint
            c = b + a
            if setting.landlordResult {
                b *= -1
                a *= -1
                cC = .green
                setting.cC = "green"
            }
            else {
                c *= -1
                cC = .red
                setting.cC = "red"
            }
        }
        setting.bombs = Int(bombs) ?? 0
        setting.apoint = apoint.point
        setting.bpoint = bpoint.point
        setting.cpoint = cpoint.point
        setting.A = a
        setting.B = b
        setting.C = c
        if gameIdx == -1 {
            instance.add(game: setting)
        } else {
            instance.change(game: setting, idx: gameIdx)
        }
        return true
    }
    
    var colorA: Color {
        if gameIdx == -1 && instance.games.count % 3 == 0 {
            
        }
        return .white
    }
    
}
