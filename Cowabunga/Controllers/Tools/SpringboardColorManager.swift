//
//  SpringboardColorManager.swift
//  Cowabunga
//
//  Created by lemin on 2/1/23.
//

import SwiftUI
import MacDirtyCowSwift

class SpringboardColorManager {
    enum SpringboardType: CaseIterable {
        case dock
        case folder
        case folderBG
        case libraryFolder
        case switcher
        case notif
    }
    
    private static let finalFiles: [SpringboardType: [String]] = [
        SpringboardType.folder: ["folderDark", "folderLight"],
        SpringboardType.libraryFolder: ["podBackgroundViewDark", "podBackgroundViewLight"],
        SpringboardType.dock: ["dockDark", "dockLight"],
        SpringboardType.folderBG: ["folderExpandedBackgroundHome", "homeScreenOverlay", "homeScreenOverlay-iPad"],
        SpringboardType.switcher: ["homeScreenBackdrop-application"],
        SpringboardType.notif: ["plattersDark", "platters"]
    ]
    
    private static let fileFolders: [SpringboardType: String] = [
        SpringboardType.folder: "/System/Library/PrivateFrameworks/SpringBoardHome.framework/",
        SpringboardType.libraryFolder: "/System/Library/PrivateFrameworks/SpringBoardHome.framework/",
        SpringboardType.dock: "/System/Library/PrivateFrameworks/CoreMaterial.framework/",
        SpringboardType.folderBG: "/System/Library/PrivateFrameworks/SpringBoardHome.framework/",
        SpringboardType.switcher: "/System/Library/PrivateFrameworks/SpringBoard.framework/",
        SpringboardType.notif: "/System/Library/PrivateFrameworks/CoreMaterial.framework/"
    ]
    
    private static let fileExt: [SpringboardType: String] = [
        SpringboardType.folder: ".materialrecipe",
        SpringboardType.libraryFolder: ".visualstyleset",
        SpringboardType.dock: ".materialrecipe",
        SpringboardType.folderBG: ".materialrecipe",
        SpringboardType.switcher: ".materialrecipe",
        SpringboardType.notif: ".materialrecipe"
    ]
    
    static func getColor(forType: SpringboardType) -> Color {
        let bgDir = getBackgroundDirectory()
        if bgDir == nil || finalFiles[forType] == nil || !FileManager.default.fileExists(atPath: (bgDir!.appendingPathComponent("\(finalFiles[forType]![0]).materialrecipe").path)) {
            return Color.gray
        }
        do {
            let newData = try Data(contentsOf: bgDir!.appendingPathComponent("\(finalFiles[forType]![0]).materialrecipe"))
            let plist = try PropertyListSerialization.propertyList(from: newData, options: [], format: nil) as! [String: Any]
            // get the color
            if let firstLevel = plist["baseMaterial"] as? [String : Any], let secondLevel = firstLevel["tinting"] as? [String: Any], let thirdLevel = secondLevel["tintColor"] as? [String: Any] {
                let r = thirdLevel["red"] as? Double ?? CIColor.gray.red
                let g = thirdLevel["green"] as? Double ?? CIColor.gray.green
                let b = thirdLevel["blue"] as? Double ?? CIColor.gray.blue
                let mFactor = ((forType == SpringboardType.notif) ? 0.8: 0.3)
                let a = (secondLevel["tintAlpha"] as? Double ?? mFactor)/mFactor
                
                return Color.init(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b)).opacity(a)
            }
        } catch {
            print(error.localizedDescription)
        }
        return Color.gray
    }
    
    static func getBlur(forType: SpringboardType) -> Double {
        let bgDir = getBackgroundDirectory()
        if bgDir == nil || finalFiles[forType] == nil || !FileManager.default.fileExists(atPath: (bgDir!.appendingPathComponent("\(finalFiles[forType]![0]).materialrecipe").path)) {
            return 30
        }
        do {
            let newData = try Data(contentsOf: bgDir!.appendingPathComponent("\(finalFiles[forType]![0]).materialrecipe"))
            let plist = try PropertyListSerialization.propertyList(from: newData, options: [], format: nil) as! [String: Any]
            // get the blur
            if let firstLevel = plist["baseMaterial"] as? [String: Any], let secondLevel = firstLevel["materialFiltering"] as? [String: Any], let thirdLevel = secondLevel["blurRadius"] as? Int {
                return Double(thirdLevel)
            }
        } catch {
            print(error.localizedDescription)
        }
        return 30
    }
    
    static func createColor(forType: SpringboardType, color: CIColor, blur: Int) throws {
        let bgDir = getBackgroundDirectory()
        
        if bgDir != nil && finalFiles[forType] != nil && fileFolders[forType] != nil && fileExt[forType] != nil {
            // get the files
            let url = Bundle.main.url(forResource: "replacement", withExtension: ".materialrecipe")
            
            // set the colors
            if url != nil {
                do {
                    let plistData = try Data(contentsOf: url!)
                    var plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as! [String: Any]
                    
                    if var firstLevel = plist["baseMaterial"] as? [String : Any], var secondLevel = firstLevel["tinting"] as? [String: Any], var thirdLevel = secondLevel["tintColor"] as? [String: Any] {
                        // set the colors
                        thirdLevel["red"] = color.red
                        thirdLevel["green"] = color.green
                        thirdLevel["blue"] = color.blue
                        thirdLevel["alpha"] = 1
                        
                        if var secondLevel2 = firstLevel["materialFiltering"] as? [String: Any] {
                            secondLevel2["blurRadius"] = blur
                            firstLevel["materialFiltering"] = secondLevel2
                        }
                        
                        secondLevel["tintColor"] = thirdLevel
                        secondLevel["tintAlpha"] = color.alpha*( (forType == SpringboardType.notif) ? 0.8: 0.3)
                        firstLevel["tinting"] = secondLevel
                        plist["baseMaterial"] = firstLevel
                    }
                    
                    // fill with empty data
                    for (_, file) in finalFiles[forType]!.enumerated() {
                        // get original data
                        let path: String = "\(fileFolders[forType]!)\(file)\(fileExt[forType]!)"
                        let newUrl = URL(fileURLWithPath: path)
                        do {
                            let originalFileSize = try Data(contentsOf: newUrl).count
                            let newData = try addEmptyData(matchingSize: originalFileSize, to: plist)
                            // save file to background directory
                            if newData.count == originalFileSize {
                                try newData.write(to: bgDir!.appendingPathComponent(file+fileExt[forType]!))
                            } else {
                                print("NOT CORRECT SIZE")
                            }
                        } catch {
                            print(error.localizedDescription)
                            throw error.localizedDescription
                        }
                    }
                }
            } else {
                throw "Could not find original resource url"
            }
        } else {
            throw "Could not find the background files directory!"
        }
    }
    
    static func deteleColor(forType: SpringboardType) throws {
        let bgDir = getBackgroundDirectory()
        if bgDir != nil {
            for (_, file) in finalFiles[forType]!.enumerated() {
                let path: URL = bgDir!.appendingPathComponent(file+fileExt[forType]!)
                try FileManager.default.removeItem(at: path)
            }
        } else {
            throw "Could not find the background files directory!"
        }
    }
    
    static func applyColor(forType: SpringboardType) {
        let bgDir = getBackgroundDirectory()
        
        if bgDir != nil && finalFiles[forType] != nil && fileFolders[forType] != nil {
            for (_, file) in finalFiles[forType]!.enumerated() {
                do {
                    let newData = try Data(contentsOf: bgDir!.appendingPathComponent(file + ".materialrecipe"))
                    // overwrite file
                    let path: String = "\(fileFolders[forType]!)\(file).materialrecipe"
                    let _ = MDC.overwriteFile(at: path, with: newData)
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    // get the directory of where background files are saved
    static func getBackgroundDirectory() -> URL? {
        do {
            let newURL: URL = URL.documents.appendingPathComponent("Background_Files")
            if !FileManager.default.fileExists(atPath: newURL.path) {
                try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
            }
            return newURL
        } catch {
            print("An error occurred getting/making the background files directory")
        }
        return nil
    }
}
