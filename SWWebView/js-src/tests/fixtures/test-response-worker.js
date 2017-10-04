self.addEventListener("fetch", e => {
    let requestURL = new URL(e.request.url);
    // console.log(requestURL.searchParams.);

    let responseJSON = {
        success: true,
        queryValue: requestURL.searchParams.get("test")
    };

    let response = new Response(JSON.stringify(responseJSON), {
        headers: {
            "content-type": "application/json"
        }
    });

    e.respondWith(response);
});

self.addEventListener("install", e => {
    self.skipWaiting();
});

self.addEventListener("activate", e => {
    e.waitUntil(self.clients.claim());
});
