require "rails/generators"
require "rails/generators/active_record"

module S3WebpUploader
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path("templates", __dir__)

      desc "Creates S3WebpUploader initializer and optional migration"
      
      argument :model_name, type: :string, default: "Product", 
               desc: "Model name to add image columns to (e.g., Product, Item)"

      class_option :migration, type: :boolean, default: true,
                   desc: "Generate migration for slug and image_count columns"

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_initializer
        create_file "config/initializers/s3_webp_uploader.rb", <<~RUBY
          S3WebpUploader.configure do |config|
            # Required: S3 bucket settings
            config.bucket = ENV.fetch("S3_BUCKET", "your-bucket-name")
            config.region = ENV.fetch("S3_REGION", "ap-south-1")
            
            # Prefix for all uploads (app-name/environment/images)
            app_name = Rails.application.class.module_parent_name.underscore.dasherize
            config.prefix = "\#{app_name}/\#{Rails.env}/images"
            
            # AWS credentials - auto-loaded from Rails credentials
            # Or set explicitly:
            # config.access_key_id = ENV["AWS_ACCESS_KEY_ID"]
            # config.secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
            
            # Attribute configuration (customize if your columns have different names)
            # config.identifier_attribute = :slug       # Column used for S3 folder name
            # config.count_attribute = :image_count    # Column for storing image count
            # config.count_column = nil                # Set to JSON column name if storing count in JSON
            #                                          # e.g., config.count_column = :metadata
            #                                          #       config.count_attribute = :photos_count
            
            # Image settings (optional)
            # config.original_max_size = 1200
            # config.thumbnail_max_size = 300
            # config.webp_quality = 85
            # config.acl = "public-read"
            # config.variants = [:original, :thumbnail]
          end
        RUBY
      end

      def create_migration
        return unless options[:migration]
        
        migration_template(
          "migration.rb.erb",
          "db/migrate/add_s3_image_columns_to_#{table_name}.rb"
        )
      end

      def show_readme
        say ""
        say "S3WebpUploader installed!", :green
        say ""
        say "Generated files:"
        say "  - config/initializers/s3_webp_uploader.rb"
        say "  - db/migrate/xxx_add_s3_image_columns_to_#{table_name}.rb" if options[:migration]
        say ""
        say "Next steps:"
        say "1. Run `rails db:migrate`" if options[:migration]
        say "2. Edit config/initializers/s3_webp_uploader.rb with your bucket name"
        say "3. Add AWS credentials to config/credentials.yml.enc:"
        say "   aws:"
        say "     access_key_id: YOUR_KEY"
        say "     secret_access_key: YOUR_SECRET"
        say "4. Add to your model:"
        say "   class #{model_name} < ApplicationRecord"
        say "     include S3WebpUploader::ImageHelpers"
        say "   end"
        say ""
        say "Usage in views:"
        say "  <%= image_tag @#{model_name.underscore}.s3_thumbnail_url if @#{model_name.underscore}.s3_has_images? %>"
        say ""
      end

      private

      def table_name
        model_name.underscore.pluralize
      end

      def model_class_name
        model_name.camelize
      end
    end
  end
end
