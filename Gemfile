source 'https://rubygems.org'

group :development, :test do
  gem 'rake', '~>10.0'
  gem 'rspec'
  gem 'rspec-its'
  gem 'rspec-instafail'
  gem 'bosh-stemcell', path: 'bosh-stemcell'
  gem 'bosh-core'
  gem 'bosh-dev', path: 'bosh-dev'
  gem 'serverspec', '0.15.4'
  gem 'fakefs'
  gem 'timecop'
  # Explicitly do not require serverspec dependency
  # so that it could be monkey patched in a deterministic way
  # in `bosh-stemcell/spec/support/serverspec_monkeypatch.rb`
  gem 'specinfra', '1.15.0', require: nil
  gem 'logging'
end
