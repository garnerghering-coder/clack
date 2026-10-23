import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { AppShell } from './components/AppShell';
import { Splash } from './components/Brand';
import { TripsPage } from './pages/TripsPage';
import { PassportPage } from './pages/PassportPage';
import { SettingsPage } from './pages/SettingsPage';
import { AboutPage } from './pages/AboutPage';
import { PrivacyPage } from './pages/PrivacyPage';
import { AddTripPage } from './pages/AddTripPage';
import { JourneyPage } from './pages/JourneyPage';
import { StationsPage } from './pages/StationsPage';
import { BoardPage } from './pages/BoardPage';
import { LiveMapPage } from './pages/LiveMapPage';
import { StationMapPage } from './pages/StationMapPage';
import { TripDetailPage } from './pages/TripDetailPage';
import { SettingsProvider } from './settings';

/** Old links to the live map keep working (with their ?train=). */
function ToExplore() {
  const { search } = useLocation();
  return <Navigate to={`/explore${search}`} replace />;
}

export function App() {
  return (
    <SettingsProvider>
      <Splash />
      <BrowserRouter>
        <AppShell>
          <Routes>
            <Route path="/" element={<TripsPage />} />
            <Route path="/trips/:id" element={<TripDetailPage />} />
            <Route path="/journeys/:id" element={<JourneyPage />} />
            <Route path="/passport" element={<PassportPage />} />
            <Route path="/stations" element={<StationsPage />} />
            <Route path="/explore" element={<LiveMapPage />} />
            <Route path="/live" element={<ToExplore />} />
            <Route path="/stations/:id" element={<BoardPage />} />
            <Route path="/stations/:id/map" element={<StationMapPage />} />
            {/* Dev preview for checking hand edits: pick two platforms, see the path and time (ADDITIONS_01 C). */}
            {import.meta.env.DEV && <Route path="/dev/station/:id" element={<StationMapPage />} />}
            <Route path="/add" element={<AddTripPage />} />
            <Route path="/settings" element={<SettingsPage />} />
            <Route path="/about" element={<AboutPage />} />
            <Route path="/privacy" element={<PrivacyPage />} />
          </Routes>
        </AppShell>
      </BrowserRouter>
    </SettingsProvider>
  );
}
