(() => {
  "use strict";
  if (window.__lockdownScan) return;
  const found = new Map();
  const isMedia = /\.(m3u8|mpd|mp4|m4v|mov|webm|ogv)(?:$|[?#])/i;
  function send(url, type = "") {
    try {
      const absolute = new URL(url, document.baseURI);
      if (!/^https?:$/.test(absolute.protocol) || absolute.username || absolute.password) return;
      if (!isMedia.test(absolute.href) && !/^(video\/|application\/(vnd\.apple\.mpegurl|x-mpegurl|dash\+xml))/i.test(type)) return;
      if (found.size >= 150) return;
      found.set(absolute.href, type);
      window.webkit.messageHandlers.media.postMessage({url:absolute.href, type, page:location.href});
    } catch {}
  }
  window.__lockdownScan = () => {
    for (const video of document.querySelectorAll("video")) {
      send(video.currentSrc || video.src, "video/unknown");
      for (const source of video.querySelectorAll("source[src]")) send(source.src, source.type || "video/unknown");
    }
    for (const meta of document.querySelectorAll('meta[property^="og:video"],meta[name="twitter:player:stream"]')) send(meta.content);
    for (const entry of performance.getEntriesByType("resource")) send(entry.name);
    for (const script of document.scripts) {
      const text = script.textContent.slice(0,500000).replace(/\\\//g,"/").replace(/\\u0026/g,"&");
      for (const match of text.matchAll(/["']([^"'\s<>]+\.(?:m3u8|mpd|mp4|m4v|webm)(?:\?[^"'\s<>]*)?)["']/gi)) send(match[1]);
      if (script.type === "application/ld+json") {
        try {
          const walk = (item, depth = 0) => {
            if (!item || typeof item !== "object" || depth > 10) return;
            if (typeof item.contentUrl === "string") send(item.contentUrl, "video/unknown");
            for (const child of Object.values(item).slice(0,100)) walk(child,depth+1);
          };
          walk(JSON.parse(text));
        } catch {}
      }
    }
    for (const [url,type] of found) {
      try { window.webkit.messageHandlers.media.postMessage({url,type,page:location.href}); } catch {}
    }
  };
  window.open = () => null;
  const originalFetch = window.fetch;
  window.fetch = function(...args) {
    const result = Reflect.apply(originalFetch,this,args);
    result.then(response => send(response.url,response.headers.get("content-type") || "")).catch(()=>{});
    return result;
  };
  const originalOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(...args) {
    this.addEventListener("load",()=>send(this.responseURL,this.getResponseHeader("content-type") || ""),{once:true});
    return Reflect.apply(originalOpen,this,args);
  };
  try {
    new PerformanceObserver(list => {
      for (const entry of list.getEntries()) send(entry.name);
    }).observe({type:"resource",buffered:true});
  } catch {}
  let timer;
  const schedule = () => {
    clearTimeout(timer);
    timer = setTimeout(window.__lockdownScan,400);
  };
  document.addEventListener("loadedmetadata",schedule,true);
  document.addEventListener("play",schedule,true);
  document.addEventListener("DOMContentLoaded",()=>{
    new MutationObserver(schedule).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:["src"]});
    schedule();
  },{once:true});
  window.addEventListener("message",event=>{
    if(event.data === "__tabLockdownScanFrames") {
      window.__lockdownScan();
      for(let i=0;i<frames.length;i++) frames[i].postMessage("__tabLockdownScanFrames","*");
    }
  });
  window.addEventListener("pageshow",schedule);
})();
