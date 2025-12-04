# frozen_string_literal: true

RSpec.describe S3WebpUploader::Uploader do
  # Mock record class that simulates ActiveRecord behavior
  let(:mock_record_class) do
    klass = Class.new do
      attr_accessor :slug, :image_count, :specifications

      def initialize(slug:, image_count: 0, specifications: {})
        @slug = slug
        @image_count = image_count
        @specifications = specifications
      end

      def read_attribute(attr)
        send(attr)
      end

      def respond_to?(method, include_all = false)
        [:read_attribute, :update_columns, :slug, :image_count, :specifications].include?(method) || super
      end

      def update_columns(attrs)
        attrs.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
        true
      end

      def try(method)
        send(method) if respond_to?(method)
      end
    end
    klass.define_singleton_method(:column_names) { %w[id slug image_count specifications] }
    klass
  end

  let(:record) { mock_record_class.new(slug: "test-product", image_count: 0) }

  # Configure before each test in this file
  before(:each) do
    S3WebpUploader.configure do |config|
      config.bucket = "test-bucket"
      config.region = "us-east-1"
      config.prefix = "test-app/test/images"
      config.access_key_id = "test-access-key"
      config.secret_access_key = "test-secret-key"
    end
  end

  describe "#initialize" do
    it "extracts identifier from record slug" do
      uploader = described_class.new(record)
      expect(uploader.identifier).to eq("test-product")
    end

    it "accepts custom identifier" do
      uploader = described_class.new(record, identifier: "custom-id")
      expect(uploader.identifier).to eq("custom-id")
    end

    it "accepts string as record (uses string as identifier)" do
      uploader = described_class.new("string-identifier")
      expect(uploader.identifier).to eq("string-identifier")
    end

    context "when identifier is blank" do
      let(:record_without_slug) do
        mock_record_class.new(slug: "", image_count: 0)
      end

      it "raises an error" do
        expect { described_class.new(record_without_slug) }
          .to raise_error(S3WebpUploader::Error, "identifier cannot be blank")
      end
    end

    context "when configuration is invalid" do
      it "raises an error" do
        S3WebpUploader.configuration.bucket = nil
        expect { described_class.new(record) }
          .to raise_error(S3WebpUploader::Error, "bucket is required")
      end
    end
  end

  describe "#url" do
    subject(:uploader) { described_class.new(record) }

    it "returns correct URL for original variant" do
      expected = "https://test-bucket.s3.us-east-1.amazonaws.com/test-app/test/images/test-product/original.webp"
      expect(uploader.url(:original, 0)).to eq(expected)
    end

    it "returns correct URL for thumbnail variant" do
      expected = "https://test-bucket.s3.us-east-1.amazonaws.com/test-app/test/images/test-product/thumbnail.webp"
      expect(uploader.url(:thumbnail, 0)).to eq(expected)
    end

    it "returns correct URL for second image" do
      expected = "https://test-bucket.s3.us-east-1.amazonaws.com/test-app/test/images/test-product/original_1.webp"
      expect(uploader.url(:original, 1)).to eq(expected)
    end

    it "returns correct URL for third thumbnail" do
      expected = "https://test-bucket.s3.us-east-1.amazonaws.com/test-app/test/images/test-product/thumbnail_2.webp"
      expect(uploader.url(:thumbnail, 2)).to eq(expected)
    end

    it "defaults to original variant and index 0" do
      expected = "https://test-bucket.s3.us-east-1.amazonaws.com/test-app/test/images/test-product/original.webp"
      expect(uploader.url).to eq(expected)
    end
  end

  describe "#urls" do
    let(:record) { mock_record_class.new(slug: "test-product", image_count: 3) }
    subject(:uploader) { described_class.new(record) }

    it "returns all URLs for a variant" do
      urls = uploader.urls(:thumbnail)
      
      expect(urls).to eq([
        "https://test-bucket.s3.us-east-1.amazonaws.com/test-app/test/images/test-product/thumbnail.webp",
        "https://test-bucket.s3.us-east-1.amazonaws.com/test-app/test/images/test-product/thumbnail_1.webp",
        "https://test-bucket.s3.us-east-1.amazonaws.com/test-app/test/images/test-product/thumbnail_2.webp"
      ])
    end

    it "returns empty array when no images" do
      record.image_count = 0
      expect(uploader.urls(:original)).to eq([])
    end
  end

  describe "#count" do
    it "returns the current image count from record" do
      record.image_count = 5
      uploader = described_class.new(record)
      expect(uploader.count).to eq(5)
    end

    it "returns 0 when image_count is nil" do
      record.image_count = nil
      uploader = described_class.new(record)
      expect(uploader.count).to eq(0)
    end
  end

  describe "#upload" do
    subject(:uploader) { described_class.new(record) }

    let(:mock_file) do
      file = double("UploadedFile")
      allow(file).to receive(:content_type).and_return("image/jpeg")
      allow(file).to receive(:tempfile).and_return(
        double("Tempfile", path: "/tmp/test.jpg")
      )
      file
    end

    before do
      # Stub S3 client
      s3_client = instance_double(Aws::S3::Client)
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(s3_client).to receive(:put_object).and_return(true)
    end

    it "validates the file is an image" do
      invalid_file = double("UploadedFile", content_type: "text/plain")
      expect(uploader.upload(invalid_file)).to be_nil
    end

    it "returns nil for non-image content type" do
      pdf_file = double("UploadedFile", content_type: "application/pdf")
      expect(uploader.upload(pdf_file)).to be_nil
    end

    it "accepts image/jpeg content type" do
      jpeg_file = double("UploadedFile")
      allow(jpeg_file).to receive(:content_type).and_return("image/jpeg")
      allow(jpeg_file).to receive(:tempfile).and_return(
        double("Tempfile", path: "/tmp/test.jpg")
      )
      
      # This will try to process the file, but our Vips stub handles it
      result = uploader.upload(jpeg_file)
      expect(result).to eq(0) # First image, index 0
    end

    it "accepts image/png content type" do
      png_file = double("UploadedFile")
      allow(png_file).to receive(:content_type).and_return("image/png")
      allow(png_file).to receive(:tempfile).and_return(
        double("Tempfile", path: "/tmp/test.png")
      )
      
      result = uploader.upload(png_file)
      expect(result).to eq(0)
    end

    it "increments image count after successful upload" do
      expect { uploader.upload(mock_file) }
        .to change { record.image_count }.from(0).to(1)
    end
  end

  describe "#upload_all" do
    subject(:uploader) { described_class.new(record) }

    let(:mock_files) do
      3.times.map do |i|
        file = double("UploadedFile#{i}")
        allow(file).to receive(:content_type).and_return("image/jpeg")
        allow(file).to receive(:tempfile).and_return(
          double("Tempfile", path: "/tmp/test#{i}.jpg")
        )
        file
      end
    end

    before do
      s3_client = instance_double(Aws::S3::Client)
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(s3_client).to receive(:put_object).and_return(true)
    end

    it "uploads multiple files and returns indices" do
      indices = uploader.upload_all(mock_files)
      expect(indices).to eq([0, 1, 2])
    end

    it "handles single file wrapped in array" do
      indices = uploader.upload_all([mock_files.first])
      expect(indices).to eq([0])
    end

    it "handles nil gracefully" do
      indices = uploader.upload_all(nil)
      expect(indices).to eq([])
    end
  end

  describe "#delete" do
    let(:record) { mock_record_class.new(slug: "test-product", image_count: 3) }
    subject(:uploader) { described_class.new(record) }

    before do
      s3_client = instance_double(Aws::S3::Client)
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(s3_client).to receive(:delete_object).and_return(true)
      allow(s3_client).to receive(:copy_object).and_return(true)
    end

    it "returns false for negative index" do
      expect(uploader.delete(-1)).to be false
    end

    it "returns false for index >= count" do
      expect(uploader.delete(3)).to be false
      expect(uploader.delete(10)).to be false
    end

    it "returns true for valid index" do
      expect(uploader.delete(0)).to be true
    end

    it "decrements the image count" do
      expect { uploader.delete(1) }
        .to change { record.image_count }.from(3).to(2)
    end
  end

  describe "#delete_all" do
    let(:record) { mock_record_class.new(slug: "test-product", image_count: 3) }
    subject(:uploader) { described_class.new(record) }

    before do
      s3_client = instance_double(Aws::S3::Client)
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(s3_client).to receive(:delete_object).and_return(true)
    end

    it "returns true" do
      expect(uploader.delete_all).to be true
    end

    it "sets image count to 0" do
      expect { uploader.delete_all }
        .to change { record.image_count }.from(3).to(0)
    end
  end

  describe "#replace" do
    let(:record) { mock_record_class.new(slug: "test-product", image_count: 3) }
    subject(:uploader) { described_class.new(record) }

    let(:mock_file) do
      file = double("UploadedFile")
      allow(file).to receive(:content_type).and_return("image/jpeg")
      allow(file).to receive(:tempfile).and_return(
        double("Tempfile", path: "/tmp/test.jpg")
      )
      file
    end

    before do
      s3_client = instance_double(Aws::S3::Client)
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(s3_client).to receive(:delete_object).and_return(true)
      allow(s3_client).to receive(:put_object).and_return(true)
    end

    it "returns nil for invalid file" do
      invalid_file = double("UploadedFile", content_type: "text/plain")
      expect(uploader.replace(0, invalid_file)).to be_nil
    end

    it "returns nil for negative index" do
      expect(uploader.replace(-1, mock_file)).to be_nil
    end

    it "returns nil for index >= count" do
      expect(uploader.replace(3, mock_file)).to be_nil
    end

    it "returns the index for valid replacement" do
      expect(uploader.replace(1, mock_file)).to eq(1)
    end

    it "does not change image count" do
      expect { uploader.replace(1, mock_file) }
        .not_to change { record.image_count }
    end
  end

  describe "#exists?" do
    subject(:uploader) { described_class.new(record) }

    let(:s3_client) { instance_double(Aws::S3::Client) }

    before do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    end

    it "returns true when object exists" do
      allow(s3_client).to receive(:head_object).and_return(true)
      expect(uploader.exists?(0)).to be true
    end

    it "returns false when object does not exist" do
      allow(s3_client).to receive(:head_object)
        .and_raise(Aws::S3::Errors::NotFound.new(nil, "Not Found"))
      expect(uploader.exists?(0)).to be false
    end
  end

  describe "count storage with JSON column" do
    let(:json_record_class) do
      klass = Class.new do
        attr_accessor :sku, :metadata

        def initialize(sku:, metadata: {})
          @sku = sku
          @metadata = metadata
        end

        def read_attribute(attr)
          send(attr)
        end

        def respond_to?(method, include_all = false)
          [:read_attribute, :update_columns, :sku, :metadata].include?(method) || super
        end

        def update_columns(attrs)
          attrs.each do |key, value|
            send("#{key}=", value) if respond_to?("#{key}=")
          end
          true
        end

        def try(method)
          send(method) if respond_to?(method)
        end
      end
      klass.define_singleton_method(:column_names) { %w[id sku metadata] }
      klass
    end

    let(:record) { json_record_class.new(sku: "SKU-123", metadata: { "photo_count" => 5 }) }

    before(:each) do
      S3WebpUploader.configure do |config|
        config.bucket = "test-bucket"
        config.region = "us-east-1"
        config.prefix = "test-app/test/images"
        config.access_key_id = "test-access-key"
        config.secret_access_key = "test-secret-key"
        config.identifier_attribute = :sku
        config.count_column = :metadata
        config.count_attribute = :photo_count
      end
    end

    it "uses custom identifier attribute" do
      uploader = described_class.new(record)
      expect(uploader.identifier).to eq("SKU-123")
    end

    it "reads count from JSON column" do
      uploader = described_class.new(record)
      expect(uploader.count).to eq(5)
    end

    it "updates count in JSON column" do
      s3_client = instance_double(Aws::S3::Client)
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(s3_client).to receive(:delete_object).and_return(true)

      record.metadata = { "photo_count" => 1 }
      uploader = described_class.new(record)
      uploader.delete_all

      expect(record.metadata["photo_count"]).to eq(0)
    end
  end
end
