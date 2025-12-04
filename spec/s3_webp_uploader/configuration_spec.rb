# frozen_string_literal: true

RSpec.describe S3WebpUploader::Configuration do
  subject(:config) { described_class.new }

  describe "default values" do
    it "sets default region" do
      expect(config.region).to eq("ap-south-1")
    end

    it "sets default original_max_size" do
      expect(config.original_max_size).to eq(1200)
    end

    it "sets default thumbnail_max_size" do
      expect(config.thumbnail_max_size).to eq(300)
    end

    it "sets default webp_quality" do
      expect(config.webp_quality).to eq(85)
    end

    it "sets default acl" do
      expect(config.acl).to eq("public-read")
    end

    it "sets default variants" do
      expect(config.variants).to eq([:original, :thumbnail])
    end

    it "sets default identifier_attribute" do
      expect(config.identifier_attribute).to eq(:slug)
    end

    it "sets default count_attribute" do
      expect(config.count_attribute).to eq(:image_count)
    end

    it "has nil bucket by default (requires configuration)" do
      # Unless S3_BUCKET env var is set
      original_bucket = ENV["S3_BUCKET"]
      ENV.delete("S3_BUCKET")
      
      fresh_config = described_class.new
      expect(fresh_config.bucket).to be_nil
      
      ENV["S3_BUCKET"] = original_bucket if original_bucket
    end
  end

  describe "#credentials" do
    context "when access_key_id and secret_access_key are set" do
      before do
        config.access_key_id = "test-key"
        config.secret_access_key = "test-secret"
      end

      it "returns AWS credentials" do
        expect(config.credentials).to be_a(Aws::Credentials)
      end
    end

    context "when credentials are not set" do
      it "returns nil" do
        expect(config.credentials).to be_nil
      end
    end
  end

  describe "#base_url" do
    before do
      config.bucket = "my-bucket"
      config.region = "us-west-2"
      config.prefix = "app/prod/images"
    end

    it "returns the correct S3 base URL" do
      expect(config.base_url).to eq("https://my-bucket.s3.us-west-2.amazonaws.com/app/prod/images")
    end
  end

  describe "#validate!" do
    context "when bucket is missing" do
      before do
        config.region = "us-east-1"
        config.access_key_id = "key"
        config.secret_access_key = "secret"
      end

      it "raises an error" do
        expect { config.validate! }.to raise_error(S3WebpUploader::Error, "bucket is required")
      end
    end

    context "when region is missing" do
      before do
        config.bucket = "bucket"
        config.instance_variable_set(:@region, nil)
        config.access_key_id = "key"
        config.secret_access_key = "secret"
      end

      it "raises an error" do
        expect { config.validate! }.to raise_error(S3WebpUploader::Error, "region is required")
      end
    end

    context "when access_key_id is missing" do
      before do
        config.bucket = "bucket"
        config.region = "us-east-1"
        config.secret_access_key = "secret"
      end

      it "raises an error" do
        expect { config.validate! }.to raise_error(S3WebpUploader::Error, "access_key_id is required")
      end
    end

    context "when secret_access_key is missing" do
      before do
        config.bucket = "bucket"
        config.region = "us-east-1"
        config.access_key_id = "key"
      end

      it "raises an error" do
        expect { config.validate! }.to raise_error(S3WebpUploader::Error, "secret_access_key is required")
      end
    end

    context "when all required values are present" do
      before do
        config.bucket = "bucket"
        config.region = "us-east-1"
        config.access_key_id = "key"
        config.secret_access_key = "secret"
      end

      it "does not raise an error" do
        expect { config.validate! }.not_to raise_error
      end
    end
  end

  describe "environment variable defaults" do
    it "reads bucket from S3_BUCKET env var" do
      original = ENV["S3_BUCKET"]
      ENV["S3_BUCKET"] = "env-bucket"
      
      fresh_config = described_class.new
      expect(fresh_config.bucket).to eq("env-bucket")
      
      ENV["S3_BUCKET"] = original if original
      ENV.delete("S3_BUCKET") unless original
    end

    it "reads region from S3_REGION env var" do
      original = ENV["S3_REGION"]
      ENV["S3_REGION"] = "eu-central-1"
      
      fresh_config = described_class.new
      expect(fresh_config.region).to eq("eu-central-1")
      
      ENV["S3_REGION"] = original if original
      ENV.delete("S3_REGION") unless original
    end
  end
end
