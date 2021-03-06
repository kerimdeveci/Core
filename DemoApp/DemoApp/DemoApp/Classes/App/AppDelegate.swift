//
//  Copyright © 2018 mkerekes. All rights reserved.
//

import UIKit
import IosCore
import Presentation
import Domain
import Data
import Additions
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var appRouter: AppRouter!
    var appPresenter: AppPresenting!
    var helper: NotificationServicesHelper!
    var orientationLock = UIInterfaceOrientationMask.portrait
    let config: Configuration = Configuration.shared
    
    private func setupApplication() {
        window?.rootViewController = UIViewController()
        guard !TestHelper.isTesting else {
            return
        }
        
        //setup dependency injection
        let config: Configuration = Configuration.shared
        config.settings.register()
        DependencyInjection().injectDependencies(in: config.appModules)
        let appModule: AppModule = config.appModules.module()
        let result = appModule.setup(window: window!, config: config)
        appPresenter = result.presenter
        appRouter = result.router
        helper = NotificationServicesHelper(appPresenter: appPresenter)
        appPresenter.loadApplication()
    }
    
    private func forwardNotifications(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !TestHelper.isTesting else {
            return
        }
        if let deeplink = helper.extractParams(from: launchOptions) {
            appPresenter.link(with: DeepLinkOption<Void>.deeplink(deeplink))
        }
        
        helper.forwardNotification(to: appPresenter, from: launchOptions)
    }
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow()
        window?.makeKeyAndVisible()
        setupApplication()
        if application.applicationState == .active ||  TestHelper.isUITesting {
            forwardNotifications(with: launchOptions)
        }
        config.notificationServices.setupAWSservices(with: launchOptions)
        if !TestHelper.isUITesting {
            config.notificationServices.registerForPushNotifications()
        }
        config.notificationServices.helper = helper
        if let launchOptions = launchOptions {
            helper.processOtherArguments(from: launchOptions)
        }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        return true
    }
    
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        let deepLink = DeepLinkOption<Void>.activity(userActivity)
        appPresenter.link(with: deepLink)
        return true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        appPresenter.applicationWillEnterForeground()
    }
        
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return self.orientationLock
    }
    
    //MARK: - Handle Notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        config.notificationServices.didRegisterForRemoteNotificationsWith(token: deviceToken)
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler:
        @escaping (UIBackgroundFetchResult) -> Void) {
        
        config.notificationServices.didReceiveRemoteNotification(userInfo: userInfo) { (result) in
            switch result {
            case .failed:
                completionHandler(.failed)
            case .newData:
                completionHandler(.newData)
            case .noData:
                completionHandler(.noData)
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        config.notificationServices.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        config.notificationServices.forwardNotifications(userInfo: userInfo)
    }
}

extension AppRouter: LogoutResponder {
    public func didLogout() {
        delegate?.setNeedsRestart()
    }
}

extension AppRouter: OrientationLocking {
    public func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.orientationLock = orientation
        }
    }
    
    public func lockOrientation(_ orientation: UIInterfaceOrientationMask,
                                andRotateTo rotateOrientation: UIInterfaceOrientation) {
        self.lockOrientation(orientation)
        UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
    }
}

