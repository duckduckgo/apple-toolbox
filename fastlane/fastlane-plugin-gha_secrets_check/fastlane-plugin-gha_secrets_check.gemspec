lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/gha_secrets_check/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-gha_secrets_check'
  spec.version       = Fastlane::GhaSecretsCheck::VERSION
  spec.author        = 'Dominik Kapusta'
  spec.email         = 'dkapusta@duckduckgo.com'

  spec.summary       = 'This plugin verifies if secrets used by GitHub Actions workflows are correctly referenced in their workflow_call definitions'
  # spec.homepage      = "https://github.com/<GITHUB_USERNAME>/fastlane-plugin-gha_secrets_check"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.required_ruby_version = '>= 2.6'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency

  # spec.add_dependency 'your-dependency', '~> 1.0.0'
end
