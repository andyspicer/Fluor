//
//  RunningAppsWindowController.swift
//  Fluor
//
//  Created by Pierre TACCHI on 06/09/16.
//  Copyright © 2016 Pyrolyse. All rights reserved.
//

import Cocoa

class RunningAppsWindowController: NSWindowController, BehaviorDidChangeHandler {
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet var runningAppsArrayController: NSArrayController!
    
    dynamic var runningAppsArray = [RuleItem]()
    dynamic var runningAppsCount: Int = 0
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))
        runningAppsArrayController.sortDescriptors = [sortDescriptor]
        loadData()
        applyAsObserver()
    }
    
    deinit {
        NSWorkspace.shared().notificationCenter.removeObserver(self)
        stopObservingBehaviorDidChange()
    }
    
    func behaviorDidChangeForApp(notification: Notification) {
        if let obj = notification.object as? RuleItem, case .rule = obj.kind { return }
        guard let userInfo = notification.userInfo as? [String: Any], let appId = userInfo["id"] as? String, let appBehavior = userInfo["behavior"] as? AppBehavior else { return }
        guard let index = runningAppsArray.index(where: { $0.id == appId }) else { return }
        runningAppsArray[index].behavior = appBehavior
    }
    
    /// Called whenever an application is launched by the system or the user.
    ///
    /// - parameter notification: The notification.
    @objc private func appDidLaunch(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication,
            let appId = app.bundleIdentifier,
            let appURL = app.bundleURL,
            let appIcon = app.icon else { return }
        let appPath = appURL.path
        let appName = Bundle(path: appPath)?.localizedInfoDictionary?["CFBundleName"] as? String ?? appURL.deletingPathExtension().lastPathComponent
        let behavior = BehaviorManager.default.behaviorForApp(id: appId)
        let item = RuleItem(id: appId, url: appURL, icon: appIcon, name: appName, behavior: behavior, kind: .runningApp)
        
        runningAppsArray.append(item)
    }
    
    /// Called whenever an application is terminated by the system or the user.
    ///
    /// - parameter notification: The notification.
    @objc private func appDidTerminate(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication,
            let appId = app.bundleIdentifier,
            let index = runningAppsArray.index(where: { $0.id == appId }) else { return }
        runningAppsArray.remove(at: index)
    }
    
    /// Set `self` as an observer for *launch* and *terminate* notfications.
    private func applyAsObserver() {
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(appDidLaunch(notification:)), name: NSNotification.Name.NSWorkspaceDidLaunchApplication, object: nil)
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(appDidTerminate(notification:)), name: NSNotification.Name.NSWorkspaceDidTerminateApplication, object: nil)
        startObservingBehaviorDidChange()
    }
    
    /// Load all running applications and populate the table view with corresponding datas.
    private func loadData() {
        runningAppsArray = NSWorkspace.shared().runningApplications.flatMap { (app) -> RuleItem? in
            guard let appId = app.bundleIdentifier, let appURL = app.bundleURL, let appIcon = app.icon else { return nil }
            guard app.activationPolicy == .regular else { return nil }
            let appPath = appURL.path
            let appName = Bundle(path: appPath)?.localizedInfoDictionary?["CFBundleName"] as? String ?? appURL.deletingPathExtension().lastPathComponent
            let behavior = BehaviorManager.default.behaviorForApp(id: appId)
            return RuleItem(id: appId, url: appURL, icon: appIcon, name: appName, behavior: behavior, kind: .runningApp)
        }
    }
}
