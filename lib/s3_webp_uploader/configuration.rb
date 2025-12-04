module S3WebpUploader
  class Configuration
    attr_accessor :bucket, :region, :prefix, :access_key_id, :secret_access_key,
                  :original_max_size, :thumbnail_max_size, :webp_quality,
                  :acl, :variants, :identifier_attribute, :count_attribute, :count_column

    def initialize
      @bucket = ENV.fetch("S3_BUCKET", nil)
      @region = ENV.fetch("S3_REGION", "ap-south-1")
      @prefix = ENV.fetch("S3_PREFIX", nil)
      @access_key_id = nil
      @secret_access_key = nil
      @original_max_size = 1200
      @thumbnail_max_size = 300
      @webp_quality = 85
      @acl = "public-read"
      @variants = [:original, :thumbnail]
      
      # Customizable attribute names
      @identifier_attribute = :slug        # Used for S3 folder name
      @count_attribute = :image_count      # Column or JSON key for count
      @count_column = nil                  # If set, uses this JSON column with count_attribute as key
    end

    def credentials
      return nil unless access_key_id && secret_access_key
      Aws::Credentials.new(access_key_id, secret_access_key)
    end

    def s3_client
      @s3_client ||= Aws::S3::Client.new(
        region: region,
        credentials: credentials
      ).tap { @s3_client = nil if @s3_client&.config&.credentials.nil? }
    end

    def base_url
      "https://#{bucket}.s3.#{region}.amazonaws.com/#{prefix}"
    end

    def validate!
      raise Error, "bucket is required" if bucket.nil?
      raise Error, "region is required" if region.nil?
      raise Error, "access_key_id is required" if access_key_id.nil?
      raise Error, "secret_access_key is required" if secret_access_key.nil?
    end
  end
end
