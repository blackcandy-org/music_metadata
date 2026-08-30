# frozen_string_literal: true

require_relative "lib/music_metadata/version"

Gem::Specification.new do |spec|
  spec.name = "music_metadata"
  spec.version = MusicMetadata::VERSION
  spec.authors = [ "Black Candy contributors" ]
  spec.summary = "Identify audio files and enrich their music metadata"
  spec.description = <<~DESCRIPTION
    A small, stateless Ruby library that identifies audio with Chromaprint and
    AcoustID, enriches matches with MusicBrainz, and finds release artwork in
    the Cover Art Archive.
  DESCRIPTION
  spec.homepage = "https://github.com/blackcandy-org/blackcandy"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*", "exe/*", "README.md", "LICENSE.txt"]
  end
  spec.bindir = "exe"
  spec.executables = [ "music-metadata", "music-metadata-doctor" ]
  spec.require_paths = [ "lib" ]

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = spec.homepage
end
