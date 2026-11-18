(() => {
  // Installed at document start in every frame. Keep window.open unchanged:
  // replacing it can trigger player sandbox detection. Native navigation and
  // UI delegates reject popup requests without modifying player APIs.
  const channel = '__CHANNEL__';
  function send(kind, value) {
    window.webkit?.messageHandlers?.tv?.postMessage({kind, value});
  }
  // Report the capabilities used by the provider's sandbox check. Do not
  // impersonate browser APIs or suppress genuine origin/storage restrictions.
  if (window.location?.hostname === 'embedse.com' && window !== top) {
    const failures = [];
    try {
      if (window.origin === 'null' || window.location.origin === 'null') failures.push('opaque origin');
      void window.localStorage;
    } catch { failures.push('storage unavailable'); }
    try {
      if (typeof window.navigator?.serviceWorker?.getRegistration !== 'function') failures.push('service workers unavailable');
    } catch { failures.push('service workers unavailable'); }
    if (failures.length) send('compatibility', 'Player compatibility: ' + failures.join(', ') + '.');
  }
  function act(data) {
    const x = data.x * innerWidth, y = data.y * innerHeight;
    let element = document.elementFromPoint(x, y);
    while (element?.shadowRoot) {
      const child = element.shadowRoot.elementFromPoint(x, y);
      if (!child || child === element) break;
      element = child;
    }
    if (!element) return;
    if (element.tagName === 'IFRAME') {
      const r = element.getBoundingClientRect();
      element.contentWindow?.postMessage({...data, channel,
        x: (x - r.left - element.clientLeft) / element.clientWidth,
        y: (y - r.top - element.clientTop) / element.clientHeight}, '*');
      return;
    }
    if (data.kind === 'scroll') {
      let container = element;
      while (container && container !== document.documentElement) {
        if (container.scrollHeight > container.clientHeight &&
            /auto|scroll/.test(getComputedStyle(container).overflowY)) {
          container.scrollBy(data.dx, data.dy); return;
        }
        container = container.parentElement;
      }
      window.scrollBy(data.dx, data.dy); return;
    }
    if (data.kind === 'click') {
      element.focus?.({preventScroll: true});
      for (const type of ['mousedown', 'mouseup']) element.dispatchEvent(new MouseEvent(type,
        {bubbles: true, cancelable: true, clientX: x, clientY: y, view: window}));
      element.click?.();
    }
    if (data.kind === 'video') {
      const video = element.closest?.('video') || document.querySelector('video');
      const src = video?.currentSrc || video?.src;
      if (src && /^https?:/.test(src)) { video.pause(); send('video', src); }
      else send('notice', 'No direct video URL here. Start the embedded player first; blob/DRM video cannot be handed to the native player.');
    }
  }
  window.addEventListener('message', e => {
    if (e.source === parent && e.data?.channel === channel && window !== top) act(e.data);
  });
  Object.defineProperty(window, '__tvAct', {value: act, configurable: false, writable: false});
})();
