# frozen_string_literal: true

require_relative "lib/super8/version"

Gem::Specification.new do |spec|
  spec.name = "super8"
  spec.version = Super8::VERSION
  spec.authors = ["John Cipriano"]
  spec.email = ["johnmikecip@gmail.com"]

  spec.summary = "Record and replay ruby-odbc sessions for easier, more accurate testing."
  spec.description = "Super 8 is a \"vcr\"-like library for recording and playing back ODBC " \
                     "interactions made with ruby-odbc, for use with automated testing. More " \
                     "accurate than manually mocking and less work than adding an ODBC-enabled " \
                     "server to your test stack."
  spec.homepage = "https://github.com/johncip/super8"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/johncip/super8"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir["lib/**/*", "spec/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "ruby-odbc"

  # Development dependencies
  spec.add_development_dependency "fakefs"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
