# Changelog

All notable changes to snaptty will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- LaunchAgent that puts each new screenshot's escaped file path and PNG data on the clipboard, finding screenshots through Spotlight in any save location.
- Clipboard handling that saves image-only clipboard content to a cache file and adds its path as text, covering the `Ctrl` screenshot shortcuts.
- `install`, `install --no-clipboard` and `uninstall` commands.
- App bundle with a name and icon, shown in Login Items and the folder access prompt.

[Unreleased]: https://github.com/s3rgiosan/snaptty/commits/main
