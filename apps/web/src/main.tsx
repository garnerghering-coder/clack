import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@fontsource-variable/inter';
import '@fontsource/space-grotesk/600.css';
import '@fontsource/space-grotesk/700.css';
import './i18n';
import './styles.css';
import { App } from './App';
import { PhoneFrame, PhoneViewButton, readLayout } from './PhoneFrame';
import { watchTheme } from './theme';

watchTheme();

// Inside the phone frame (an iframe) the app renders normally; on a wide screen the top window shows the frame.
const inFrame = window.self !== window.top;
const wide = window.matchMedia('(min-width: 700px)').matches;
const layout = readLayout();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {!inFrame && wide && layout === 'phone' ? (
      <PhoneFrame />
    ) : (
      <>
        <App />
        {!inFrame && wide && <PhoneViewButton />}
      </>
    )}
  </StrictMode>,
);
