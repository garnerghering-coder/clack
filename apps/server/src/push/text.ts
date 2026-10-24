// What the alerts say, in the two languages the app has. The phone isn't running when an alert is made, so the words
// are made here (the app's own strings live in its i18n files; these are only the notification texts). In English a
// platform is a name, "Platform 5", capitalised as on the app's cards and boards; in Swedish "spår 5" stays lower case
// inside a sentence, as Trafikverket writes it.
import type { Language } from '@clack/shared';

type Params = Record<string, string | number>;

const TEXT: Record<Language, Record<string, string>> = {
  en: {
    route: '{from} → {to}',
    reminderPlatform: 'Leaves {time} from Platform {platform}.',
    reminderNoPlatform: 'Leaves {time}. Platform not announced yet.',
    reminderLate: 'Leaves {time} ({delay} min late) from Platform {platform}.',
    reminderLateNoPlatform: 'Leaves {time} ({delay} min late). Platform not announced yet.',
    platformDepSet: 'Leaves from Platform {to}.',
    platformDepChanged: 'Platform changed to {to} (was {from}).',
    platformArrSet: 'Arrives at {station} on Platform {to}.',
    platformArrChanged: 'Now arriving at {station} on Platform {to} (was {from}).',
    delayed: '{delay} min late, now arriving {time}.',
    cancelledTitle: 'Cancelled: {from} → {to}',
    cancelled: 'This train is cancelled. Check the operator for other trains or replacement buses.',
    shortTurned: 'Some stops on this train are cancelled. Open Clack for the details.',
    getOff: 'Get off at {station} in about {min} min.',
    changeTitle: 'Change at {station}',
    changeBoth: 'Arrive on Platform {a}, leave from Platform {b}. {spare} min to spare.',
    changeArrOnly: 'Arrive on Platform {a}. {spare} min to spare.',
    changeDepOnly: 'Leave from Platform {b}. {spare} min to spare.',
    changeNone: '{spare} min to spare.',
    changeTight: 'Tight change at {station}',
    missTitle: 'You may miss your connection',
    miss: 'You arrive {late} min after the train to {to} leaves {station}.',
    connectionCancelled: 'Your next train to {to} is cancelled.',
    welcome: 'Welcome to {station}',
    welcomeBody: 'You arrived at {time}.',
  },
  sv: {
    route: '{from} → {to}',
    reminderPlatform: 'Avgår {time} från spår {platform}.',
    reminderNoPlatform: 'Avgår {time}. Spåret är inte meddelat än.',
    reminderLate: 'Avgår {time} ({delay} min försenat) från spår {platform}.',
    reminderLateNoPlatform: 'Avgår {time} ({delay} min försenat). Spåret är inte meddelat än.',
    platformDepSet: 'Avgår från spår {to}.',
    platformDepChanged: 'Spårändring: nu spår {to}, var {from}.',
    platformArrSet: 'Ankommer till {station} på spår {to}.',
    platformArrChanged: 'Spårändring vid ankomst i {station}: nu spår {to}, var {from}.',
    delayed: '{delay} min försenat, ankommer nu {time}.',
    cancelledTitle: 'Inställt: {from} → {to}',
    cancelled: 'Tåget är inställt. Kolla med operatören efter andra tåg eller ersättningsbussar.',
    shortTurned: 'Några stopp på tåget är inställda. Öppna Clack för detaljer.',
    getOff: 'Kliv av i {station} om cirka {min} min.',
    changeTitle: 'Byte i {station}',
    changeBoth: 'Kom på spår {a}, fortsätt från spår {b}. {spare} min till godo.',
    changeArrOnly: 'Kom på spår {a}. {spare} min till godo.',
    changeDepOnly: 'Fortsätt från spår {b}. {spare} min till godo.',
    changeNone: '{spare} min till godo.',
    changeTight: 'Snävt byte i {station}',
    missTitle: 'Du kan missa din anslutning',
    miss: 'Du kommer {late} min efter att tåget mot {to} avgått från {station}.',
    connectionCancelled: 'Ditt nästa tåg mot {to} är inställt.',
    welcome: 'Välkommen till {station}',
    welcomeBody: 'Du kom fram {time}.',
  },
};

export function t(lang: Language, key: string, params: Params = {}): string {
  const text = TEXT[lang]?.[key] ?? TEXT.en[key] ?? key;
  return text.replace(/\{(\w+)\}/g, (_, name: string) => (name in params ? String(params[name]) : `{${name}}`));
}

/** A time of day in the station's own zone, 24 h (the app's default clock). */
export function clock(ms: number, tz: string): string {
  return new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false, timeZone: tz }).format(new Date(ms));
}
