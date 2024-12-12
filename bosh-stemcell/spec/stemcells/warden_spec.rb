require 'spec_helper'

describe 'Warden Stemcell', stemcell_image: true do
  it_behaves_like 'udf module is disabled'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      its(:content) { should include('warden') }
    end
  end

  context 'auditd config' do
    describe file('/etc/audit/auditd.conf') do
      its(:content) { should include('local_events = no') }
    end
  end

  context 'systemd config' do
    describe file('/etc/systemd/system.conf') do
      its(:content) { should include('DefaultStartLimitBurst=500') }
    end
  end

end
