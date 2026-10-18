<p align="center"><img src="assets/snaptty.png" alt="snaptty icon" width="128" height="128"></p>

# snaptty

Paste macOS screenshots into the terminal with `Cmd+V`.

Take a screenshot with any macOS shortcut, then press `Cmd+V` in your terminal: snaptty puts the screenshot's file path on the clipboard, so the path is pasted. Coding agents such as Claude Code and Codex read images from a path, and Claude Code attaches a pasted image path as an image. The PNG data stays on the clipboard too, so apps that paste images (chat apps, image editors, Claude Code's `Ctrl+V`) still get the picture.

## How it works

Terminals paste text only. A macOS screenshot either lands as a file or as image-only clipboard content. snaptty runs one LaunchAgent (`com.s3rgiosan.snaptty`, a small Swift program) that handles both:

| Shortcut | macOS behavior | snaptty |
|---|---|---|
| `Cmd+Shift+3`, `Cmd+Shift+4`, `Cmd+Shift+4` then `Space`, `Cmd+Shift+5` | Saves a file | Copies the file's path and PNG data |
| `Ctrl+Cmd+Shift+3`, `Ctrl+Cmd+Shift+4`, `Cmd+Shift+5` set to Clipboard | Copies the image, no file | Saves the image to `~/Library/Caches/snaptty/` and adds its path |

- **Screenshot files** are found through Spotlight, which tags every screen capture (`kMDItemIsScreenCapture`), so snaptty follows whatever save location you use and never changes your screenshot settings. The path is backslash-escaped the way a terminal escapes a dropped file.
- **Clipboard images** are checked every 0.3 seconds. When the clipboard holds an image and no text, URL or file reference, the image is saved to the cache and its path is added as text. Cached images older than 7 days are deleted.

## Requirements

- macOS with Spotlight indexing enabled for the folder screenshots are saved to
- Xcode command line tools (`xcode-select --install`), used to compile the agent

## Install

```sh
git clone https://github.com/s3rgiosan/snaptty.git
cd snaptty
./snaptty install
```

`install` builds the agent as `snaptty.app` in `~/Library/Application Support/snaptty/` and loads it, so the checkout can be moved or deleted afterwards. Re-run it to update or to switch options; the app is rebuilt only when its source, `Info.plist` or icon changes.

When screenshots are saved to a protected folder (Desktop, the default, or Documents or Downloads), macOS asks once whether "snaptty" may access it. Allow it: Spotlight leaves out files in protected folders for apps without access. macOS asks again after an update that rebuilds the app. To review the permission later, open System Settings → Privacy & Security → Files & Folders.

To skip clipboard images and handle only the shortcuts that save a file:

```sh
./snaptty install --no-clipboard
```

## Uninstall

```sh
./snaptty uninstall
```

This stops the agent and removes its files and cache. The log is left in place.

## Notes

- **Floating thumbnail.** While the thumbnail shows, macOS waits about 5 seconds before writing the file, so `Cmd+V` pastes the previous clipboard until it goes away. Swipe it off, or turn it off under Options → "Show Floating Thumbnail" in the `Cmd+Shift+5` toolbar.
- **Every image-only copy is handled.** A `Ctrl` screenshot carries no marker on the clipboard, so snaptty also adds a path to images copied in apps such as Preview. Use `--no-clipboard` to turn this off.
- **Changing the save location.** The agent asks for folder access when it starts, so re-run `install` after moving screenshots to another protected folder.
- **Clipboard contents.** Each screenshot replaces whatever was on the clipboard.
- **Log.** `~/Library/Logs/snaptty.log`
- **Icon.** `assets/snaptty.icns` is built from `assets/snaptty.png` with `scripts/make-icon.sh`.

## License

[MIT](LICENSE)
