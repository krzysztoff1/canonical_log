# frozen_string_literal: true

require_relative 'lib/canonical_log/version'

Gem::Specification.new do |spec|
  spec.name = 'canonical_log'
  spec.version = CanonicalLog::VERSION
  spec.authors = ['Krzysztof Duda']
  spec.email = ['hello@krzysztof.studio']

  spec.summary = 'One structured JSON log line per request'
  spec.description = 'Implements the canonical log lines / wide events pattern. ' \
                     'Accumulates context throughout a request lifecycle and emits ' \
                     'a single structured JSON log line containing everything interesting.'
  spec.homepage = 'https://github.com/krzysztoff1/canonical_log'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*', 'LICENSE.txt']
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 6.0'
  spec.add_dependency 'rack', '>= 2.0'
end
