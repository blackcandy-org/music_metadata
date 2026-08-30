# Changelog

All notable changes to this project will be documented in this file. The
project follows Semantic Versioning.

## [Unreleased]

## [0.2.0] - 2026-08-30

### Added

- Process-wide, thread-safe throttling for MusicBrainz and AcoustID.
- Bounded retries with exponential backoff and `Retry-After` support.
- In-memory LRU response caching with configurable expiry.
- A timeout that terminates stalled `fpcalc` process groups.
- Deterministic MusicBrainz release selection and release-ID hints.
- Standard Ruby linting, coverage enforcement, expanded tests, dependency
  updates, and Ruby 3.1–4.0 CI.
- Trusted Publishing release workflow and automated dependency updates.

### Changed

- AcoustID fingerprint lookup now uses form-encoded POST requests.
- Result candidates and fingerprints are immutable.
- Configuration values are validated before network work begins.

## [0.1.0] - 2026-08-30

### Added

- Initial Chromaprint, AcoustID, MusicBrainz, and Cover Art Archive pipeline.
- Ruby API, JSON CLI, diagnostic CLI, confidence checks, ambiguity detection,
  and field provenance.

[Unreleased]: https://github.com/blackcandy-org/music_metadata/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/blackcandy-org/music_metadata/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/blackcandy-org/music_metadata/releases/tag/v0.1.0
