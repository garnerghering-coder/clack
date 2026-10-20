import { BrowserRouter, Route, Routes } from 'react-router-dom';
import { TabBar } from './components/TabBar';
import { TripsPage } from './pages/TripsPage';
import { PassportPage } from './pages/PassportPage';
import { SettingsPage } from './pages/SettingsPage';
import { AboutPage } from './pages/AboutPage';
import { SettingsProvider } from './settings';

export function App() {
  return (
    <SettingsProvider>
      <BrowserRouter>
        <div className="shell">
          <Routes>
            <Route path="/" element={<TripsPage />} />
            <Route path="/passport" element={<PassportPage />} />
            <Route path="/settings" element={<SettingsPage />} />
            <Route path="/about" element={<AboutPage />} />
          </Routes>
          <TabBar />
        </div>
      </BrowserRouter>
    </SettingsProvider>
  );
}
