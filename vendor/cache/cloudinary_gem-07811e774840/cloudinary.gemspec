# -*- encoding: utf-8 -*-
# stub: cloudinary 1.27.0 ruby lib

Gem::Specification.new do |s|
  s.name = "cloudinary".freeze
  s.version = "1.27.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Nadav Soferman".freeze, "Itai Lahan".freeze, "Tal Lev-Ami".freeze]
  s.date = "2023-11-03"
  s.description = "Client library for easily using the Cloudinary service".freeze
  s.email = ["nadav.soferman@cloudinary.com".freeze, "itai.lahan@cloudinary.com".freeze, "tal.levami@cloudinary.com".freeze]
  s.files = [".github/ISSUE_TEMPLATE/bug_report.md".freeze, ".github/ISSUE_TEMPLATE/feature_request.md".freeze, ".github/pull_request_template.md".freeze, ".gitignore".freeze, ".rspec".freeze, ".travis.yml".freeze, "CHANGELOG.md".freeze, "CONTRIBUTING.md".freeze, "Gemfile".freeze, "README.md".freeze, "Rakefile".freeze, "cloudinary.gemspec".freeze, "lib/active_storage/blob_key.rb".freeze, "lib/active_storage/service/cloudinary_service.rb".freeze, "lib/cloudinary.rb".freeze, "lib/cloudinary/account_api.rb".freeze, "lib/cloudinary/account_config.rb".freeze, "lib/cloudinary/api.rb".freeze, "lib/cloudinary/auth_token.rb".freeze, "lib/cloudinary/base_api.rb".freeze, "lib/cloudinary/base_config.rb".freeze, "lib/cloudinary/blob.rb".freeze, "lib/cloudinary/cache.rb".freeze, "lib/cloudinary/cache/breakpoints_cache.rb".freeze, "lib/cloudinary/cache/key_value_cache_adapter.rb".freeze, "lib/cloudinary/cache/rails_cache_adapter.rb".freeze, "lib/cloudinary/cache/storage/rails_cache_storage.rb".freeze, "lib/cloudinary/carrier_wave.rb".freeze, "lib/cloudinary/carrier_wave/error.rb".freeze, "lib/cloudinary/carrier_wave/preloaded.rb".freeze, "lib/cloudinary/carrier_wave/process.rb".freeze, "lib/cloudinary/carrier_wave/remote.rb".freeze, "lib/cloudinary/carrier_wave/storage.rb".freeze, "lib/cloudinary/cloudinary_controller.rb".freeze, "lib/cloudinary/config.rb".freeze, "lib/cloudinary/downloader.rb".freeze, "lib/cloudinary/engine.rb".freeze, "lib/cloudinary/exceptions.rb".freeze, "lib/cloudinary/helper.rb".freeze, "lib/cloudinary/migrator.rb".freeze, "lib/cloudinary/missing.rb".freeze, "lib/cloudinary/ostruct2.rb".freeze, "lib/cloudinary/preloaded_file.rb".freeze, "lib/cloudinary/railtie.rb".freeze, "lib/cloudinary/responsive.rb".freeze, "lib/cloudinary/search.rb".freeze, "lib/cloudinary/search_folders.rb".freeze, "lib/cloudinary/static.rb".freeze, "lib/cloudinary/uploader.rb".freeze, "lib/cloudinary/utils.rb".freeze, "lib/cloudinary/version.rb".freeze, "lib/cloudinary/video_helper.rb".freeze, "lib/tasks/cloudinary/fetch_assets.rake".freeze, "lib/tasks/cloudinary/sync_static.rake".freeze, "tools/allocate_test_cloud.sh".freeze, "tools/get_test_cloud.sh".freeze, "tools/update_version".freeze]
  s.homepage = "http://cloudinary.com".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.5.0.dev".freeze
  s.summary = "Client library for easily using the Cloudinary service".freeze

  s.installed_by_version = "3.5.0.dev" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<aws_cf_signer>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<rest-client>.freeze, [">= 2.0.0"])
  s.add_development_dependency(%q<rexml>.freeze, [">= 0"])
  s.add_development_dependency(%q<actionpack>.freeze, [">= 0"])
  s.add_development_dependency(%q<nokogiri>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 13.0.1"])
  s.add_development_dependency(%q<sqlite3>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 3.5"])
  s.add_development_dependency(%q<rspec-retry>.freeze, [">= 0"])
  s.add_development_dependency(%q<rails>.freeze, ["~> 6.0.3"])
  s.add_development_dependency(%q<rspec-rails>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubyzip>.freeze, [">= 0"])
  s.add_development_dependency(%q<simplecov>.freeze, ["> 0.18.0"])
end
