# S3 WebP Uploader

Simple S3 image uploads with automatic WebP conversion for Rails. No Active Storage pollution.

## Features

- 🖼️ Automatic WebP conversion with libvips
- 📐 Configurable image sizes (original + thumbnail)
- 🗂️ Predictable URL structure: `{bucket}/{prefix}/{identifier}/original.webp`
- 🔢 Multiple images per record with automatic indexing
- 🚀 No model pollution - use standalone or with minimal helpers
- ⚡ Simple API

## Installation

Add to your Gemfile:

```ruby
gem "s3_webp_uploader", git: "https://github.com/desingh-rajan/s3_webp_uploader"
```

Run the installer:

```bash
bundle install
rails generate s3_webp_uploader:install
```

## Configuration

Edit `config/initializers/s3_webp_uploader.rb`:

```ruby
S3WebpUploader.configure do |config|
  config.bucket = "your-bucket-name"
  config.region = "ap-south-1"
  config.prefix = "my-app/#{Rails.env}/images"
  
  # Optional - auto-loaded from Rails credentials
  # config.access_key_id = ENV["AWS_ACCESS_KEY_ID"]
  # config.secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
  
  # Image settings
  config.original_max_size = 1200    # Max dimension for original
  config.thumbnail_max_size = 300    # Max dimension for thumbnail
  config.webp_quality = 85           # WebP quality (1-100)
  config.acl = "public-read"         # S3 ACL
  config.variants = [:original, :thumbnail]
end
```

Add AWS credentials to `config/credentials.yml.enc`:

```yaml
aws:
  access_key_id: YOUR_ACCESS_KEY
  secret_access_key: YOUR_SECRET_KEY
```

## Usage

### Standalone (Recommended - No Model Pollution)

```ruby
# In controller
def upload_images
  @product = Product.find(params[:id])
  uploader = S3WebpUploader.uploader_for(@product)
  
  uploader.upload(params[:image])           # Upload single image
  uploader.upload_all(params[:images])      # Upload multiple
  uploader.replace(0, params[:new_image])   # Replace at index
  uploader.delete(0)                        # Delete at index
  uploader.delete_all                       # Delete all
end

# In view
<% uploader = S3WebpUploader.uploader_for(@product) %>
<%= image_tag uploader.url(:thumbnail, 0) %>
<%= image_tag uploader.url(:original, 0) %>

<% uploader.urls(:thumbnail).each do |url| %>
  <%= image_tag url %>
<% end %>
```

### With Custom Identifier

```ruby
# Use any string as folder name
uploader = S3WebpUploader.uploader_for(@product, identifier: "custom-folder-name")

# Or use a different attribute
uploader = S3WebpUploader.uploader_for(@product, identifier: @product.sku)
```

### Optional Model Helpers

If you prefer convenience methods on the model:

```ruby
class Product < ApplicationRecord
  include S3WebpUploader::ImageHelpers
  
  # Now you can use:
  # @product.s3_thumbnail_url(0)
  # @product.s3_original_url(0)
  # @product.s3_image_urls(:thumbnail)
  # @product.s3_has_images?
end
```

## URL Structure

```
https://{bucket}.s3.{region}.amazonaws.com/{prefix}/{identifier}/original.webp
https://{bucket}.s3.{region}.amazonaws.com/{prefix}/{identifier}/thumbnail.webp

# Multiple images
https://{bucket}.s3.{region}.amazonaws.com/{prefix}/{identifier}/original_1.webp
https://{bucket}.s3.{region}.amazonaws.com/{prefix}/{identifier}/thumbnail_1.webp
```

## Image Count Storage

The gem expects your model to store image count in one of these ways:

```ruby
# Option 1: image_count column
add_column :products, :image_count, :integer, default: 0

# Option 2: JSON specifications column (what vega-tools uses)
# Stores as: { "image_count" => 3, ... }
add_column :products, :specifications, :json, default: {}
```

## S3 Bucket Setup

1. Create bucket with public access enabled
2. Add bucket policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicRead",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::your-bucket/your-app/*"
  }]
}
```

## Requirements

- Ruby >= 3.0
- Rails >= 7.0
- libvips (for WebP conversion)

### Installing libvips

```bash
# macOS
brew install vips

# Ubuntu/Debian
apt-get install libvips

# Dockerfile
RUN apt-get install --no-install-recommends -y libvips
```

## License

MIT
