//
//  AppDelegate.swift
//  basic_app
//
//  Created by Liaz Kamper on 11/05/2020.
//  Copyright © 2020 OneLink. All rights reserved.
//

import UIKit
import AppsFlyerLib
import AppTrackingTransparency
import AppsFlyerMigrationHelper

import BranchSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var ConversionData: [AnyHashable: Any]? = nil
    var window: UIWindow?
    var deferred_deep_link_processed_flag:Bool = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        //  Set isDebug to true to see AppsFlyer debug logs
        AppsFlyerLib.shared().isDebug = true
        
        // Replace 'appsFlyerDevKey', `appleAppID` with your DevKey, Apple App ID
        AppsFlyerLib.shared().appsFlyerDevKey = "sQ84wpdxRTR4RMCaE9YqS4"
        AppsFlyerLib.shared().appleAppID = "1512793879"
        
        Branch.enableLogging()
        
        if #available(iOS 16.0, *) {
            // Don't check pasteboard on install, instead utilize UIPasteControl
        } else if #available(iOS 15.0, *) {
            // Call `checkPasteboardOnInstall()` before Branch initialization
            Branch.getInstance().checkPasteboardOnInstall()
        }
        
        // Check if pasteboard toast will show
        if Branch.getInstance().willShowPasteboardToast(){
            // You can notify the user of what just occurred here
            NSLog("[Branch] willShowPasteboardToast ######")
        }
        
        Branch.getInstance().initSession(launchOptions: launchOptions) { (params, error) in
            print(params as? [String: AnyObject] ?? {})
            
            if error != nil {
                print("Error initializing Branch: \(String(describing: error))")
                // Even Branch starts with an error, AppsFlyer should be started
                AppsFlyerLib.shared().start()
            } else {
                NSLog("Branch SDK init completed successfully")
                // Access and use deep link data here (nav to page, display content, etc.)
                let isFirstBranchSession = (params?["+is_first_session"] as? Bool) ?? false
                let isDeepLink = (params?["+clicked_branch_link"] as? Bool) ?? false
                
                if isDeepLink {
                    // deep link flow
                    if isFirstBranchSession {
                        // Deferred deep linking flow
                        let dispatchGroup = DispatchGroup()
                        dispatchGroup.enter()
                        
                        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3) {
                            Branch.getInstance().lastAttributedTouchData(withAttributionWindow:0) { (params, error) in
                                if let params = params {
                                    // In several cases the LATD can come back nil.
                                    // This condition protects this case
                                    AFMigrationHelper.shared.setAttributionData(params.lastAttributedTouchJSON, attributionWindow: params.attributionWindow)
                                }
                                AppsFlyerLib.shared().start()
                            }
                            dispatchGroup.leave()
                        }
                    } else {
                        // Direct deep linking flow - Universal link
                        AFMigrationHelper.shared.setDeepLinkingData(Branch.getInstance().getLatestReferringParams())
                        AppsFlyerLib.shared().start()
                    }
                } else {
                    // Organic flow
                    AppsFlyerLib.shared().start()
                }
            }
            return
        }
        return true
    }
    
        
    // Open Universal Links
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        // Handler for Universal Links
        Branch.getInstance().continue(userActivity)
        AppsFlyerLib.shared().continue(userActivity)
        return true
    }
            
    // Open URI-scheme for iOS 9 and above
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return true
    }
    
       
    // User logic
    fileprivate func walkToSceneWithParams(fruitName: String, deepLinkData: [String: Any]?) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        UIApplication.shared.windows.first?.rootViewController?.dismiss(animated: true, completion: nil)
               
        let destVC = fruitName + "_vc"
        if let newVC = storyBoard.instantiateVC(withIdentifier: destVC) {
            
            NSLog("[AFSDK] AppsFlyer routing to section: \(destVC)")
            newVC.deepLinkData = deepLinkData
            
             UIApplication.shared.windows.first?.rootViewController?.present(newVC, animated: true, completion: nil)
        } else {
            NSLog("[AFSDK] AppsFlyer: could not find section: \(destVC)")
        }
    }
}

extension UIStoryboard {
    func instantiateVC(withIdentifier identifier: String) -> DLViewController? {
        // "identifierToNibNameMap" – dont change it. It is a key for searching IDs
        if let identifiersList = self.value(forKey: "identifierToNibNameMap") as? [String: Any] {
            if identifiersList[identifier] != nil {
                return self.instantiateViewController(withIdentifier: identifier) as? DLViewController
            }
        }
        return nil
    }
}
