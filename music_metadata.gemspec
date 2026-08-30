# frozen_string_literal: true

require_relative "lib/music_metadata/version"

Gem::Specification.new do |spec|
  spec.name = "music_metadata"
  spec.version = MusicMetadata::VERSION
  spec.authors = ["Black Candy contributors"]
  spec.email = ["liuwenju26@gmail.com"]
  spec.summary = "Identify audio files and enrich their music metadata"
  spec.description = <<~DESCRIPTION
    A small, stateless Ruby library that identifies audio with Chromaprint and
    AcoustID, enriches matches with MusicBrainz, and finds release artwork in
    the Cover Art Archive.
  DESCRIPTION
  spec.homepage = "https://github.com/blackcandy-org/music_metadata"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*", "exe/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  end
  spec.bindir = "exe"
  spec.executables = ["music-metadata", "music-metadata-doctor"]
  spec.require_paths = ["lib"]

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "#{spec.homepage}#readme"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "simplecov", "~> 0.22.0"
  spec.add_development_dependency "standard", "~> 1.56"
end
