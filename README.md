# S3 WebP Uploader

[![Gem Version](https://badge.fury.io/rb/s3_webp_uploader.svg)](https://badge.fury.io/rb/s3_webp_uploader)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A lightweight Rails gem for uploading images directly to AWS S3 with automatic WebP conversion and thumbnail generation. Built for simplicity, predictable URLs, and production use.

## Why This Gem?

### The Problem

When building e-commerce or content-heavy Rails applications, you often need:

1. **Predictable image URLs** - For SEO, caching, and debugging
2. **Optimized images** - WebP format with proper sizing
3. **Simple folder structure** - Organized by product/content slug
4. **No Active Storage overhead** - For public images that don't need blob management

**Active Storage limitations for public product images:**
- Generates random blob keys (`abc123xyz789...`) making URLs unpredictable
- Requires database lookups to resolve image URLs
- Overkill for simple public image hosting
- Complex setup for S3 folder prefixes

### The Solution

`s3_webp_uploader` provides:

- **Slug-based URLs**: `https://bucket.s3.region.amazonaws.com/app/prod/images/blue-widget/thumbnail.webp`
- **Automatic WebP conversion**: Optimized file sizes with configurable quality
- **Multiple variants**: Original (1200px) and thumbnail (300px) by default
- **Zero Active Storage**: Direct S3 uploads with `aws-sdk-s3`
- **Image count tracking**: Stored in your model's column or JSON field

## When to Use This Gem

✅ **Use this gem when:**
- You have public product/content images that don't need access control
- You want predictable, SEO-friendly image URLs
- You need automatic WebP conversion and thumbnails
- You want a simple setup without Active Storage complexity
- You're building e-commerce catalogs, portfolios, or content sites

❌ **Don't use this gem when:**
- You need private/authenticated file access
- You need complex file attachments (PDFs, documents, etc.)
- You need multiple storage backends (local, cloud, etc.)
- Active Storage's features align with your needs

## Features

- 🖼️ **WebP Conversion** - Automatic conversion using libvips (fast!)
- 📐 **Smart Resizing** - Configurable max dimensions for original and thumbnail
- 🔗 **Predictable URLs** - Slug-based folder structure for clean URLs
- 🔢 **Image Count Tracking** - Stored in dedicated column or JSON field
- 🔄 **Reindexing** - Automatic reindexing when images are deleted
- 🛠️ **Rails Generator** - Quick setup with migration and initializer
- ⚙️ **Configurable** - Customize sizes, quality, column names, and more

## Requirements

- Ruby 3.0+
- Rails 7.0+
- libvips (for image processing)
- AWS S3 bucket with public read access

## Installation

### 1. Add the Gem

```ruby
# Gemfile
gem "s3_webp_uploader", github: "desingh-rajan/s3_webp_uploader"
```

```bash
bundle install
```

### 2. Install libvips

**Ubuntu/Debian:**
```bash
sudo apt-get install libvips
```

**macOS:**
```bash
brew install vips
```

**Docker:**
```dockerfile
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libvips
```

### 3. Run the Generator

```bash
# For a Product model (default)
bin/rails generate s3_webp_uploader:install

# For a different model
bin/rails generate s3_webp_uploader:install Item

# Skip migration if you already have slug/image_count columns
bin/rails generate s3_webp_uploader:install --no-migration
```

### 4. Run Migration

```bash
bin/rails db:migrate
```

This adds `slug` (string, unique index) and `image_count` (integer, default 0) columns.

## Configuration

### AWS Credentials

Add to Rails credentials:

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

```yaml
aws:
  access_key_id: YOUR_ACCESS_KEY
  secret_access_key: YOUR_SECRET_KEY
```

Or use environment variables:

```bash
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
```

### Gem Configuration

Edit `config/initializers/s3_webp_uploader.rb`:

```ruby
S3WebpUploader.configure do |config|
  # Required: S3 bucket settings
  config.bucket = ENV.fetch("S3_BUCKET", "your-bucket-name")
  config.region = ENV.fetch("S3_REGION", "ap-south-1")
  
  # Prefix for all uploads (recommended: app-name/environment/images)
  app_name = Rails.application.class.module_parent_name.underscore.dasherize
  config.prefix = "#{app_name}/#{Rails.env}/images"
  
  # Column configuration (defaults shown)
  config.identifier_attribute = :slug        # Column used for S3 folder name
  config.count_attribute = :image_count      # Column for storing image count
  
  # Or store count in a JSON column:
  # config.count_column = :specifications    # JSON column name
  # config.count_attribute = :image_count    # Key within the JSON
  
  # Image settings (defaults shown)
  config.original_max_size = 1200            # Max dimension for original
  config.thumbnail_max_size = 300            # Max dimension for thumbnail
  config.webp_quality = 85                   # WebP quality (1-100)
  config.acl = "public-read"                 # S3 ACL for uploaded files
  config.variants = [:original, :thumbnail]  # Generated variants
end
```

### S3 Bucket Setup

#### 1. Create Bucket

```bash
aws s3 mb s3://your-bucket-name --region ap-south-1
```

#### 2. Disable Block Public Access

In AWS Console → S3 → your-bucket → Permissions → Block public access:
- Uncheck "Block all public access"

#### 3. Add Bucket Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadForApp",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::your-bucket-name/your-app/*"
    }
  ]
}
```

## Usage

### Add to Model

```ruby
class Product < ApplicationRecord
  include S3WebpUploader::ImageHelpers
  
  # Ensure you have a slug column (used for S3 folder name)
  # The gem uses config.identifier_attribute (default: :slug)
end
```

### Upload Images (Controller)

```ruby
class Admin::ProductsController < ApplicationController
  def upload_images
    @product = Product.find(params[:id])
    
    if params[:images].present?
      uploader = @product.s3_image_uploader
      indices = uploader.upload_all(params[:images])
      
      if indices.any?
        redirect_to @product, notice: "#{indices.size} image(s) uploaded successfully"
      else
        redirect_to @product, alert: "Failed to upload images"
      end
    end
  end

  def delete_image
    @product = Product.find(params[:id])
    index = params[:index].to_i
    
    if @product.s3_image_uploader.delete(index)
      redirect_to @product, notice: "Image deleted"
    else
      redirect_to @product, alert: "Failed to delete image"
    end
  end
  
  def replace_image
    @product = Product.find(params[:id])
    index = params[:index].to_i
    
    if params[:image].present?
      @product.s3_image_uploader.replace(index, params[:image])
      redirect_to @product, notice: "Image replaced"
    end
  end
end
```

### Display Images (Views)

```erb
<%# Single image %>
<% if @product.s3_has_images? %>
  <%= image_tag @product.s3_thumbnail_url, alt: @product.name %>
<% end %>

<%# Gallery with multiple images %>
<% if @product.s3_has_images? %>
  <div class="product-gallery">
    <% @product.s3_image_count.times do |index| %>
      <figure>
        <a href="<%= @product.s3_original_url(index) %>" data-lightbox="product">
          <%= image_tag @product.s3_thumbnail_url(index), 
                        alt: "#{@product.name} - Image #{index + 1}",
                        loading: "lazy" %>
        </a>
      </figure>
    <% end %>
  </div>
<% end %>

<%# With fallback placeholder %>
<%= image_tag(@product.s3_has_images? ? @product.s3_thumbnail_url : "placeholder.png") %>
```

### Form for Upload

```erb
<%= form_with url: upload_images_admin_product_path(@product), 
              method: :post, 
              local: true,
              multipart: true do |f| %>
  
  <div class="field">
    <%= f.label :images, "Upload Images" %>
    <%= f.file_field :images, multiple: true, accept: "image/*" %>
  </div>
  
  <%= f.submit "Upload" %>
<% end %>
```

### Direct Uploader Access

For more control, use the uploader directly:

```ruby
# Get uploader for a record
uploader = S3WebpUploader.uploader_for(@product)
# Or
uploader = @product.s3_image_uploader

# Upload single image (returns index or nil)
index = uploader.upload(file)

# Upload multiple images (returns array of indices)
indices = uploader.upload_all(files)

# Replace image at specific index
uploader.replace(0, new_file)

# Delete single image (reindexes remaining)
uploader.delete(0)

# Delete all images
uploader.delete_all

# Get URLs
uploader.url(:original, 0)      # First original
uploader.url(:thumbnail, 2)     # Third thumbnail
uploader.urls(:thumbnail)       # All thumbnail URLs

# Info
uploader.count                  # Number of images
uploader.exists?(0)             # Check if image exists at index
```

## Helper Methods Reference

When you include `S3WebpUploader::ImageHelpers`:

| Method | Description | Example |
|--------|-------------|---------|
| `s3_image_uploader` | Get uploader instance | `@product.s3_image_uploader` |
| `s3_thumbnail_url(index = 0)` | Get thumbnail URL | `@product.s3_thumbnail_url(1)` |
| `s3_original_url(index = 0)` | Get original URL | `@product.s3_original_url` |
| `s3_image_urls(variant)` | Get all URLs for variant | `@product.s3_image_urls(:thumbnail)` |
| `s3_image_count` | Number of images | `@product.s3_image_count` |
| `s3_has_images?` | Check if any images exist | `@product.s3_has_images?` |

## S3 URL Structure

The gem creates a predictable folder structure:

```
your-bucket/
└── your-app/
    └── production/
        └── images/
            └── blue-widget/           # Product slug
                ├── original.webp      # First image (index 0)
                ├── thumbnail.webp
                ├── original_1.webp    # Second image (index 1)
                ├── thumbnail_1.webp
                ├── original_2.webp    # Third image (index 2)
                └── thumbnail_2.webp
```

**URL Pattern:**
```
https://{bucket}.s3.{region}.amazonaws.com/{prefix}/{slug}/{variant}.webp
https://{bucket}.s3.{region}.amazonaws.com/{prefix}/{slug}/{variant}_{index}.webp
```

**Example URLs:**
```
https://my-bucket.s3.ap-south-1.amazonaws.com/my-app/production/images/blue-widget/thumbnail.webp
https://my-bucket.s3.ap-south-1.amazonaws.com/my-app/production/images/blue-widget/original_1.webp
```

## Advanced Configuration

### Custom Identifier Column

If your model uses a different column for the unique identifier:

```ruby
S3WebpUploader.configure do |config|
  config.identifier_attribute = :sku  # Use SKU instead of slug
end
```

### Store Count in JSON Column

If you prefer storing image count in a JSON column:

```ruby
S3WebpUploader.configure do |config|
  config.count_column = :metadata       # JSON column name
  config.count_attribute = :photo_count # Key within JSON
end
```

```ruby
# Your model
# metadata: { "photo_count" => 3, "other_data" => "..." }
```

### Custom Image Sizes

```ruby
S3WebpUploader.configure do |config|
  config.original_max_size = 1600   # Larger originals
  config.thumbnail_max_size = 400   # Larger thumbnails
  config.webp_quality = 90          # Higher quality
end
```

## Troubleshooting

### Common Issues

#### 1. AWS Credentials Error

```
Aws::Errors::MissingCredentialsError: unable to sign request without credentials set
```

**Solution:** Ensure credentials are set in Rails credentials or environment variables.

#### 2. 403 Forbidden on Image URLs

**Causes:**
- Bucket "Block Public Access" is enabled
- Missing bucket policy
- Objects not uploaded with `acl: "public-read"`

**Solutions:**
1. Disable "Block all public access" in S3 console
2. Add the bucket policy (see S3 Bucket Setup)
3. For existing files: `aws s3 cp s3://bucket/path/ s3://bucket/path/ --recursive --acl public-read --metadata-directive REPLACE`

#### 3. Image Upload Fails Silently

Check Rails logs for `[S3WebpUploader]` errors. Common causes:
- Invalid image file (not a supported format)
- libvips not installed
- S3 permissions issue

#### 4. libvips Not Found

```
Vips::Error: unable to load ...
```

**Solution:** Install libvips for your platform (see Installation).

## Production Checklist

- [ ] S3 bucket created with public access for your app prefix
- [ ] Bucket policy allows `s3:GetObject` for public read
- [ ] AWS credentials configured (Rails credentials or ENV)
- [ ] libvips installed in production environment
- [ ] `slug` column has unique index
- [ ] Consider CloudFront CDN for faster image delivery

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Commit your changes (`git commit -am 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

This gem is available as open source under the [MIT License](MIT-LICENSE).

## Author

**Desingh Rajan**
- GitHub: [@desingh-rajan](https://github.com/desingh-rajan)
- Website: [desinghrajan.in](https://desinghrajan.in)
