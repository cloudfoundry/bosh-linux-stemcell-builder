require 'rspec'
require 'rspec/its'
require 'fakefs/spec_helpers'
require 'support/shellout_type_assertions.rb'

Dir.glob(File.expand_path('../support/**/*.rb', __FILE__)).each { |f| require(f) }
