const appUrl = new URL('./', self.location.href);

self.addEventListener('push', function (event) {
  let payload = { title: 'Second Brain', body: '' };
  try {
    if (event.data) payload = Object.assign(payload, event.data.json());
  } catch (error) {
    if (event.data) payload.body = event.data.text();
  }
  event.waitUntil(self.registration.showNotification(payload.title, {
    body: payload.body,
    icon: new URL('icons/Icon-192.png', appUrl).href,
    badge: new URL('icons/Icon-192.png', appUrl).href,
  }));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil((async function () {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const existing = windows.find(function (client) {
      const url = new URL(client.url);
      return url.origin === appUrl.origin && url.pathname.startsWith(appUrl.pathname);
    });
    return existing ? existing.focus() : self.clients.openWindow(appUrl.href);
  })());
});
