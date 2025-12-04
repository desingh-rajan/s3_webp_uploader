# frozen_string_literal: true

RSpec.describe S3WebpUploader do
  it "has a version number" do
    expect(S3WebpUploader::VERSION).not_to be_nil
    expect(S3WebpUploader::VERSION).to eq("0.1.0")
  end

  describe ".configure" do
    it "yields a configuration object" do
      expect { |b| S3WebpUploader.configure(&b) }.to yield_with_args(S3WebpUploader::Configuration)
    end

    it "stores the configuration" do
      S3WebpUploader.configure do |config|
        config.bucket = "my-bucket"
      end

      expect(S3WebpUploader.configuration.bucket).to eq("my-bucket")
    end

    it "allows multiple configurations to be set" do
      S3WebpUploader.configure do |config|
        config.bucket = "my-bucket"
        config.region = "eu-west-1"
        config.prefix = "app/prod/images"
      end

      config = S3WebpUploader.configuration
      expect(config.bucket).to eq("my-bucket")
      expect(config.region).to eq("eu-west-1")
      expect(config.prefix).to eq("app/prod/images")
    end
  end

  describe ".uploader_for" do
    before(:each) do
      S3WebpUploader.configure do |c|
        c.bucket = "test-bucket"
        c.region = "us-east-1"
        c.prefix = "test-app/test/images"
        c.access_key_id = "test-access-key"
        c.secret_access_key = "test-secret-key"
        c.identifier_attribute = :slug  # Reset to default
        c.count_column = nil  # Reset to default
        c.count_attribute = :image_count  # Reset to default
      end
    end

    context "when configured" do
      let(:mock_record_class) do
        klass = Class.new do
          attr_accessor :slug
          
          def initialize(slug:)
            @slug = slug
          end
          
          def read_attribute(attr)
            send(attr) if respond_to?(attr)
          end
          
          def respond_to?(method, include_all = false)
            [:read_attribute, :slug].include?(method) || super
          end
        end
        klass.define_singleton_method(:column_names) { %w[id slug image_count] }
        klass
      end

      it "returns an Uploader instance" do
        record = mock_record_class.new(slug: "test-product")
        uploader = S3WebpUploader.uploader_for(record)
        expect(uploader).to be_a(S3WebpUploader::Uploader)
      end

      it "allows custom identifier" do
        record = mock_record_class.new(slug: "test-product")
        uploader = S3WebpUploader.uploader_for(record, identifier: "custom-slug")
        expect(uploader.identifier).to eq("custom-slug")
      end
    end
  end
end
