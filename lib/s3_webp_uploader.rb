require "aws-sdk-s3"
require "vips"

require_relative "s3_webp_uploader/version"
require_relative "s3_webp_uploader/configuration"
require_relative "s3_webp_uploader/uploader"
require_relative "s3_webp_uploader/image_helpers"
require_relative "s3_webp_uploader/railtie" if defined?(Rails::Railtie)

module S3WebpUploader
  class Error < StandardError; end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def uploader_for(record, identifier: nil)
      Uploader.new(record, identifier: identifier)
    end
  end
end
