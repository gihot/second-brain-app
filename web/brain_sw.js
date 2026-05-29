// Second Brain — Service Worker for Web Push notifications.
// Registered alongside Flutter's own service worker.

/**
 * Push handler (Notifications Phase 1): zeigt eine Notification aus dem
 * vom Server gepushten Payload {title, body, url}. Feuert auch bei
 * geschlossener App — das ist der ganze Punkt gegenüber der alten
 * client-seitigen web.Notification.
 */
self.addEventListener('push', function (event) {
  let payload = { title: 'Second Brain', body: '', url: '/' };
  try {
    if (event.data) payload = Object.assign(payload, event.data.json());
  } catch (e) {
    if (event.data) payload.body = event.data.text();
  }
  event.waitUntil(
    self.registration.showNotification(payload.title, {
      body: payload.body,
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      data: { url: payload.url || '/' },
    })
  );
});

/**
 * Notification-Klick: bestehenden Tab fokussieren oder App an der vom
 * Push mitgegebenen URL öffnen.
 */
self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  const targetUrl =
    (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then(function (clientList) {
        for (const client of clientList) {
          if ('focus' in client) return client.focus();
        }
        if (clients.openWindow) return clients.openWindow(targetUrl);
      })
  );
});
