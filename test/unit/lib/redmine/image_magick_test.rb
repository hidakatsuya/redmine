# frozen_string_literal: true

require_relative '../../../test_helper'
require 'open3'
require 'tmpdir'

class Redmine::ImageMagickTest < ActiveSupport::TestCase
  def test_environment_preserves_operator_paths_without_duplicates
    paths = ['/operator/policy', Redmine::ImageMagick::POLICY_DIRECTORY].join(File::PATH_SEPARATOR)
    result = Redmine::ImageMagick.environment('MAGICK_CONFIGURE_PATH' => paths)
    assert_equal [Redmine::ImageMagick::POLICY_DIRECTORY, '/operator/policy'].join(File::PATH_SEPARATOR),
                 result['MAGICK_CONFIGURE_PATH']
  end

  def test_mini_magick_preserves_other_environment_settings
    skip unless Object.const_defined?(:MiniMagick)

    original = MiniMagick.cli_env
    MiniMagick.cli_env = {'MAGICK_CONFIGURE_PATH' => '/operator/policy', 'MAGICK_THREAD_LIMIT' => '1'}
    Redmine::ImageMagick.configure_mini_magick
    assert_equal '1', MiniMagick.cli_env['MAGICK_THREAD_LIMIT']
    assert_equal [Redmine::ImageMagick::POLICY_DIRECTORY, '/operator/policy'].join(File::PATH_SEPARATOR),
                 MiniMagick.cli_env['MAGICK_CONFIGURE_PATH']
  ensure
    MiniMagick.cli_env = original if original
  end

  def test_policy_rejects_cr3_even_when_marcel_identifies_jpeg
    skip unless convert_installed?

    Dir.mktmpdir do |directory|
      source = File.join(directory, 'image.jpg')
      File.binwrite(source, "\xff\xd8\xff\x00ftypcrx ".b + "\x00".b * 100)
      assert_equal 'image/jpeg', File.open(source) {|file| Marcel::MimeType.for(file)}

      _, error, status = convert(source, File.join(directory, 'thumbnail.png'))
      assert_not status.success?
      # Older ImageMagick versions recognize only the JPEG marker and reject
      # the invalid JPEG. Versions that recognize CR3 must reject it by policy.
      assert_match(/security policy.*CR3|error\/jpeg\.c/i, error)
    end
  end

  def test_policy_rejects_scripting_and_external_reference_coders
    skip unless convert_installed?

    Dir.mktmpdir do |directory|
      source = File.join(directory, 'script.xml')
      File.write(source, '<image><read filename="xc:white"/></image>')
      ["msl:#{source}", 'https://example.invalid/image.png'].each do |input|
        _, error, status = convert(input, File.join(directory, 'thumbnail.png'))
        assert_not status.success?
        assert_match(/security policy/i, error)
      end
    end
  end

  def test_mini_magick_rejects_scripting_coder
    skip unless Object.const_defined?(:MiniMagick) && convert_installed?

    original = MiniMagick.cli_env
    Redmine::ImageMagick.configure_mini_magick
    Dir.mktmpdir do |directory|
      source = File.join(directory, 'script.xml')
      File.write(source, '<image><read filename="xc:white"/></image>')
      error = assert_raises MiniMagick::Error do
        MiniMagick.convert do |command|
          command << "msl:#{source}"
          command << File.join(directory, 'image.png')
        end
      end
      assert_match(/security policy.*MSL/i, error.message)
    end
  ensure
    MiniMagick.cli_env = original if original
  end

  def test_policy_preserves_later_operator_restrictions
    skip unless convert_installed?

    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'policy.xml'),
                 '<policymap><policy domain="coder" rights="none" pattern="PNG"/></policymap>')
      environment = Redmine::ImageMagick.environment('MAGICK_CONFIGURE_PATH' => directory)
      _, error, status = Open3.capture3(environment, Redmine::Thumbnail::CONVERT_BIN,
                                      'xc:white', File.join(directory, 'image.png'))
      assert_not status.success?
      assert_match(/security policy.*PNG/i, error)
    end
  end

  private

  def convert(*)
    Open3.capture3(Redmine::ImageMagick.environment, Redmine::Thumbnail::CONVERT_BIN, *)
  end
end
