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

  def test_terminates_fpcalc_after_timeout
    executable = File.expand_path("fixtures/slow_fpcalc", __dir__)
    audio = File.expand_path("fixtures/audio.mp3", __dir__)

    error = assert_raises(MusicMetadata::FingerprintError) do
      MusicMetadata::Fingerprinter.new(executable: executable, timeout: 0.05).call(audio)
    end

    assert_match "timed out", error.message
  end

  def test_reports_fpcalc_failure_without_losing_stderr
    error = fingerprint_error("failing_fpcalc")

    assert_match "decoder failed", error.message
  end

  def test_rejects_invalid_and_incomplete_fpcalc_output
    invalid = fingerprint_error("invalid_json_fpcalc")
    incomplete = fingerprint_error("incomplete_fpcalc")

    assert_match "invalid JSON", invalid.message
    assert_match "incomplete fingerprint", incomplete.message
  end

  def test_reports_missing_fpcalc_executable
    audio = File.expand_path("fixtures/audio.mp3", __dir__)

    error = assert_raises(MusicMetadata::FingerprintError) do
      MusicMetadata::Fingerprinter.new(executable: "definitely-missing-fpcalc").call(audio)
    end

    assert_match "was not found", error.message
  end

  private

  def fingerprint_error(fixture)
    executable = File.expand_path("fixtures/#{fixture}", __dir__)
    audio = File.expand_path("fixtures/audio.mp3", __dir__)

    assert_raises(MusicMetadata::FingerprintError) do
      MusicMetadata::Fingerprinter.new(executable: executable).call(audio)
    end
  end
end
