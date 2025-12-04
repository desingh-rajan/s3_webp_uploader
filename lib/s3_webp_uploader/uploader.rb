module S3WebpUploader
  class Uploader
    attr_reader :record, :identifier, :config

    def initialize(record, identifier: nil)
      @record = record
      @config = S3WebpUploader.configuration
      @identifier = identifier || extract_identifier(record)
      validate!
    end

    # Upload a single image, returns index
    def upload(file)
      return nil unless valid_image?(file)

      index = current_count
      upload_variants(file.tempfile.path, index)
      update_count(index + 1)
      index
    rescue => e
      log_error("Upload failed", e)
      nil
    end

    # Upload multiple images, returns array of indices
    def upload_all(files)
      Array(files).filter_map { |f| upload(f) }
    end

    # Replace image at index
    def replace(index, file)
      return nil unless valid_image?(file)
      return nil unless index >= 0 && index < current_count

      delete_variants(index)
      upload_variants(file.tempfile.path, index)
      index
    rescue => e
      log_error("Replace failed", e)
      nil
    end

    # Delete image at index (reindexes remaining)
    def delete(index)
      return false unless index >= 0 && index < current_count

      delete_variants(index)
      reindex_after_delete(index)
      true
    rescue => e
      log_error("Delete failed", e)
      false
    end

    # Delete all images
    def delete_all
      current_count.times { |i| delete_variants(i) }
      update_count(0)
      true
    rescue => e
      log_error("Delete all failed", e)
      false
    end

    # Get URL for variant at index
    def url(variant = :original, index = 0)
      "#{config.base_url}/#{identifier}/#{key_suffix(variant, index)}"
    end

    # Get all URLs for a variant
    def urls(variant = :original)
      (0...current_count).map { |i| url(variant, i) }
    end

    # Check if image exists
    def exists?(index = 0)
      s3_head(s3_key(:original, index))
    end

    # Current image count
    def count
      current_count
    end

    private

    def validate!
      config.validate!
      raise Error, "identifier cannot be blank" if identifier.blank?
    end

    def extract_identifier(record)
      return record if record.is_a?(String)
      
      id_attr = config.identifier_attribute
      record.try(id_attr) || record.try(:to_param) || record.try(:id)&.to_s
    end

    def current_count
      return 0 unless record.respond_to?(:read_attribute)

      count_attr = config.count_attribute.to_s
      json_column = config.count_column&.to_s

      # If count_column is set, look in that JSON column
      if json_column && record.class.column_names.include?(json_column)
        record.read_attribute(json_column)&.dig(count_attr) || 0
      # Otherwise, try the count_attribute as a direct column
      elsif record.class.column_names.include?(count_attr)
        record.read_attribute(count_attr) || 0
      # Fallback: try specifications column (backward compatibility)
      elsif record.class.column_names.include?("specifications")
        record.read_attribute(:specifications)&.dig("image_count") || 0
      else
        0
      end
    end

    def update_count(count)
      return unless record.respond_to?(:update_columns)

      count_attr = config.count_attribute.to_s
      json_column = config.count_column&.to_s

      # If count_column is set, update within that JSON column
      if json_column && record.class.column_names.include?(json_column)
        data = record.read_attribute(json_column) || {}
        data[count_attr] = count
        record.update_columns(json_column.to_sym => data, updated_at: Time.current)
      # Otherwise, update the count_attribute column directly
      elsif record.class.column_names.include?(count_attr)
        record.update_columns(count_attr.to_sym => count, updated_at: Time.current)
      # Fallback: try specifications column
      elsif record.class.column_names.include?("specifications")
        specs = record.read_attribute(:specifications) || {}
        specs["image_count"] = count
        record.update_columns(specifications: specs, updated_at: Time.current)
      end
    end

    def upload_variants(source_path, index)
      config.variants.each do |variant|
        max_size = variant == :thumbnail ? config.thumbnail_max_size : config.original_max_size
        webp_file = convert_to_webp(source_path, max_size)
        next unless webp_file

        s3_put(webp_file, s3_key(variant, index))
        webp_file.close
      end
    end

    def delete_variants(index)
      config.variants.each do |variant|
        s3_delete(s3_key(variant, index))
      end
    end

    def reindex_after_delete(deleted_index)
      total = current_count
      ((deleted_index + 1)...total).each do |i|
        config.variants.each do |variant|
          s3_copy(s3_key(variant, i), s3_key(variant, i - 1))
          s3_delete(s3_key(variant, i))
        end
      end
      update_count([total - 1, 0].max)
    end

    def s3_key(variant, index)
      "#{config.prefix}/#{identifier}/#{key_suffix(variant, index)}"
    end

    def key_suffix(variant, index)
      suffix = index.zero? ? "" : "_#{index}"
      "#{variant}#{suffix}.webp"
    end

    def convert_to_webp(source_path, max_size)
      image = Vips::Image.new_from_file(source_path, access: :sequential)
      scale = [max_size.to_f / image.width, max_size.to_f / image.height].min
      resized = scale < 1 ? image.resize(scale) : image

      temp = Tempfile.new(["webp_", ".webp"])
      resized.webpsave(temp.path, Q: config.webp_quality)
      temp.rewind
      temp
    rescue => e
      log_error("WebP conversion failed", e)
      nil
    end

    def s3_client
      @s3_client ||= Aws::S3::Client.new(
        region: config.region,
        credentials: config.credentials
      )
    end

    def s3_put(file, key)
      file.rewind if file.respond_to?(:rewind)
      s3_client.put_object(
        bucket: config.bucket,
        key: key,
        body: file,
        content_type: "image/webp",
        acl: config.acl
      )
    end

    def s3_delete(key)
      s3_client.delete_object(bucket: config.bucket, key: key)
    rescue Aws::S3::Errors::NoSuchKey
      # Ignore
    end

    def s3_copy(source_key, dest_key)
      s3_client.copy_object(
        bucket: config.bucket,
        copy_source: "#{config.bucket}/#{source_key}",
        key: dest_key,
        acl: config.acl
      )
    end

    def s3_head(key)
      s3_client.head_object(bucket: config.bucket, key: key)
      true
    rescue Aws::S3::Errors::NotFound
      false
    end

    def valid_image?(file)
      return false unless file.respond_to?(:content_type)
      file.content_type&.start_with?("image/")
    end

    def log_error(message, error)
      if defined?(Rails)
        Rails.logger.error "[S3WebpUploader] #{message}: #{error.message}"
      else
        warn "[S3WebpUploader] #{message}: #{error.message}"
      end
    end
  end
end
