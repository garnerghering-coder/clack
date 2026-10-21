import { BrowserRouter, Route, Routes } from 'react-router-dom';
import { AppShell } from './components/AppShell';
import { TripsPage } from './pages/TripsPage';
import { PassportPage } from './pages/PassportPage';
import { SettingsPage } from './pages/SettingsPage';
import { AboutPage } from './pages/AboutPage';
import { AddTripPage } from './pages/AddTripPage';
import { JourneyPage } from './pages/JourneyPage';
import { StationsPage } from './pages/StationsPage';
import { BoardPage } from './pages/BoardPage';
import { TripDetailPage } from './pages/TripDetailPage';
import { SettingsProvider } from './settings';

export function App() {
  return (
    <SettingsProvider>
      <BrowserRouter>
        <AppShell>
          <Routes>
            <Route path="/" element={<TripsPage />} />
            <Route path="/trips/:id" element={<TripDetailPage />} />
            <Route path="/journeys/:id" element={<JourneyPage />} />
            <Route path="/passport" element={<PassportPage />} />
            <Route path="/stations" element={<StationsPage />} />
            <Route path="/stations/:id" element={<BoardPage />} />
            <Route path="/add" element={<AddTripPage />} />
            <Route path="/settings" element={<SettingsPage />} />
            <Route path="/about" element={<AboutPage />} />
          </Routes>
        </AppShell>
      </BrowserRouter>
    </SettingsProvider>
  );
}
