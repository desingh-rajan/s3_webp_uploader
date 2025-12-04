Gem::Specification.new do |spec|
  spec.name          = "s3_webp_uploader"
  spec.version       = "0.1.0"
  spec.authors       = ["Desingh Rajan"]
  spec.email         = ["desinghrajan@gmail.com"]

  spec.summary       = "Simple S3 image uploads with WebP conversion for Rails"
  spec.description   = "Upload images to S3 with automatic WebP conversion, thumbnails, and predictable URL structure. No Active Storage pollution."
  spec.homepage      = "https://github.com/desingh-rajan/s3_webp_uploader"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/desingh-rajan/s3_webp_uploader"
  spec.metadata["changelog_uri"] = "https://github.com/desingh-rajan/s3_webp_uploader/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "MIT-LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-s3", "~> 1.0"
  spec.add_dependency "ruby-vips", ">= 2.1"
  spec.add_dependency "rails", ">= 7.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
