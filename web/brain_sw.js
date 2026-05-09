// Second Brain — Service Worker for notification handling and local reminders.
// Registered alongside Flutter's own service worker.

// Track reminders scheduled for local notifications
const scheduledReminders = new Set();

/**
 * Handle notification clicks: refocus the tab or open the app.
 */
self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then(function (clientList) {
        for (const client of clientList) {
          if ('focus' in client) return client.focus();
        }
        if (clients.openWindow) return clients.openWindow('/');
      })
  );
});

/**
 * Handle notification close (optional cleanup).
 */
self.addEventListener('notificationclose', function (event) {
  // Could track dismissed notifications here if needed
});

/**
 * Periodic background task: check for due reminders and notify.
 * (Note: PWA background sync requires a registered sync event)
 */
self.addEventListener('sync', function (event) {
  if (event.tag === 'check-reminders') {
    event.waitUntil(
      (async () => {
        try {
          // Fetch reminder check from the app (would need a dedicated endpoint)
          // For now, this is a placeholder for future server-side push support.
        } catch (error) {
          console.error('Background sync failed:', error);
        }
      })()
    );
  }
});
