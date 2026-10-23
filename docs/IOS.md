# Clack on iPhone: from this repository to the App Store

This guide assumes a Mac with nothing installed and no Xcode experience. Follow it top to bottom; each step says
exactly what to click or type. Commands go in **Terminal** (Applications > Utilities > Terminal): paste the line,
press Return, and wait until it finishes.

What to fix before submitting, and why, is in [APP_STORE.md](APP_STORE.md).

## The short answer: no rebuild, no Swift rewrite

Clack is a React web app (`apps/web`) plus a Node server (`apps/server`). For iPhone it's wrapped with
**Capacitor**, which puts the app inside a real native iOS app that Xcode builds and the App Store accepts. The
Xcode project is already in the repository: `apps/web/ios/App/App.xcodeproj`.

- **What stays as it is:** every screen, the maps, offline mode, Swedish and English. One codebase for web and iPhone.
- **What is Swift:** only the parts iOS requires to be native: the home-screen widget, the Live Activity (the
  train on the Lock Screen and in the Dynamic Island) and notifications. They're added to the same Xcode project
  as separate small Swift targets, and talk to the app through a thin bridge. See
  [Widgets, Live Activities and notifications](#widgets-live-activities-and-notifications).
- **Why not rewrite everything in Swift (SwiftUI)?** It would take months to reach today's features, and every
  later change would have to be made twice (web and iPhone). The App Store accepts apps built this way as long as
  they're more than a repackaged website (guideline 4.2). Clack is: offline trips, live maps and live tracking now,
  and widgets, Live Activities and notifications next.
- **The one real change:** the server must run somewhere public (step 9). On your laptop it serves only you; on
  phones it needs an https address.

## 1. What you need

- A Mac with Apple silicon (M1 or newer) and the latest macOS. Claude inside Xcode needs Apple silicon, and
  reportedly macOS 26 (Tahoe); Xcode itself installs on slightly older macOS too.
- About 60 GB of free disk space (Xcode with the iOS simulator is about 30 GB; Clack's data is about 6 GB).
- Your Apple ID.
- Your Claude account (Pro or Max) for Claude Code and Claude in Xcode.
- Later, for TestFlight and the App Store: the **Apple Developer Program**, USD 99 a year
  (developer.apple.com/programs/enroll). You don't need it to run the app on your own iPhone.

## 2. Install Xcode

1. Open the **App Store** app on the Mac, search **Xcode**, click **Get**. It's large; give it time.
2. Open Xcode once. Accept the license. When it asks which platforms to install, tick **iOS** (this downloads the
   iPhone simulator), then **Install**.
3. Xcode > **Settings** (Cmd+,) > **Accounts** > **+** > **Apple ID**, and sign in.
4. Quit Xcode.

## 3. Install Node.js

1. Go to **nodejs.org**, download the **LTS** installer for macOS (version 22 or newer), open it, and click through.
2. In Terminal, check it worked: `node -v` should print `v22…` or higher.

## 4. Get the code onto the Mac

The repository is private, so sign in to GitHub once. The easiest way is **GitHub Desktop**:

1. Download it from **desktop.github.com**, open it, and sign in with your GitHub account.
2. **File > Clone Repository** > **GitHub.com** tab > choose **garnerghering-coder/clack** > set **Local Path** to
   `/Users/<you>/Developer/clack` > **Clone**.
3. In Terminal, go to the project (do this every time you open a new Terminal window):

   ```
   cd ~/Developer/clack
   ```

## 5. Run Clack on the Mac (the version you know)

1. Install the project's packages (the first time, and after pulling changes):

   ```
   npm install
   ```

2. Create the secrets file. The API keys never go into GitHub. In Terminal:

   ```
   open -e .env
   ```

   If it says the file doesn't exist, run `touch .env` first. Paste your keys, one per line, and save:

   ```
   TRAFIKVERKET_API_KEY=your key
   TRAFIKLAB_GTFS_SWEDEN3_KEY=your key
   TRAFIKLAB_GTFS_SVERIGE2_KEY=your key
   ```

3. Start it:

   ```
   npm run dev
   ```

   The first start downloads timetables and maps (several GB, can take a while). Then open
   **http://localhost:5173** in Safari. Press **Ctrl+C** in Terminal to stop it.

## 6. Clack in the iPhone simulator

This first run uses the server on your Mac, so no hosting is needed yet.

1. Terminal window 1, start the server and the web app so other devices can reach them:

   ```
   npm run dev:phone
   ```

2. Terminal window 2 (Cmd+T), point the iOS app at it and open Xcode:

   ```
   cd ~/Developer/clack/apps/web
   CLACK_DEV_URL=http://localhost:5173 npx cap sync ios
   npx cap open ios
   ```

3. In Xcode, at the top middle, click the device menu and pick an iPhone simulator, e.g. **iPhone 17 Pro**.
4. Press **Cmd+R** (or the ▶ button). The simulator opens and Clack starts. The first build takes a few minutes.

## 7. Clack on your own iPhone

1. In Xcode's left sidebar, click **App** (the blue icon at the top). Under **TARGETS** choose **App**, then the
   **Signing & Capabilities** tab.
2. **Team**: choose your name (your Apple ID). **Bundle Identifier**: change `app.clack` to something unique to you,
   e.g. `com.<yourname>.clack`. Make the same change in `apps/web/capacitor.config.ts` (`appId`).
3. Connect the iPhone with a cable and unlock it. On the iPhone: **Settings > Privacy & Security > Developer Mode**
   on (it restarts).
4. Find your Mac's local name: **System Settings > General > Sharing**, at the bottom: **Local hostname**, e.g.
   `Garners-MacBook-Pro.local`. Then, in Terminal window 2:

   ```
   CLACK_DEV_URL=http://Garners-MacBook-Pro.local:5173 npx cap sync ios
   ```

   (Keep `npm run dev:phone` running in window 1; phone and Mac on the same Wi-Fi.)
5. In Xcode's device menu choose your iPhone, press **Cmd+R**. The first time, the iPhone asks you to trust the
   developer: **Settings > General > VPN & Device Management** > your Apple ID > **Trust**. Run again.

With a free Apple ID the app stops opening after 7 days; run it from Xcode again to renew. With the Developer Program
it lasts a year, and TestFlight installs (step 10) don't expire that way.

## 8. Keep building it, with Claude, from the Mac

From here on all development happens on your Mac; this cloud session isn't needed. The repository carries
everything Claude needs to know: `CLAUDE.md` (the standing rules: accuracy first, nothing made up, the design rules,
how commits are written) and the docs it points to.

There are two ways to work with Claude, and you can use both:

**A. Claude Code in Terminal: for anything in the project.** It works across the web app, the server, the data and
the Swift code, runs the tests, and commits and pushes.

1. Install it (once): in Terminal, `curl -fsSL https://claude.ai/install.sh | bash`, then open a new Terminal window.
2. Start it in the project: `cd ~/Developer/clack` then `claude`. Sign in with your Claude account the first time.
3. Let it see Xcode's builds and errors (once). Run
   `claude mcp add --transport stdio xcode -- xcrun mcpbridge`, then in Xcode open **Settings > Intelligence** and
   allow external agents (Model Context Protocol). Keep the project open in Xcode while you work.

**B. Claude inside Xcode: for the Swift parts** (widgets, Live Activities, notifications).

1. Xcode 26.3 or newer. On the Mac: **System Settings > Apple Intelligence & Siri**, turn it on.
2. Xcode > **Settings > Intelligence** > **Claude Agent** > **Get** > **Install**, and sign in with your Claude account.
3. Open the assistant in Xcode's coding panel and describe what you want.

**The everyday loop:**

- Change screens or styles: edit under `apps/web/src` (or ask Claude), check in Safari with `npm run dev`.
- Put the change in the iPhone app: `cd apps/web` then `npm run ios` (builds the web app for the phone and copies it
  into the Xcode project), then **Cmd+R** in Xcode.
- Swift changes (widgets and so on): edit in Xcode, **Cmd+R**.
- Save the work to GitHub: ask Claude Code to commit and push, or use GitHub Desktop.

## 9. Put the server online

Phones need the server at a public https address. This is the free route; a small paid server works the same way.

1. **A free server:** sign up for **Oracle Cloud Free Tier** (cloud.oracle.com). Create a compute instance: image
   **Ubuntu 24.04**, shape **Ampere A1 (Arm)** with at least 2 cores and 12 GB of memory (inside the free
   allowance). Add your SSH key when asked. In its network settings (**Security List**), allow incoming TCP ports
   **80** and **443**.
2. **A free name:** at **duckdns.org**, sign in, create a subdomain (e.g. `clack-garner.duckdns.org`), and set it to
   the server's public IP address.
3. **Log in to the server** from Terminal: `ssh ubuntu@<server ip>`. Then install Node and Caddy (Caddy fetches the
   https certificate by itself):

   ```
   curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs git caddy
   ```

4. **Get the code and secrets onto it** (GitHub will ask you to sign in; use a personal access token as the
   password):

   ```
   git clone https://github.com/garnerghering-coder/clack.git && cd clack && npm ci && nano .env
   ```

   Paste the same keys as in step 5, add `CLACK_ALLOWED_ORIGINS=capacitor://localhost`, save with Ctrl+O, Return,
   Ctrl+X. Then build the web pages (they serve the privacy page and the web version):
   `npm run build -w @clack/web`.

5. **Keep the server running** (restarts by itself after a crash or reboot):

   ```
   sudo tee /etc/systemd/system/clack.service >/dev/null <<'EOF'
   [Unit]
   Description=Clack server
   After=network-online.target
   [Service]
   User=ubuntu
   WorkingDirectory=/home/ubuntu/clack
   ExecStart=/usr/bin/npm start
   Restart=always
   [Install]
   WantedBy=multi-user.target
   EOF
   sudo systemctl enable --now clack
   ```

6. **https with Caddy** (replace the name with yours):

   ```
   sudo tee /etc/caddy/Caddyfile >/dev/null <<'EOF'
   clack-garner.duckdns.org {
     encode gzip
     handle /api/* {
       reverse_proxy 127.0.0.1:3001 {
         flush_interval -1
       }
     }
     handle {
       root * /home/ubuntu/clack/apps/web/dist
       try_files {path} /index.html
       file_server
     }
   }
   EOF
   sudo systemctl reload caddy
   ```

   Check it: `https://clack-garner.duckdns.org/api/health` in Safari shows `"ok":true` (the first start downloads
   data for a while), and `https://clack-garner.duckdns.org/privacy` shows the privacy page, which is your privacy
   policy URL for App Store Connect.

7. **Point the iPhone app at it**, on the Mac: open `apps/web/.env.ios`, set
   `VITE_API_BASE=https://clack-garner.duckdns.org` and `VITE_SUPPORT_EMAIL=` your support address. Then
   `cd apps/web && npm run ios` (without `CLACK_DEV_URL`), and **Cmd+R**. The app now works anywhere, without your Mac.

To update the server later: `ssh` in, then
`cd clack && git pull && npm ci && npm run build -w @clack/web && sudo systemctl restart clack`.

## 10. TestFlight: the real app on your phone (and friends')

Needs the Apple Developer Program.

1. **appstoreconnect.apple.com** > **Apps** > **+** > **New App**: platform iOS, your app name, language, the bundle
   id from step 7, SKU `clack`.
2. In Xcode's device menu choose **Any iOS Device (arm64)**. Menu **Product > Archive**. When the Organizer opens,
   **Distribute App** > **App Store Connect** > **Upload**, and accept the defaults.
3. After processing (10 to 30 minutes), in App Store Connect > your app > **TestFlight**, add yourself as an internal
   tester. Install the **TestFlight** app on the iPhone and open the invite.

For each new version, raise the **Build** number (target App > General), then archive and upload again.

## 11. Submit to the App Store

Fill in the listing and answers prepared in [APP_STORE.md](APP_STORE.md) (privacy label, age rating, screenshots,
review notes), choose the build, and click **Add for Review**. Review usually takes one to three days. If it's
rejected, the message names the guideline; ask Claude to fix it, upload a new build and reply in App Store Connect.

## Widgets, Live Activities and notifications

All three are native iOS features, built in Swift inside the same Xcode project. Plan, in order:

1. **Notifications (local first).** Departure reminders and "your platform changed" while the app is open or just
   closed, with Capacitor's Local Notifications plugin. No server changes. Good first step.
2. **Push notifications** for delays and cancellations when the app is closed. Needs:
   - an **APNs key** (Apple Developer > Keys > +, enable Apple Push Notifications service; download the .p8 file once
     and keep it like a password: it goes in the server's `.env`);
   - the **Push Notifications** capability (Xcode > Signing & Capabilities > + Capability);
   - the app sending its push token to the server;
   - the server sending a push when its live tracker sees a change. The tracker already detects these.
3. **Live Activity** for the train you're on: the Lock Screen and Dynamic Island show the next stop, delay and
   platform, updated by push from the server (ActivityKit). Needs a **Widget Extension** target (Xcode >
   File > New > Target > Widget Extension, tick "Include Live Activity") and a small bridge so the app can start
   it. It reuses the push setup from 2.
4. **Home-screen widget**: your next trip, or a station's departures. Same Widget Extension; the app shares data
   with it through an **App Group** (Signing & Capabilities > + App Groups).

Guidelines to keep in mind: widgets and notifications must relate to the app (2.5.16); the app must work without
push permission (4.5.4); no marketing pushes without opt-in.
