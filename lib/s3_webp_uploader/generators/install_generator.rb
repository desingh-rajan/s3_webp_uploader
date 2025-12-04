require "rails/generators"

module S3WebpUploader
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates S3WebpUploader initializer"

      def create_initializer
        create_file "config/initializers/s3_webp_uploader.rb", <<~RUBY
          S3WebpUploader.configure do |config|
            # Required settings
            config.bucket = ENV.fetch("S3_BUCKET", "your-bucket-name")
            config.region = ENV.fetch("S3_REGION", "ap-south-1")
            
            # Prefix for all uploads (e.g., "my-app/prod/images")
            # Tip: Use Rails.env to separate dev/prod
            app_name = Rails.application.class.module_parent_name.underscore.dasherize
            config.prefix = "\#{app_name}/\#{Rails.env}/images"
            
            # AWS credentials - auto-loaded from Rails credentials
            # Or set explicitly:
            # config.access_key_id = ENV["AWS_ACCESS_KEY_ID"]
            # config.secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
            
            # Image settings (optional)
            # config.original_max_size = 1200
            # config.thumbnail_max_size = 300
            # config.webp_quality = 85
            # config.acl = "public-read"
            # config.variants = [:original, :thumbnail]
          end
        RUBY
      end

      def show_readme
        say ""
        say "S3WebpUploader installed!", :green
        say ""
        say "Next steps:"
        say "1. Edit config/initializers/s3_webp_uploader.rb"
        say "2. Add AWS credentials to config/credentials.yml.enc:"
        say "   aws:"
        say "     access_key_id: YOUR_KEY"
        say "     secret_access_key: YOUR_SECRET"
        say ""
        say "Usage:"
        say "  uploader = S3WebpUploader.uploader_for(@product)"
        say "  uploader.upload(params[:image])"
        say "  uploader.url(:thumbnail, 0)"
        say ""
      end
    end
  end
end
