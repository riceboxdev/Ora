//
//  AppDelegate.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/21/25.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import GoogleMobileAds
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    private var apnsTokenSet = false
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize Firebase
        FirebaseApp.configure()
        Logger.info("Firebase configured in AppDelegate", service: "AppDelegate")
        
        // Initialize Google Mobile Ads
        MobileAds.shared.start(completionHandler: nil)
//        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [ "78bf3f080fc6c81a36f26229501ef028" ]
        
        // Register for remote notifications FIRST
        // Don't set Messaging delegate until after APNS registration is requested
        // This prevents Firebase from trying to get FCM token before APNS is available
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { [weak self] granted, error in
                if let error = error {
                    Logger.error("Failed to request notification authorization: \(error.localizedDescription)", service: "AppDelegate")
                } else {
                    Logger.info("Notification authorization granted: \(granted)", service: "AppDelegate")
                    if granted {
                        // Register for remote notifications to get APNS token
                        DispatchQueue.main.async {
                            application.registerForRemoteNotifications()
                        }
                    }
                }
                
                // Set Messaging delegate AFTER requesting APNS registration
                // This reduces the chance of Firebase trying to get token before APNS is ready
                // Note: Firebase will still try, but APNS registration should complete quickly
                DispatchQueue.main.async {
                    Messaging.messaging().delegate = self
                }
            }
        )
        
        // Initialize Remote Config (after Firebase is configured)
        RemoteConfigService.shared.initialize()
        
        
        return true
    }
    
    // MARK: - MessagingDelegate
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Foundation.Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
        
        // Register FCM token with backend
        if let token = fcmToken {
            Task {
                do {
                    try await PushNotificationService.shared.registerToken(token)
                    Logger.info("FCM token registered successfully", service: "AppDelegate")
                } catch {
                    Logger.error("Failed to register FCM token: \(error.localizedDescription)", service: "AppDelegate")
                }
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print message ID.
        if let messageID = userInfo["gcm.message_id"] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        // Check if app is in foreground
        let applicationState = UIApplication.shared.applicationState
        if applicationState == .active {
            // App is in foreground - don't show banner, just update badge
            // The in-app notification list will be updated via Firestore listener
            completionHandler([.badge])
        } else {
            // App is in background - show banner normally
            completionHandler([[.banner, .badge, .sound]])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Print message ID.
        if let messageID = userInfo["gcm.message_id"] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        // Handle deep link if present
        if let deepLink = userInfo["deepLink"] as? String {
            // Post notification to handle deep link navigation
            NotificationCenter.default.post(
                name: Foundation.Notification.Name("NotificationDeepLink"),
                object: nil,
                userInfo: ["deepLink": deepLink]
            )
        }
        
        // Track notification click
        if let notificationId = userInfo["notificationId"] as? String {
            // Track click in analytics
            Logger.info("Notification clicked: \(notificationId)", service: "AppDelegate")
        }
        
        completionHandler()
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Logger.info("APNS token received, setting on Messaging", service: "AppDelegate")
        
        // Set APNS token on Messaging FIRST
        // This must be done before FCM can generate a token
        Messaging.messaging().apnsToken = deviceToken
        apnsTokenSet = true
        
        // Now that APNS token is set, FCM token will be generated automatically
        // The didReceiveRegistrationToken delegate method will be called when it's ready
        // We can also explicitly request it if needed
        Messaging.messaging().token { token, error in
            if let error = error {
                Logger.error("Error fetching FCM registration token: \(error.localizedDescription)", service: "AppDelegate")
            } else if let token = token {
                Logger.info("FCM registration token fetched: \(token)", service: "AppDelegate")
            }
        }
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.error("Failed to register for remote notifications: \(error.localizedDescription)", service: "AppDelegate")
        Logger.error("Push notifications will not work until this is resolved", service: "AppDelegate")
    }
}
