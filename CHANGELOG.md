# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-12-04

### Added

- Initial release
- WebP conversion using ruby-vips
- Automatic thumbnail generation (300px max dimension)
- Original image resizing (1200px max dimension)
- Predictable slug-based S3 URL structure
- Image count tracking (dedicated column or JSON column support)
- Rails generator for quick setup (`rails g s3_webp_uploader:install`)
- `ImageHelpers` module for easy model integration
- Configurable image sizes, quality, and S3 settings
- Automatic reindexing when images are deleted
- Support for multiple images per record

### Features

- `upload(file)` - Upload single image
- `upload_all(files)` - Upload multiple images
- `delete(index)` - Delete image at index (auto-reindexes)
- `delete_all` - Delete all images
- `replace(index, file)` - Replace image at index
- `url(variant, index)` - Get URL for specific variant and index
- `urls(variant)` - Get all URLs for a variant
- `exists?(index)` - Check if image exists at index
- `count` - Get current image count

### Configuration Options

- `bucket` - S3 bucket name
- `region` - AWS region
- `prefix` - S3 key prefix (e.g., "app/env/images")
- `access_key_id` - AWS access key (optional if using Rails credentials)
- `secret_access_key` - AWS secret key (optional if using Rails credentials)
- `original_max_size` - Max dimension for original (default: 1200)
- `thumbnail_max_size` - Max dimension for thumbnail (default: 300)
- `webp_quality` - WebP quality 1-100 (default: 85)
- `acl` - S3 ACL (default: "public-read")
- `variants` - Array of variants (default: [:original, :thumbnail])
- `identifier_attribute` - Record attribute for S3 folder (default: :slug)
- `count_attribute` - Attribute for image count (default: :image_count)
- `count_column` - JSON column for count storage (optional)
