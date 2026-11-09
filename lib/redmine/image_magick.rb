# frozen_string_literal: true

module Redmine
  # Restrict ImageMagick itself in addition to checking attachment MIME types.
  module ImageMagick
    POLICY_DIRECTORY = File.expand_path('image_magick', __dir__).freeze

    def self.environment(environment=ENV)
      paths = environment.fetch('MAGICK_CONFIGURE_PATH', ENV['MAGICK_CONFIGURE_PATH']).to_s.split(File::PATH_SEPARATOR)
      {'MAGICK_CONFIGURE_PATH' => [POLICY_DIRECTORY, *paths].uniq.join(File::PATH_SEPARATOR)}
    end

    def self.configure_mini_magick
      MiniMagick.cli_env = MiniMagick.cli_env.merge(environment(MiniMagick.cli_env))
    end
  end
end
