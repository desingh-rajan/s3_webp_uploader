module S3WebpUploader
  # Standalone helper module - include only if you want convenience methods
  # Or just use S3WebpUploader.uploader_for(record) directly
  module ImageHelpers
    def s3_image_uploader(identifier_method = :slug)
      S3WebpUploader.uploader_for(self, identifier: send(identifier_method))
    end

    def s3_image_url(variant = :original, index = 0)
      s3_image_uploader.url(variant, index)
    end

    def s3_thumbnail_url(index = 0)
      s3_image_url(:thumbnail, index)
    end

    def s3_original_url(index = 0)
      s3_image_url(:original, index)
    end

    def s3_image_urls(variant = :original)
      s3_image_uploader.urls(variant)
    end

    def s3_image_count
      s3_image_uploader.count
    end

    def s3_has_images?
      s3_image_count.positive?
    end
  end
end
