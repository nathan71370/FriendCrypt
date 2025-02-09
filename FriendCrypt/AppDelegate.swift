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

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Set UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request permission for alerts, sounds, and badges
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Notifications permission granted: \(granted)")
            if let error = error {
                print("Request permission error: \(error.localizedDescription)")
            }
        }
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        // Set Firebase Messaging delegate
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // Called when iOS successfully registers the device with APNs
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass APNs token to Firebase
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
        
        // Store the FCM token in Firestore under the current user's document
        storeFCMTokenInFirestore(fcmToken)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Called when a notification is delivered to a foreground app (iOS 10+)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            // Use .banner for iOS 14+, plus sound & badge
            completionHandler([.banner, .sound, .badge])
        } else {
            // Fall back to .alert for older iOS
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // Called when the user taps a notification (iOS 10+)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("User tapped notification: \(userInfo)")
        
        // Parse userInfo keys if needed, e.g. conversationId, friendRequestId, etc.
        
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
