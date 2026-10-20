import { BrowserRouter, Route, Routes, useLocation } from 'react-router-dom';
import { TabBar } from './components/TabBar';
import { MapBackdrop } from './components/MapBackdrop';
import { TripsPage } from './pages/TripsPage';
import { PassportPage } from './pages/PassportPage';
import { SettingsPage } from './pages/SettingsPage';
import { AboutPage } from './pages/AboutPage';
import { AddTripPage } from './pages/AddTripPage';
import { SettingsProvider } from './settings';

/** Flighty shows the floating tab bar on the main screens only; Add, Settings and About are full-height sheets. */
function Chrome() {
  const { pathname } = useLocation();
  return pathname === '/' || pathname === '/passport' ? <TabBar /> : null;
}

export function App() {
  return (
    <SettingsProvider>
      <BrowserRouter>
        <div className="shell">
          <MapBackdrop />
          <Routes>
            <Route path="/" element={<TripsPage />} />
            <Route path="/passport" element={<PassportPage />} />
            <Route path="/add" element={<AddTripPage />} />
            <Route path="/settings" element={<SettingsPage />} />
            <Route path="/about" element={<AboutPage />} />
          </Routes>
          <Chrome />
        </div>
      </BrowserRouter>
    </SettingsProvider>
  );
}
