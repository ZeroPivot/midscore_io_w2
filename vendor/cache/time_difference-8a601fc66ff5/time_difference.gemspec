# -*- encoding: utf-8 -*-
# stub: time_difference 0.4.2 ruby lib

Gem::Specification.new do |s|
  s.name = "time_difference".freeze
  s.version = "0.4.2".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["TM Lee".freeze]
  s.date = "2024-03-01"
  s.description = "TimeDifference is the missing Ruby method to calculate difference between two given time. You can do a Ruby time difference in year, month, week, day, hour, minute, and seconds.".freeze
  s.email = ["tmlee.ltm@gmail.com".freeze]
  s.files = [".gitignore".freeze, ".travis.yml".freeze, "CHANGELOG.md".freeze, "Gemfile".freeze, "Gemfile.activesupport32".freeze, "LICENSE".freeze, "README.md".freeze, "Rakefile".freeze, "lib/time_difference.rb".freeze, "spec/spec_helper.rb".freeze, "spec/time_difference_spec.rb".freeze, "time_difference.gemspec".freeze]
  s.homepage = "".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.5.6".freeze
  s.summary = "TimeDifference is the missing Ruby method to calculate difference between two given time. You can do a Ruby time difference in year, month, week, day, hour, minute, and seconds.".freeze
  s.test_files = ["spec/spec_helper.rb".freeze, "spec/time_difference_spec.rb".freeze]

  s.installed_by_version = "3.5.6".freeze if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 2.13.0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
end
