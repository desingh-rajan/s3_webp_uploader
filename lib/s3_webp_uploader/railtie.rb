module S3WebpUploader
  class Railtie < Rails::Railtie
    initializer "s3_webp_uploader.configure" do
      # Auto-configure from Rails credentials if available
      S3WebpUploader.configure do |config|
        if defined?(Rails.application.credentials)
          config.access_key_id ||= Rails.application.credentials.dig(:aws, :access_key_id)
          config.secret_access_key ||= Rails.application.credentials.dig(:aws, :secret_access_key)
        end
      end
    end

    generators do
      require_relative "generators/install_generator"
    end
  end
end
