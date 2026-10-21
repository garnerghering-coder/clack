// On a laptop the app shows inside a phone-sized frame (owner request 2026-10-21), so it looks the way it will on a
// phone. The app runs in an iframe, which makes its own mobile layout apply exactly as on a real phone. The address
// bar follows the page inside, and "Full width" switches back to the desktop layout (remembered per browser).
import { useEffect, useRef, useState } from 'react';
import { Maximize2, Smartphone } from 'lucide-react';

const KEY = 'clack.layout';
export const PHONE = { width: 393, height: 852 };

export function readLayout(): 'phone' | 'full' {
  try {
    return localStorage.getItem(KEY) === 'full' ? 'full' : 'phone';
  } catch {
    return 'phone';
  }
}
export function setLayout(v: 'phone' | 'full') {
  try {
    localStorage.setItem(KEY, v);
  } catch {
    // Private mode: the choice just isn't remembered.
  }
  window.location.reload();
}

function useScale() {
  const fit = () => Math.min(1, (window.innerHeight - 72) / (PHONE.height + 24), (window.innerWidth - 32) / (PHONE.width + 24));
  const [scale, setScale] = useState(fit);
  useEffect(() => {
    const on = () => setScale(fit());
    window.addEventListener('resize', on);
    return () => window.removeEventListener('resize', on);
  }, []);
  return scale;
}

export function PhoneFrame() {
  const frame = useRef<HTMLIFrameElement>(null);
  const scale = useScale();
  const [src] = useState(() => window.location.pathname + window.location.search + window.location.hash);

  // Keep the address bar in step with the page inside, so reload and copy-link work.
  useEffect(() => {
    const t = setInterval(() => {
      try {
        const l = frame.current?.contentWindow?.location;
        if (!l) return;
        const inner = l.pathname + l.search + l.hash;
        if (inner !== window.location.pathname + window.location.search + window.location.hash) window.history.replaceState(null, '', inner);
        const title = frame.current?.contentDocument?.title;
        if (title && title !== document.title) document.title = title;
      } catch {
        // Not loaded yet.
      }
    }, 400);
    return () => clearInterval(t);
  }, []);

  return (
    <div className="phone-stage">
      <button className="phone-toggle" onClick={() => setLayout('full')} title="Use the full browser width">
        <Maximize2 size={16} /> Full width
      </button>
      <div className="phone-device" style={{ width: PHONE.width + 24, height: PHONE.height + 24, transform: `scale(${scale})` }}>
        <iframe ref={frame} className="phone-screen" src={src} title="Clack" width={PHONE.width} height={PHONE.height} allow="geolocation" />
      </div>
    </div>
  );
}

/** Small button shown in full-width mode on a laptop, to go back to the phone frame. */
export function PhoneViewButton() {
  return (
    <button className="phone-toggle floating" onClick={() => setLayout('phone')} title="Show the app in a phone-sized frame">
      <Smartphone size={16} /> Phone view
    </button>
  );
}
