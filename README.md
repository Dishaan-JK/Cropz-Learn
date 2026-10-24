# Lumi Learning Workspace

Lumi is a local learning workspace for collecting notes and turning them into
study materials. This repository contains the React web interface. In the
single-executable Linux build, the interface and Lumi's Dart/Genkit service are
packaged together, so learners can use the app without installing Node.js, Dart,
or this source repository.

## What you can do

- Create and organize notes in folders.
- Arrange and connect notes on a visual Canvas.
- Browse saved learning artifacts, including quizzes and flashcards, and review
  or take supported activities.
- Chat with the Lumi Coach when an AI provider is configured.
- Adjust appearance and workspace settings, including dark mode and panel
  widths.

The app runs its local service on loopback and stores workspace data on the
computer where it runs. In the packaged app, data is saved under
`$XDG_DATA_HOME/lumi`, or `~/.local/share/lumi` when `XDG_DATA_HOME` is not set.
Set `LUMI_DATA_DIR` to use a different location. AI provider credentials are
managed by the local service and are not put into the browser bundle.

## Linux desktop support

The available packaged executable targets **Linux x86_64** and requires **glibc
2.39 or newer**. It is suitable for 64-bit Intel/AMD Linux systems whose installed
glibc meets that requirement. The executable does not currently target ARM64,
32-bit Linux, Windows, or macOS.

The runtime preparation script recognizes these distro families:

| Distro family | Examples |
| --- | --- |
| Debian based | Debian, Ubuntu, Linux Mint, Pop!_OS, Elementary OS, Zorin OS, Kali |
| Fedora/RHEL based | Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux |
| Arch based | Arch Linux, Manjaro, EndeavourOS, Omarchy |
| SUSE based | openSUSE |
| Other supported package managers | Void Linux, Gentoo |

These names indicate package-manager support, not that every release of each
distro is compatible. Check the installed glibc version: older releases may
fall below 2.39. The included helper checks this and can update glibc through
the distro package manager where configured. If the distro repositories do not
provide a new enough version, upgrade the distro to a compatible release.

Alpine Linux uses musl instead of glibc and is not compatible with this build.
Other distributions may work if they provide x86_64, glibc 2.39 or newer, and
the shared libraries reported by `ldd`. On unsupported distributions, run the
runtime check and install manually only if it passes.

## Install and run the packaged app

The repository does not currently publish a hosted download. Get the
`lumi-linux-x64` executable and `prepare-linux-runtime.sh` from a Lumi release
bundle or from whoever provided the build. On the target computer, open a
terminal in the folder containing those files and:

```bash
chmod +x lumi-linux-x64 prepare-linux-runtime.sh
LUMI_EXECUTABLE="$PWD/lumi-linux-x64" ./prepare-linux-runtime.sh
./lumi-linux-x64
```

The helper may request administrator access to install or update runtime
packages. It does not install a web browser; Lumi opens your default browser
when possible and prints its local address in the terminal. If no browser opens,
copy that address (usually `http://127.0.0.1:<port>/`) into a browser on the same
computer. Keep the terminal open while using Lumi; press **Ctrl+C** there to
stop it.

The helper updates only the needed runtime package on most supported systems.
Arch-family systems require a full synchronized `pacman -Syu` update because
Arch does not support partial upgrades. Review package-manager output before
proceeding. The helper will not attempt to upgrade the distribution itself.

### Where your data lives

By default, Lumi saves workspace data in:

```text
~/.local/share/lumi
```

To choose another directory for one launch:

```bash
LUMI_DATA_DIR="$HOME/Documents/LumiData" ./lumi-linux-x64
```

Back up this directory before removing it. Deleting it removes the local Lumi
workspace and its settings.

## Connect Google Gemini (API key example)

Lumi can use Google Gemini, OpenAI, Anthropic, an OpenAI-compatible API, or a
local Ollama service. This walkthrough uses Google Gemini.

### 1. Create a Gemini API key

1. Sign in to [Google AI Studio](https://aistudio.google.com/) with your Google
   account and open its [API keys page](https://aistudio.google.com/apikey).
2. Create a key for a project, following Google's prompts for project access
   and any applicable API terms or billing setup.
3. Copy the key and keep it in a password manager or another private place.
   Treat it like a password: do not post it, share it, or put it in a screenshot
   or source file. Google explains key creation and restrictions in its
   [Gemini API key guide](https://ai.google.dev/gemini-api/docs/api-key).

### 2. Add and test it in Lumi

1. Open Lumi and go to **Settings → AI & models**.
2. Choose **Google Gemini** from **Provider**.
3. Paste the key into **API key**. Lumi contacts Google's model-list endpoint
   and displays the models available to that key; choose one from **Model**.
4. Select **Test connection**. When the test succeeds, select **Save
   connection**. Lumi clears the key from the input after saving. To keep the
   key already saved for Gemini, leave the field blank.

The provider screen uses Google's standard Gemini endpoint, so there is no API
base URL to enter. Available models and access depend on Google's current API,
project, region, account, and quota settings. Check your Google AI Studio usage
and billing pages for the terms that apply to your project.

### 3. How Lumi handles the key and connection

- The web page sends the key to Lumi's service on the same computer through its
  loopback address. The key is not sent to a Lumi-hosted server.
- Lumi's local service makes the Gemini model-list and model requests to
  Google's HTTPS API. The key is sent in the API request, not placed in the
  page's source code or URL.
- When saved, the key is stored by the local service in
  `provider-settings.json` under Lumi's data directory. On Linux, the data
  directory is restricted to the current user, and the settings file is
  written with owner-only permissions. The service does not return the key to
  the web page; Settings only learns whether a key is configured. Workspace
  exports exclude provider credentials.
- The local browser-to-service hop uses loopback HTTP, not TLS. Keep Lumi on
  your own computer and do not expose its local service port to a network or
  the public internet. The outgoing Gemini connection uses HTTPS.

Restrict the key to the Gemini API in Google AI Studio when that control is
available, and monitor the project's usage and quota. If the key is exposed,
revoke it in AI Studio, create a replacement, enter it in Lumi, test it, and
save the new connection. These controls follow Google's
[Gemini API key security guidance](https://ai.google.dev/gemini-api/docs/api-key).

## Run from source (developers)

The web client requires Node.js and npm. The full local app also requires the
sibling `Learning-App` checkout with its Dart/Genkit service configured. From
this repository:

```bash
npm ci
npm run dev:full
```

See [BACKEND.md](BACKEND.md) for backend paths, ports, and local API setup. To
build the Linux x86_64 single executable, install Rust and prepare the sibling
backend checkout, then run:

```bash
npm run bundle:single
```

The build output is `release/lumi-linux-x64`. Build it on Linux x86_64; the
current bundler does not cross-compile other operating systems or CPU
architectures. For front-end-only development, use `npm run dev` with a Lumi
backend already running at `http://127.0.0.1:8080`.

## Developer checks

```bash
npm run lint
npx vitest run
npm run build
npm run test:e2e:chrome
```

The Chrome end-to-end workflow is described in [BACKEND.md](BACKEND.md).

## Project notes

- [ChangeLog.md](ChangeLog.md) records project changes.
- [BACKEND.md](BACKEND.md) explains the React-to-Dart service connection.
- [PROJECT_PLAN.md](PROJECT_PLAN.md) tracks project scope and direction.

The [Lumi React Workspace canvas](https://superdesign.dev/teams/a4c9d57a-42d9-4578-8e2e-a8209329992f/projects/f6b6afec-4846-449e-b392-21418bc6047b) is a design reference; its generated HTML is not used at runtime.

## Focus mode

Open **Focus mode → Create Timer**, choose 1–240 minutes and an optional study
intention, then start. The countdown appears in the Focus tab and in a floating
widget at the top center of every workspace page. Drag its handle (or focus the
handle and use arrow keys) to move it; the reset-position button centers it
again. Pause/resume works from either surface. Return to the Focus tab and use
**Switch off timer** to end early. Pausing keeps focus protection enabled.

Forest study, Quiet night, and Warm sand temporarily theme the whole app while
the timer is running or paused. A contrasting shadow outlines the app edges
(dark on light themes, light on Quiet night). Saved appearance preferences are
not changed; the usual workspace theme returns on switch-off or expiry. The timer and Focus theme are stored
in this browser's local storage; a deadline keeps the countdown accurate after
background throttling and reload. Open tabs on the same origin synchronize timer
changes. Clearing browser storage removes this state; it is not synced through
the Dart workspace service.

Ask Coach, for example, **“Start a 25 minute focus timer for biology.”** The client
advertises a browser action to the existing assistant and validates its completed
response against a unique request ID, duration bounds, and supported themes.
Only the completed current reply can start a timer; restored conversations never
execute actions. An unfinished timer is never automatically replaced. This is a
client-side action bridge, not a new Dart/Genkit server tool. The configured model
must follow the action protocol; live-provider behavior is not guaranteed by the
mocked integration tests. Starting a timer manually requests fullscreen through the Fullscreen API.
Coach-created or restored sessions offer **Enter fullscreen** in the floating
widget because the browser requires a fresh student click.

While a session is active, links that leave the current document are intercepted
with a reminder to switch off the timer in Focus mode. Reload/close attempts use
the browser's standard confirmation where supported. Tab visibility and
fullscreen exits show a reminder when the student returns. Fullscreen
can also be requested from the Focus tab or floating widget. Browsers always retain
Esc, tab switching, browser controls, and OS app switching: **a website cannot
block other applications or force the student to stay**. Device-level enforcement
would require a separately installed, authorized native/kiosk integration.

When the timer expires, an in-app modal announces **Your time is over.** and
offers **End Focus Session**. The usual theme returns immediately at expiry;
the button dismisses the popup, clears the timer, and exits fullscreen. Esc in
the completion popup also ends the session. An expired session restored after
a reload shows the same popup until acknowledged.


Coach stores the exact Student prompt in message metadata so restored **You**
messages show the request, while attached note/Canvas context stays available to
the model. Older context-wrapped messages have a compatibility reader. Tool
exchanges and marked reasoning are excluded from the visible transcript. A
completed Coach turn refreshes workspace queries so created note cards display
the saved title and content immediately.

The sibling Dart backend provides **createWorkspaceNote** for standalone notes,
rejects empty agent-created note drafts, and checks the original Student prompt
before allowing a new Canvas. Restart the backend after updating these server
files; refreshing the React page alone does not reload Dart agent definitions.
