# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-07-08

### Added
- **Cursor-Driven Configuration Wizard**: Rewrote `configure.sh`'s main loop as an arrow-key-driven editor — navigate enabled segments with `↑`/`↓`, add/remove/reorder in place, and insert a line break at the cursor with `n`.
- **Live Preview Engine**: The wizard now shells out to the real renderer for an always-accurate, cached live preview as you edit.
- **Auto-Wrap**: Segments that overflow the terminal width now wrap onto a new line automatically instead of truncating with `...`.
- **New Segments**: `cache_read`, `cache_write`, `quota_5h_reset`, `quota_7d_reset`, `vim_mode`, `worktree`, `api_duration`, `tokens_in`, `tokens_out`, `tokens_cached`, `tokens_total`, `flex`, `newline`.
- **`STATUSLINE_CONFIG_FILE`**: Environment variable override for the config path, enabling isolated testing.

### Fixed
- Incorrect README description for the Duration segment (was documented with API Duration's description).

## [0.2.0] - 2026-07-07

### Added
- **Interactive Configuration Wizard (`configure.sh`)**: A bash-compatible terminal UI to easily toggle, customize, and reorder statusline segments with a live updating preview.
- **One-Line Installer (`install.sh`)**: Direct setup command that downloads the scripts, edits `settings.json`, and launches the configuration wizard.
- **New Segment Renderers**: Added support for 19 total configurable segments, including:
  - `context_pct`, `quota_5h_pct`, `quota_7d_pct`: Bar-free percentage segments to save terminal space and prevent truncation.
  - `effort`: Current reasoning effort level (low, medium, high, etc.).
  - `thinking`: Extended thinking status (on/off).
  - `pr`: Pull Request number and review status (approved, draft, etc.).
  - `duration`: API response wait duration formatted nicely.
  - `lines`: Lines of code added/removed (+/-).
  - `session`: Custom session name.
  - `version`: Claude Code version.
- **Truncation Warning**: Configurator now warns users if their enabled statusline exceeds 85 printable characters to prevent terminal truncation.
- **`CHANGELOG.md`**: Official version history tracking.

### Changed
- **Segment-Based Architecture**: Refactored `statusline-command.sh` from a monolithic script into a clean, modular structure of independent renderers.
- **Native JSON Payload Integration**: Switched to using Claude Code's native `context_window.used_percentage` and `rate_limits` fields.
- **Optimized Layout Logic**: Automatically hides API cost when subscription quotas (`quota_5h`/`quota_7d`) are active.

### Removed
- **Background `curl` Hack**: Removed credentials parsing, background API calls to Claude Haiku, and token-wasting header probing.
- **Cache File Dependency**: Deleted local caching mechanism (`~/.claude/quota_cache.json`).
- **Static Overhead Math**: Deprecated fallback context window estimation formulas in favor of native accuracy.
- **`eval` Usage**: Cleaned up code execution pathways in progress bar generation to prevent potential shell injections.

---

## [0.1.0] - 2026-07-06

### Added
- Initial release of the custom Claude Code statusline script.
- Basic session cost display.
- Cached context window usage bar.
- Basic Git branch and status indicators.
- Localized timestamp, active model, and style info.
