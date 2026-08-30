# MusicMetadata

`MusicMetadata` is a small, stateless Ruby library for identifying an audio
file and proposing normalized music metadata. It is designed to sit between a
music application and existing open music services without taking ownership of
the application's library.

The gem is read-only: it does not move files, rename files, write audio tags,
or maintain a second music database.

## Pipeline

1. Use an embedded MusicBrainz recording ID when the caller already has one.
2. Otherwise run Chromaprint's `fpcalc` against the audio file.
3. Send the fingerprint and duration to AcoustID.
4. Fetch canonical recording and release metadata from MusicBrainz.
5. Fetch release-specific artwork from the Cover Art Archive.
6. Return a proposal with confidence, ambiguity, provenance, and candidates.

Beets is the primary behavioral reference for this design. This gem reuses the
same underlying open services but deliberately does not embed beets' importer,
database, interactive matching, or file-management workflow.

## Requirements

- Ruby 3.1 or newer
- [`fpcalc`](https://acoustid.org/chromaprint), unless every request supplies a
  MusicBrainz recording ID
- An [AcoustID application API key](https://acoustid.org/api-key)
- A descriptive User-Agent for MusicBrainz requests

On Debian/Ubuntu, `fpcalc` is normally provided by `libchromaprint-tools`. On
macOS it is available through `brew install chromaprint`.

## Installation

Until the first RubyGems release, add the GitHub repository to your Gemfile:

```ruby
gem "music_metadata", github: "blackcandy-org/music_metadata", branch: "main"
```

Then run:

```sh
bundle install
```

## Usage

```ruby
require "music_metadata"

MusicMetadata.configure do |config|
  config.acoustid_api_key = ENV.fetch("ACOUSTID_API_KEY")
  config.user_agent = "MyMusicApp/1.0 (admin@example.com)"
  config.minimum_confidence = 0.85
end

result = MusicMetadata.enrich(
  file_path: "/music/song.flac",
  metadata: {
    title: "Existing title",
    artist: "Existing artist",
    album: "Existing album"
  }
)

result.acceptable?       # confidence is high enough and match is unambiguous
result.ambiguous?        # top candidates are too close to auto-accept
result.value(:artist)    # normalized value
result.source(:artist)   # :musicbrainz or :embedded
result.candidates        # scored AcoustID/MusicBrainz candidates
result.to_h              # serializable proposal
```

When a trusted embedded MusicBrainz recording ID exists, identification skips
`fpcalc` and AcoustID:

```ruby
MusicMetadata.enrich(
  file_path: "/music/song.flac",
  metadata: { musicbrainz_recording_id: "..." }
)
```

The command-line interface prints the same result as JSON:

```sh
ACOUSTID_API_KEY=... bundle exec music-metadata \
  --artist "Artist hint" \
  --album "Album hint" \
  /music/song.flac
```

Exit status is `0` for an acceptable result, `1` for an unmatched, ambiguous,
or low-confidence result, and `2` for configuration/provider failures.

## Verify a local installation

First check configuration and prove that `fpcalc` can decode a real file:

```sh
ACOUSTID_API_KEY=your_application_key \
  bundle exec music-metadata-doctor /music/song.flac
```

The doctor reports whether an API key and User-Agent are configured, plus the
decoded duration and encoded fingerprint length. It never prints the API key
or the fingerprint itself.

Then perform an end-to-end identification:

```sh
ACOUSTID_API_KEY=your_application_key \
MUSIC_METADATA_USER_AGENT='MyMusicApp/1.0 (admin@example.com)' \
  bundle exec music-metadata \
    --artist 'Optional artist hint' \
    --album 'Optional album hint' \
    /music/song.flac
```

Use a full, recognizable recording rather than a generated tone or very short
fixture. A successful run has `match.acceptable: true` and returns the matched
MusicBrainz identifiers and Cover Art Archive result. An empty `candidates`
array means AcoustID accepted the fingerprint but did not know the recording.

To verify MusicBrainz and Cover Art Archive independently of fingerprinting,
pass a trusted recording MBID:

```sh
bundle exec music-metadata \
  --recording-id cd2e7c47-16f5-46c6-a37c-a1eb7bf599ff \
  /music/song.flac
```

This bypasses `fpcalc` and AcoustID and is useful for separating identification
problems from metadata-provider problems.

## Returned shape

```ruby
{
  metadata: {
    title: "Canonical title",
    artist: "Canonical artist credit",
    artists: [ "Canonical artist" ],
    album: "Release title",
    release_date: "2020-05-01",
    year: 2020,
    genres: [ "Indie Rock" ],
    artwork: {
      url: "https://.../cover-500.jpg",
      original_url: "https://.../cover.jpg",
      source: :cover_art_archive
    },
    musicbrainz_recording_id: "...",
    musicbrainz_release_id: "...",
    acoustid: "...",
    isrcs: [ "..." ]
  },
  sources: {
    title: :musicbrainz,
    artwork: :cover_art_archive
  },
  match: {
    confidence: 0.97,
    method: :acoustid,
    acceptable: true,
    ambiguous: false
  },
  candidates: [],
  warnings: []
}
```

## Application integration boundary

Black Candy only needs to pass a file path plus the tags it already reads with
WahWah. A background job can inspect `acceptable?` and apply selected values.
The gem owns external API formats, throttling, matching, normalization, and
provenance; Black Candy keeps persistence and overwrite policy.

Discogs styles and Last.fm genre canonicalization are intentionally deferred
until the identification and canonical MusicBrainz path has been validated on
a representative file corpus.

## Development

```sh
bundle install
bundle exec rake test
gem build music_metadata.gemspec
```
