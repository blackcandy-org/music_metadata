# frozen_string_literal: true

require "test_helper"

class FingerprinterTest < Minitest::Test
  def test_reads_fpcalc_json_output
    executable = File.expand_path("fixtures/fake_fpcalc", __dir__)
    audio = File.expand_path("fixtures/audio.mp3", __dir__)

    fingerprint = MusicMetadata::Fingerprinter.new(executable: executable).call(audio)

    assert_equal 201, fingerprint.duration
    assert_equal "AQAD-test-fingerprint", fingerprint.value
  end

  def test_rejects_missing_audio_file
    error = assert_raises(MusicMetadata::FingerprintError) do
      MusicMetadata::Fingerprinter.new.call("does-not-exist.mp3")
    end

    assert_match "does not exist", error.message
  end
end
