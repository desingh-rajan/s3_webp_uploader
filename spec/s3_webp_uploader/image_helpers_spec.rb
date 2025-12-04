# frozen_string_literal: true

RSpec.describe S3WebpUploader::ImageHelpers do
  # Create a test class that includes the helpers
  let(:model_class) do
    klass = Class.new do
      include S3WebpUploader::ImageHelpers

      attr_accessor :slug, :image_count

      def initialize(slug:, image_count: 0)
        @slug = slug
        @image_count = image_count
      end

      def read_attribute(attr)
        send(attr)
      end

      def respond_to?(method, include_all = false)
        [:read_attribute, :update_columns, :slug, :image_count].include?(method) || super
      end

      def update_columns(attrs)
        attrs.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
        true
      end

      def try(method)
        send(method) if respond_to?(method)
      end
    end
    
    # Define column_names as a class method
    klass.define_singleton_method(:column_names) { %w[id slug image_count] }
    klass
  end

  let(:record) { model_class.new(slug: "awesome-widget", image_count: 3) }

  before(:each) do
    S3WebpUploader.configure do |config|
      config.bucket = "test-bucket"
      config.region = "ap-south-1"
      config.prefix = "my-app/production/images"
      config.access_key_id = "test-key"
      config.secret_access_key = "test-secret"
    end
  end

  describe "#s3_image_uploader" do
    it "returns an Uploader instance" do
      expect(record.s3_image_uploader).to be_a(S3WebpUploader::Uploader)
    end

    it "uses the default slug method" do
      uploader = record.s3_image_uploader
      expect(uploader.identifier).to eq("awesome-widget")
    end

    it "accepts custom identifier method" do
      record.define_singleton_method(:custom_id) { "custom-123" }
      uploader = record.s3_image_uploader(:custom_id)
      expect(uploader.identifier).to eq("custom-123")
    end
  end

  describe "#s3_thumbnail_url" do
    it "returns the thumbnail URL for first image by default" do
      expected = "https://test-bucket.s3.ap-south-1.amazonaws.com/my-app/production/images/awesome-widget/thumbnail.webp"
      expect(record.s3_thumbnail_url).to eq(expected)
    end

    it "returns the thumbnail URL for specified index" do
      expected = "https://test-bucket.s3.ap-south-1.amazonaws.com/my-app/production/images/awesome-widget/thumbnail_2.webp"
      expect(record.s3_thumbnail_url(2)).to eq(expected)
    end
  end

  describe "#s3_original_url" do
    it "returns the original URL for first image by default" do
      expected = "https://test-bucket.s3.ap-south-1.amazonaws.com/my-app/production/images/awesome-widget/original.webp"
      expect(record.s3_original_url).to eq(expected)
    end

    it "returns the original URL for specified index" do
      expected = "https://test-bucket.s3.ap-south-1.amazonaws.com/my-app/production/images/awesome-widget/original_1.webp"
      expect(record.s3_original_url(1)).to eq(expected)
    end
  end

  describe "#s3_image_urls" do
    it "returns all URLs for the specified variant" do
      urls = record.s3_image_urls(:thumbnail)
      
      expect(urls).to eq([
        "https://test-bucket.s3.ap-south-1.amazonaws.com/my-app/production/images/awesome-widget/thumbnail.webp",
        "https://test-bucket.s3.ap-south-1.amazonaws.com/my-app/production/images/awesome-widget/thumbnail_1.webp",
        "https://test-bucket.s3.ap-south-1.amazonaws.com/my-app/production/images/awesome-widget/thumbnail_2.webp"
      ])
    end

    it "returns empty array when no images" do
      record.image_count = 0
      expect(record.s3_image_urls(:original)).to eq([])
    end
  end

  describe "#s3_image_count" do
    it "returns the image count" do
      expect(record.s3_image_count).to eq(3)
    end

    it "returns 0 when no images" do
      record.image_count = 0
      expect(record.s3_image_count).to eq(0)
    end
  end

  describe "#s3_has_images?" do
    it "returns true when images exist" do
      expect(record.s3_has_images?).to be true
    end

    it "returns false when no images" do
      record.image_count = 0
      expect(record.s3_has_images?).to be false
    end
  end
end
