$cis_test_cases = Set.new # standard:disable Style/GlobalVars

RSpec.configure do |config|
  config.before(:each) do |example|
    if example.full_description.include? "CIS-"
      $cis_test_cases += example.full_description.scan(/CIS-(?:\d+\.?)+/) # standard:disable Style/GlobalVars
    end
  end
end
