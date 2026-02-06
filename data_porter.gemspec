# frozen_string_literal: true

require_relative "lib/data_porter/version"

Gem::Specification.new do |spec|
  spec.name = "data_porter"
  spec.version = DataPorter::VERSION
  spec.authors = ["Seryl Lounis"]
  spec.email = ["seryllounis@outlook.fr"]

  spec.summary = "Rails engine for multi-step data imports with preview"
  spec.description = "A mountable Rails engine providing a complete data import workflow: " \
                     "upload/configure, preview with validation, and import. " \
                     "Supports CSV, JSON, and API sources with a simple DSL for defining import targets."
  spec.homepage = "https://github.com/SerylLns/data_porter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/SerylLns/data_porter"
  spec.metadata["changelog_uri"] = "https://github.com/SerylLns/data_porter/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mcp_server_uri"] = "https://rubygems.org/gems/data_porter"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "csv"
  spec.add_dependency "phlex", ">= 1.0"
  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "store_model", ">= 2.0"
  spec.add_dependency "turbo-rails", ">= 1.0"
end
