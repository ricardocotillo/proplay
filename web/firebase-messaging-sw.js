// Web push: Firebase Cloud Messaging service worker. It shows notifications
// that arrive while no ProPlay tab is open. The `notification` payload is
// displayed by the SDK; a click opens `webpush.fcmOptions.link` (set by the
// functions in functions/src/notify.ts). Config values are public (same as
// lib/firebase_options.dart, web).
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDx2LiCpYNYKxlrDTXS5q9OsfQDp_Zq3ZM',
  appId: '1:979151294493:web:2c32870c48b7d64020f6f4',
  messagingSenderId: '979151294493',
  projectId: 'proplay-eac23',
});

firebase.messaging();
