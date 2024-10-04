//
//  AddColumnViewModel.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import Foundation

class AddColumnViewModel: ObservableObject {
    @Published var bombs: String = ""
    @Published var apoint: String = "不叫"
    @Published var bpoint: String = "不叫"
    @Published var cpoint: String = "不叫"
    @Published var adouble: Bool = false
    @Published var bdouble: Bool = false
    @Published var cdouble: Bool = false
    @Published var showAlert: Bool = false
    @Published var errorMessage: String = ""
    @Published var landlordResult: String = "赢了"
    @Published var results: [String] = ["赢了", "输了"]
    @Published var landlord: String = "A"
    @Published var basepoint: Int = 100
    @Published var a: Int = 0
    @Published var b: Int = 0
    @Published var c: Int = 0
    
    @Published var points: [String] = ["不叫", "1分", "2分", "3分"]
    
    private func validate() -> Bool {
        
        errorMessage = ""
        if apoint == "3分" {
            guard bpoint != "3分" && cpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            landlord = "A"
            basepoint = 300
        }
        else if bpoint == "3分" {
            guard apoint != "3分" && cpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            landlord = "B"
            basepoint = 300
        }
        else if cpoint == "3分" {
            guard apoint != "3分" && bpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            landlord = "C"
            basepoint = 300
        }
        else if apoint == "2分" {
            guard bpoint != "2分" && cpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            landlord = "A"
            basepoint = 200
        }
        else if bpoint == "2分" {
            guard apoint != "2分" && cpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            landlord = "B"
            basepoint = 200
        }
        else if cpoint == "2分" {
            guard apoint != "2分" && bpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            landlord = "C"
            basepoint = 200
        }
        else if apoint == "1分" {
            guard bpoint != "1分" && cpoint != "1分" else {
                errorMessage = "多人叫2分"
                return false
            }
            landlord = "A"
        }
        else if bpoint == "1分" {
            guard apoint != "1分" && cpoint != "1分" else {
                errorMessage = "多人叫2分"
                return false
            }
            landlord = "B"
        }
        else if cpoint == "1分" {
            guard apoint != "1分" && bpoint != "1分" else {
                errorMessage = "多人叫2分"
                return false
            }
            landlord = "C"
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
        switch landlord {
        case "A":
            if adouble {
                basepoint *= 2
            }
            b = (bdouble) ? basepoint*2 : basepoint
            c = (cdouble) ? basepoint*2 : basepoint
            a = b + c
            if landlordResult == "赢了" {
                b *= -1
                c *= -1
            }
            else {a *= -1}
        case "B":
            if bdouble {
                basepoint *= 2
            }
            a = (adouble) ? basepoint*2 : basepoint
            c = (cdouble) ? basepoint*2 : basepoint
            b = a + c
            if landlordResult == "赢了" {
                a *= -1
                c *= -1
            }
            else {b *= -1}
        default:
            if cdouble {
                basepoint *= 2
            }
            b = (bdouble) ? basepoint*2 : basepoint
            a = (adouble) ? basepoint*2 : basepoint
            c = b + a
            if landlordResult == "赢了" {
                b *= -1
                a *= -1
            }
            else {c *= -1}
        }
        return true
    }
    
}
