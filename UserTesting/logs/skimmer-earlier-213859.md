# The Skimmer — user test log

## 1. Persona + device + settings
The Skimmer, 24, Malmö. iPhone 18 Pro Max simulator (iOS 27.2), light mode, default text size, locale en_SE. Fresh install (simulator erased). Patience: 45 s per goal.

## 2. First 30 seconds
Before tapping: a friend said "it's like Flighty for trains", so I expected a big card with my next train on it, or a big "Add trip" button, and a map somewhere. Something colourful.

What I got (00-first-launch.png): a dark screen that says "Trips" with a yellow "Upcoming / Past" toggle, a red box saying "Couldn't load your trips. Retry", a tiny grey "No connection · showing saved data" chip at the very top, a "+" and a cog. Tabs at the bottom: Trips, Explore, Passport.

Two things straight away:
- My phone is in light mode and this app is black. Didn't ask for that. Not a dealbreaker, but it looks like a different phone.
- First thing I ever see is a red error. I have wifi. I've not done anything yet and it's already telling me something's broken. "Showing saved data" — what saved data, I just installed it. Instagram never opens on a red box.
- "Passport"? No idea. Not reading into it.

The "+" top right is where I'd go to add a train. Yellow "Upcoming" is already lit so nothing to do there.

## 3. Goals

### Goal 1 — I've got a train tomorrow, put it in so the app tells me if it's late

(21:32:14 start)

> LOOKING FOR: a way to add tomorrow's train. EXPECT IT AT: the "+" top right, because every list app (Reminders, Calendar) puts add there. DOING: tap "+". EXPECT: a form or search where I type where I'm going.

> GOT: a sheet "Plan a journey" with Today / Tomorrow / Pick date chips, a search box "Train number, route, or operator", and three suggestion chips: "SJ 523", "Stockholm → Göteborg", "Snälltåget Stockholm Malmö". "Popular stations" heading with nothing under it. (iOS keyboard tip popped over the bottom half, not the app's fault.) 01-tap-plus.png. MATCH: yes. FRICTION: 1. GUT: okay, that's the right screen, and it already guessed where I'm going. Good.

Now I want Tomorrow, then I'm hitting that Stockholm → Göteborg chip because it's literally my trip.

> LOOKING FOR: set it to tomorrow and pick my route. EXPECT IT AT: the "Tomorrow" chip, then the Stockholm → Göteborg chip (Flighty-ish quick picks). DOING: tap Continue on the keyboard tip, tap "Tomorrow", tap "Stockholm → Göteborg". EXPECT: a list of trains tomorrow Stockholm to Göteborg, and I find the 08:14.

> GOT: Tomorrow lit up yellow, the chip's text went into the search box, two grey loading blocks for a second (02-tomorrow-route.png), then: "Stations" (Göteborg C, Göteborg Sävenäs — with Swedish flags), then "18 journeys", "Filters", "Show earlier", and a list of trains starting 05:47 → 09:47 "Direct", "421 421". Keyboard still covering the bottom half (03-route-results.png). MATCH: partial. FRICTION: 2. GUT: why are there stations on top of my train list? I typed a route, not a station. And why is the keyboard still up, I'm done typing. Also "421 421"? And there's a little "?" next to it instead of a logo.

Wait. 421 is my train, but my ticket says 08:14 and this says 05:47. Is this tomorrow? It says Tomorrow. Whatever, I'll look for 08:14.

> LOOKING FOR: the 08:14 train in the list. EXPECT IT AT: further down, after the 05:47 / 06:08 / 06:55 ones (list is in time order like SJ's app). DOING: tap the keyboard's search key to get rid of it, then scroll up. EXPECT: list in time order, 08:14 a couple of cards down.

> GOT: keyboard gone, list scrolled. Trains at 07:53, 08:31, 08:47, 09:29, 10:14, 11:52, 12:14… No 08:14. Every train has a yellow "?" square where I'd expect an SJ logo, and the number is printed twice ("429 429", "169 169"). Some say "MTRX" — that's the other company, fine. 04-scrolled-list.png. MATCH: no. FRICTION: 3. GUT: my ticket says 08:14, train 421. This app says 421 leaves 05:47 and there's nothing at 08:14. Who's wrong, me or the app? Also what's with the "?" — does it not know what SJ is?

I'm not scrolling through 18 things. I'll just type the number on my ticket.

> LOOKING FOR: my train by number. EXPECT IT AT: the search box, because it literally says "Train number". DOING: scroll back up, tap the box, clear it, type 421. EXPECT: one result, train 421, tomorrow, and I tap it and I'm done.
