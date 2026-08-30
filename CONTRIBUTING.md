# Contributing

Bug reports and pull requests are welcome on GitHub.

## Development setup

Install Ruby 3.1 or newer, then run:

```sh
bundle install
bundle exec rake
```

The default task runs the complete test suite and Standard Ruby. Tests enforce
at least 90% line coverage. Build the package with:

```sh
bundle exec rake build
```

Tests must not call public music services by default. Use fakes or checked-in
JSON fixtures, and keep live verification opt-in so contributors can work
without API keys or network access.

## Pull requests

- Add tests for behavioral changes and provider edge cases.
- Update `CHANGELOG.md` for user-visible changes.
- Never commit API keys, full fingerprints, copyrighted recordings, or user
  library data.
- Preserve the read-only contract: the gem proposes metadata but does not
  mutate audio files.
