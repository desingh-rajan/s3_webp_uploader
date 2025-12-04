# frozen_string_literal: true

require "bundler/setup"
require "s3_webp_uploader"
require "webmock/rspec"

# Disable real HTTP connections during tests
WebMock.disable_net_connect!(allow_localhost: true)

# Add blank? method for testing (normally provided by Rails/ActiveSupport)
class String
  def blank?
    empty? || /\A[[:space:]]*\z/.match?(self)
  end
end

class NilClass
  def blank?
    true
  end
end

# Add try method (normally provided by Rails/ActiveSupport)
class Object
  def try(method, *args, &block)
    send(method, *args, &block) if respond_to?(method)
  end
end

# Add Time.current (normally provided by Rails/ActiveSupport)
class Time
  def self.current
    now
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset configuration before each test to ensure test isolation
  config.before(:each) do
    S3WebpUploader.configuration = S3WebpUploader::Configuration.new
  end
end

# Stub Vips for tests that don't need actual image processing
module Vips
  class Image
    def self.new_from_file(path, **options)
      new
    end

    def initialize
      @width = 2000
      @height = 1500
    end

    attr_reader :width, :height

    def resize(scale)
      self
    end

    def webpsave(path, **options)
      File.write(path, "fake webp content")
    end
  end
end

# Helper method to set up configuration
def configure_gem
  S3WebpUploader.configure do |config|
    config.bucket = "test-bucket"
    config.region = "us-east-1"
    config.prefix = "test-app/test/images"
    config.access_key_id = "test-access-key"
    config.secret_access_key = "test-secret-key"
  end
end
