# SideStore on iPad — common errors and how to fix them

This repo contains the current SideStore development source (version 0.6.4-dev),
which already includes bug fixes that are newer than the v0.6.3 release most
people have installed. Before changing any code, work through this list —
almost every SideStore error on iPad is caused by setup/pairing issues rather
than a bug in the app itself.

## 0. "Failed to refresh SideStore — the data isn't in the right format"

This one is **not** a problem with your iPad, your pairing file, or your VPN.
It means the **anisette server** SideStore picked handed back something that
isn't JSON — usually an HTML error page, a Cloudflare challenge, or a "domain
parked" page — and SideStore reported the raw parser failure instead of naming
the real cause. That's why there's no error code and no extra detail.

**Fix right now (on stock SideStore v0.6.3):**
1. SideStore → Settings → **Anisette Servers**.
2. Tap **Refresh Servers** to re-pull the server list.
3. Pick a **different server** from the list.
4. Try refreshing again. Repeat with another server if it fails — several
   public servers are usually offline at any given time.

**What this repo changes.** `AltStore/Operations/FetchAnisetteDataOperation.swift`
had three separate faults behind this message, all fixed here:

- Servers were accepted on HTTP status alone, so anything returning `200` with
  an HTML body passed the health check and only blew up later. Servers are now
  accepted only if an endpoint SideStore actually uses answers with **JSON**.
- If a server was unreachable, the thrown network error escaped the
  try-each-server loop, so the **remaining servers were never tried**. Probing
  now never throws, so a dead server just moves on to the next one.
- The two raw `JSONSerialization` calls threw Foundation's generic error
  verbatim. They now report which server failed, at which endpoint, the HTTP
  status, the content type, and the first 200 bytes of what came back.

So instead of "the data is not in the right format", a failure now reads more
like: *Anisette server https://example.com sent a response that isn't valid
JSON at v3/client_info. HTTP status 200. Content-Type: text/html. Response
started with: `<!DOCTYPE html>`…* — and in most cases it won't fail at all,
because a bad server is now skipped automatically.

## 0b. "Minimuxer.IdeviceGatewayError 1" when installing an app

### What the code actually means

That string is not the error message — it's SideStore's error *code label*.
`Error.localizedErrorCode` (`Shared/Extensions/NSError+AltStore.swift:267`)
formats any error as `"<domain> <code>"`, so you're seeing the domain and the
number, while the real sentence is displayed separately.

Decoding it:

- **Domain `Minimuxer.IdeviceGatewayError`** — the error came from minimuxer's
  `IdeviceGateway` (`Dependencies/minimuxer/Sources/IdeviceGateway.swift`),
  the layer that talks to your iPad's own lockdownd over the LocalDev tunnel.
- **Code `1`** — Swift bridges a plain enum to `NSError` using the case's
  position, and the cases are declared in this order:

  | Code | Case |
  |------|------|
  | 0 | `invalidPairingFile(reason:)` |
  | **1** | **`connectionFailed(String)`** |
  | 2 | `serviceError(String)` |
  | 3 | `noConnection` |
  | 4 | `notInitialized` |
  | 5 | `tunnelPeerIpNotAvailable` |

So the full message is **"Failed to connect to device: `<reason>`"**, and that
`<reason>` is the part that tells you what to fix.

### What it rules out

This is genuinely useful: it is **not** code 5 (`tunnelPeerIpNotAvailable`) and
**not** code 0 (`invalidPairingFile`). The tunnel therefore exists and has a
peer IP, and your pairing file loaded at startup. The failure is one step
later — actually opening the connection to the device. On the install path
`connectionFailed` is thrown for exactly these reasons:

- `pairingFileData is nil`
- `Failed to parse temporary pairing file: …` — the pairing file is re-parsed
  at connect time, so a stale or truncated one passes startup and fails here
- `Temporary pairing file was nil`
- `Failed to create TCP provider: …` / `TCP Provider was nil` — the tunnel is
  up but lockdownd on the device isn't reachable through it
- `Tunnel creation failed`
- the usbmuxd variants (`No devices found on usbmuxd`, etc.)

### Read the actual reason first

Don't guess between those — SideStore records it:

- **Settings → Error Log** → tap the entry. The code is the title; the full
  "Failed to connect to device: …" text is in the details.
- **Settings → Health Check** → shows pairing file Loaded vs **Verified**, VPN
  state, DDI mounted, and a device ping. "Loaded (Connection down)" next to
  the pairing row confirms a stale pairing file.

### Fixes, in order

1. **Regenerate the pairing file with iLoader** and re-import it. This is the
   most common cause: the file is validated again at connect time, so one that
   went stale after an iPadOS update or network reset only fails at this point.
2. **Toggle the LocalDev VPN off and on**, then retry. The tunnel can survive
   as an interface while no longer carrying traffic.
3. **Restart the iPad** and reconnect the VPN before opening SideStore —
   this remounts the Developer Disk Image, which installs depend on.
4. Confirm **Private Wi-Fi Address is off** for your network and that you're on
   Wi-Fi, not cellular.
5. Retry the install. If it now fails with a *different* code, look that code
   up in the table above — the number tells you which stage moved.

### Note

This one is an environment/pairing problem rather than a bug in SideStore's
Swift code, so there's no patch in this repo that fixes it — the steps above
are the fix. The error *presentation* is what's poor: the code label is shown
prominently while the actionable reason is a screen away.

## 1. "UUID error" when refreshing apps

Seen on recent iPadOS versions (including iPadOS 26.x). SideStore can't read
your device identity from the pairing file.

**Fixes, in order:**
1. Generate a **fresh pairing file** with [iLoader](https://sidestore.io) or
   Jitterbug on your computer, with the iPad connected by cable and *unlocked*.
   Tap "Trust" on the iPad if prompted.
2. Import the new pairing file into SideStore (Settings → import pairing file).
3. In iPad Settings → Wi-Fi → tap the ⓘ next to your network → turn **off
   "Private Wi-Fi Address"** (or set it to Fixed), then reconnect to Wi-Fi.
4. Restart the iPad, open SideStore, turn the VPN on, and try refreshing again.

A pairing file goes stale whenever you update iPadOS, reset network settings,
or restore the device — regenerate it after any of those.

## 2. "You are not connected to WiFi or LocalDev VPN"

SideStore talks to the iPad through a local loopback VPN. This error means the
VPN tunnel isn't actually up.

**Fixes, in order:**
1. Open SideStore and toggle the **LocalDev VPN on** (or open the StosVPN app
   and connect, if you use that).
2. Make sure the iPad is on **Wi-Fi**, not cellular-only.
3. iPad Settings → General → VPN & Device Management → remove the SideStore/
   LocalDev VPN profile, then let SideStore re-create it and accept the prompt.
4. If it still fails, Settings → General → Transfer or Reset → **Reset Network
   Settings** (you'll need to rejoin Wi-Fi), then regenerate the pairing file
   (see section 1 — a network reset invalidates it).

## 3. Sign-in fails, hangs, or shows an authentication/anisette error

SideStore relies on an external "anisette" server to sign in with your
Apple ID, and these servers go down sometimes.

**Fix:** SideStore Settings → **Anisette server** → pick a different server
from the list, then try signing in again. If every server fails, wait an hour
and retry — it's usually an outage, not your iPad.

## 4. Apps stop launching after 7 days / "profile expired"

With a free Apple ID, every sideloaded app's signature expires after 7 days.

**Fix:** open SideStore (VPN on) and tap **Refresh All** before the 7 days are
up. Enable Background Refresh for SideStore so it can auto-refresh. A paid
Apple Developer account extends this to 1 year.

## 5. "Cannot install" / app limit reached

Free Apple IDs can only have **3 sideloaded apps** installed at once (and
10 App IDs per week). Delete one sideloaded app and wait a few minutes, or
remove old App IDs from SideStore's My Apps screen.

## 6. General reset procedure (when nothing above works)

1. Delete SideStore from the iPad.
2. Reinstall it with iLoader from your computer.
3. Generate and import a fresh pairing file during that install.
4. Turn off Private Wi-Fi Address, enable the VPN, sign in, refresh.

## Still broken?

If you get an error not covered here, note the **exact error text** (screenshot
it) plus your iPadOS version and SideStore version. With that, targeted code
fixes can be made in this repo. Useful references:

- SideStore docs & error codes: https://docs.sidestore.io/docs/troubleshooting
- Upstream issue tracker: https://github.com/SideStore/SideStore/issues
