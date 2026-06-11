# Steam Deployment Notes

This project now builds as an Electron desktop game. For Steam, build a Linux folder and upload that folder as a Steam depot.

For private testing, upload to a password-protected Steam beta branch named `alpha`. That lets you download and play through the Steam client without setting the build live for everyone.

## Local Alpha Build

```bash
npm install
npm run dist:steam-linux
```

The Steam-ready Linux folder is:

```text
dist/linux-unpacked/
```

In Steamworks, create a depot for Linux, set its launch executable to `toekan-clicker`, and upload `dist/linux-unpacked/` with SteamPipe.

## SteamPipe Templates

Copy the template VDF files in this folder, replace these placeholders, then run SteamCMD with your real Steamworks credentials:

- `YOUR_STEAM_APP_ID`
- `YOUR_LINUX_DEPOT_ID`
- `/absolute/path/to/this/project`
- `/absolute/path/to/steampipe/output`

## Private Test Flow

1. In Steamworks, create or open the Toe-Kan Clicker app.
2. Create a Linux depot.
3. Create a beta branch named `alpha`, preferably password-protected.
4. Replace placeholders in `app_build_template.vdf` and `depot_build_template.vdf`.
5. Build locally:

```bash
npm run dist:steam-linux
```

6. From the Steamworks SDK `tools/ContentBuilder/builder` folder, run SteamCMD with the app build script:

```bash
steamcmd +login YOUR_STEAMWORKS_USER +run_app_build /home/johnathan/Desktop/gptcode/toekan-clicker-deployable/steam/app_build_template.vdf +quit
```

7. In the Steam client, open the game properties, choose the `alpha` beta branch, then install/play.

Do not commit real Steamworks credentials. Prefer typing the password/Steam Guard code interactively instead of putting them in scripts.
