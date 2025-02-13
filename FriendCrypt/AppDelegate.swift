//
//  AppDelegate.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 09/02/2025.
//

import UIKit
import Firebase
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

extension Notification.Name {
    static let navigateToConversation = Notification.Name("navigateToConversation")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        FirebaseApp.configure()
        
        UNUserNotificationCenter.current().delegate = self
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Notifications permission granted: \(granted)")
            if let error = error {
                print("Request permission error: \(error.localizedDescription)")
            }
        }
        
        application.registerForRemoteNotifications()
        
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // Called when iOS successfully registers the device with APNs
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Called if registering with APNs fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - MessagingDelegate
    
    // Called when the FCM registration token is updated
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        print("FCM registration token: \(fcmToken)")
        
        storeFCMTokenInFirestore(fcmToken)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Called when a notification is delivered to a foreground app
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Called when the user taps a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("User tapped notification: \(userInfo)")
        
        if let conversationId = userInfo["conversationId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToConversation,
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
            
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                let idsToRemove = notifications.filter {
                    if let convoId = $0.request.content.userInfo["conversationId"] as? String {
                        return convoId == conversationId
                    }
                    return false
                }.map { $0.request.identifier }
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: idsToRemove)
            }
        }
        
        completionHandler()
    }
    
    // MARK: - Firestore Integration
    
    private func storeFCMTokenInFirestore(_ fcmToken: String) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUser.uid)
        
        userRef.updateData(["fcmToken": fcmToken]) { error in
            if let error = error {
                print("Error updating FCM token in Firestore: \(error.localizedDescription)")
            } else {
                print("FCM token updated successfully in Firestore.")
            }
        }
    }
}
