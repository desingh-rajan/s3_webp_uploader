# S3 WebP Uploader

A Rails gem for uploading images to S3 with automatic WebP conversion and thumbnail generation.

## Features

- **WebP conversion** - Automatically converts images to WebP format
- **Thumbnails** - Generates original (1200px) and thumbnail (300px) variants
- **Predictable URLs** - Uses slug-based folder structure for SEO-friendly URLs
- **Simple API** - Easy to use helper methods for your models
- **Configurable** - Customize column names, sizes, and S3 settings

## Installation

Add to your Gemfile:

```ruby
gem "s3_webp_uploader", github: "desingh-rajan/s3_webp_uploader"
```

Run the generator:

```bash
# For a Product model (default)
bin/rails generate s3_webp_uploader:install

# For a different model
bin/rails generate s3_webp_uploader:install Item

# Skip migration if you already have the columns
bin/rails generate s3_webp_uploader:install --no-migration
```

Run the migration:

```bash
bin/rails db:migrate
```

## Configuration

Edit `config/initializers/s3_webp_uploader.rb`:

```ruby
S3WebpUploader.configure do |config|
  # Required: S3 bucket settings
  config.bucket = "your-bucket-name"
  config.region = "ap-south-1"
  
  # Prefix for all uploads
  config.prefix = "my-app/#{Rails.env}/images"
  
  # Custom column names (if different from defaults)
  config.identifier_attribute = :slug        # Default: :slug
  config.count_attribute = :image_count      # Default: :image_count
  
  # Or store count in a JSON column:
  # config.count_column = :metadata
  # config.count_attribute = :photos_count   # Key within the JSON
  
  # Image settings (optional)
  config.original_max_size = 1200
  config.thumbnail_max_size = 300
  config.webp_quality = 85
end
```

Add AWS credentials:

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

```yaml
aws:
  access_key_id: YOUR_ACCESS_KEY
  secret_access_key: YOUR_SECRET_KEY
```

## Usage

### Add to Model

```ruby
class Product < ApplicationRecord
  include S3WebpUploader::ImageHelpers
end
```

### In Views

```erb
<% if @product.s3_has_images? %>
  <%= image_tag @product.s3_thumbnail_url %>
  
  <%# Multiple images %>
  <% @product.s3_image_count.times do |i| %>
    <%= image_tag @product.s3_thumbnail_url(i) %>
  <% end %>
<% end %>
```

### Upload in Controller

```ruby
def upload_images
  uploader = @product.s3_image_uploader
  uploader.upload_all(params[:images])
  redirect_to @product
end

def delete_image
  @product.s3_image_uploader.delete(params[:index].to_i)
  redirect_to @product
end
```

### Direct Uploader Access

```ruby
# Get uploader for a record
uploader = S3WebpUploader.uploader_for(@product)

# Upload
uploader.upload(file)           # Returns index
uploader.upload_all(files)      # Returns array of indices

# Delete
uploader.delete(0)              # Delete by index
uploader.delete_all             # Delete all images

# Replace
uploader.replace(0, new_file)   # Replace image at index

# URLs
uploader.url(:thumbnail, 0)     # Get URL
uploader.urls(:original)        # Get all URLs for variant

# Info
uploader.count                  # Number of images
uploader.exists?(0)             # Check if image exists
```

## Helper Methods

When you include `S3WebpUploader::ImageHelpers`:

| Method | Description |
|--------|-------------|
| `s3_image_uploader` | Get uploader instance |
| `s3_thumbnail_url(index = 0)` | Thumbnail URL |
| `s3_original_url(index = 0)` | Original URL |
| `s3_image_count` | Number of images |
| `s3_has_images?` | Check if any images |
| `s3_all_thumbnail_urls` | Array of all thumbnail URLs |
| `s3_all_original_urls` | Array of all original URLs |

## S3 URL Pattern

```
https://{bucket}.s3.{region}.amazonaws.com/{prefix}/{slug}/original.webp
https://{bucket}.s3.{region}.amazonaws.com/{prefix}/{slug}/thumbnail.webp
https://{bucket}.s3.{region}.amazonaws.com/{prefix}/{slug}/original_1.webp
https://{bucket}.s3.{region}.amazonaws.com/{prefix}/{slug}/thumbnail_1.webp
```

## Requirements

- Ruby 3.0+
- Rails 7.0+
- libvips (for image processing)
- AWS S3 bucket with public read access

### Dockerfile

```dockerfile
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libvips
```

## License

MIT
