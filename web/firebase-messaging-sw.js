importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAX0KvXWPCLNL_x0YZvYMRCXjUpUi5XGcg",
  authDomain: "podsafe-92a3e.firebaseapp.com",
  projectId: "podsafe-92a3e",
  storageBucket: "podsafe-92a3e.firebasestorage.app",
  messagingSenderId: "1060052430944",
  appId: "1:1060052430944:web:c8c3dceb8dd39e3a45fe6f",
  measurementId: "G-CFBWRQYJ88"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);
  
  const notificationTitle = payload.notification?.title || 'New Notification';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification clicked:', event);
  event.notification.close();

  // Open the app
  event.waitUntil(
    clients.openWindow('/')
  );
});
