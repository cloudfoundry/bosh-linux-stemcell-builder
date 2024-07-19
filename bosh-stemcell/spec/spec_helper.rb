require 'rspec'
require 'rspec/its'
require 'fakefs/spec_helpers'
require 'support/shellout_type_assertions.rb'
require 'tmpdir'

Dir.glob(File.expand_path('../support/**/*.rb', __FILE__)).each { |f| require(f) }

# do not truncate array comparison
RSpec.configure do |rspec|
  rspec.expect_with :rspec do |c|
    c.max_formatted_output_length = nil
  end
end

def grub_cfg_path
  if ENV['STEMCELL_INFRASTRUCTURE'] == 'vsphere'
    '/boot/efi/EFI/grub/grub.cfg'
  else
    '/boot/grub/grub.cfg'
  end
end