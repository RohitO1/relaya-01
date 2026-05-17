// Firebase Cloud Messaging Service Worker
// This file is required by Firebase Messaging for web push notifications.
// Since this app targets Android/iOS primarily, this is a minimal stub
// to prevent the "unsupported MIME type" error when running on web.

importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

// Initialize Firebase — these dummy values suppress the registration error.
// Replace with real values if web push notifications are needed in future.
firebase.initializeApp({
  apiKey: 'dummy-api-key-web',
  authDomain: 'meetra-mock-project.firebaseapp.com',
  projectId: 'meetra-mock-project',
  storageBucket: 'meetra-mock-project.appspot.com',
  messagingSenderId: '1234567890',
  appId: '1:1234567890:web:abcdef123456',
});

// Retrieve an instance of Firebase Messaging so it can handle background messages.
const messaging = firebase.messaging();

// Optional: handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title ?? 'Meetra';
  const notificationOptions = {
    body: payload.notification?.body ?? '',
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
