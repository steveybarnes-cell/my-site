/* =====================================================================
   MY Site — crew app service worker.

   Its whole job is to make the app open when there is no signal. It does
   NOT cache data: everything a man sees comes from the app's own local
   copy, written by the page. A service worker caching PostgREST replies
   would be a second, invisible store of company data with none of the
   rules the first one has, and it would go stale in a way nobody could
   see or clear.

   So: the shell is cached, and every request to Supabase goes to the
   network or fails honestly and lets the page's queue deal with it.
   ===================================================================== */

"use strict";

/* Bump this on every deploy. It is the only thing that evicts an old
   shell — a crew phone that never clears its cache will otherwise run
   last month's app for as long as it stays installed. */
const CACHE = "mysite-crew-v2";

const SHELL = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icon-192.png",
  "./icon-512.png",
  "./icon-maskable-512.png"
];

self.addEventListener("install", event => {
  // Take over straight away rather than waiting for every tab to close.
  // A tradesman does not close tabs.
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE).then(c => c.addAll(SHELL)).catch(() => {
      /* A missing file must not stop the worker installing — an app that
         won't install because one icon 404'd is worse than one icon. */
    })
  );
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  const req = event.request;

  // Anything that isn't a plain GET of our own shell is none of our
  // business. Supabase calls in particular go straight past.
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  // Navigations: network first so a deployed fix arrives, cache second so
  // a basement still opens the app.
  if (req.mode === "navigate") {
    event.respondWith(
      fetch(req)
        .then(res => {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put("./index.html", copy));
          return res;
        })
        .catch(() => caches.match("./index.html").then(r => r || caches.match("./")))
    );
    return;
  }

  // Everything else in the shell: cache first, it never changes within a
  // version.
  event.respondWith(
    caches.match(req).then(hit => hit || fetch(req).then(res => {
      if (res && res.status === 200 && res.type === "basic") {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(req, copy));
      }
      return res;
    }))
  );
});

/* The page asks for a flush when it comes back online and when it is
   reopened. Background Sync would be nicer and is not on iOS Safari at
   all, so the page's own online listener is the thing that has to work. */
self.addEventListener("message", event => {
  if (event.data === "skipWaiting") self.skipWaiting();
});
