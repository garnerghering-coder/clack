// All UI strings go through i18next. English and Swedish; English fills any gap.
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from './locales/en.json';
import sv from './locales/sv.json';

export const resources = { en: { translation: en }, sv: { translation: sv } } as const;

void i18n.use(initReactI18next).init({
  resources,
  lng: 'en',
  fallbackLng: 'en',
  interpolation: { escapeValue: false },
});

export default i18n;
