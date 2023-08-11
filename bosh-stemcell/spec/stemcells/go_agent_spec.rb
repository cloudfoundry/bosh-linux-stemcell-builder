require 'spec_helper'

describe 'Stemcell with Go Agent', stemcell_image: true do
  describe 'installed by bosh_go_agent' do
    %w(bosh-agent bosh-agent-rc bosh-blobstore-dav bosh-blobstore-gcs bosh-blobstore-s3 bosh-blobstore-az).each do |binary|
      describe file("/var/vcap/bosh/bin/#{binary}") do
        it { should be_file }
        it { should be_executable }
      end
    end

    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
    end

    describe 'set user/group owner and permission on /etc/crontab (CIS-9.1.2)' do
      context file('/etc/crontab') do
        it { should be_mode(0600) }
        it { should be_owned_by('root') }
        its(:group) { should eq('root') }
      end
    end

    describe 'set user/group owner and permission on /etc/cron.hourly (CIS-9.1.3)' do
      context file('/etc/cron.hourly') do
        it { should be_directory }
        it { should be_mode(0700) }
        it { should be_owned_by('root') }
        its(:group) { should eq('root') }
      end
    end

    describe 'set user/group owner and permission on /etc/cron.daily (CIS-9.1.4)' do
      context file('/etc/cron.daily') do
        it { should be_directory }
        it { should be_mode(0700) }
        it { should be_owned_by('root') }
        its(:group) { should eq('root') }
      end
    end

    describe 'set user/group owner and permission on /etc/cron.weekly (CIS-9.1.5)' do
      context file('/etc/cron.weekly') do
        it { should be_directory }
        it { should be_mode(0700) }
        it { should be_owned_by('root') }
        its(:group) { should eq('root') }
      end
    end

    describe 'set user/group owner and permission on /etc/cron.monthly (CIS-9.1.6)' do
      context file('/etc/cron.monthly') do
        it { should be_directory }
        it { should be_mode(0700) }
        it { should be_owned_by('root') }
        its(:group) { should eq('root') }
      end
    end

    describe 'set user/group owner and permission on /etc/cron.d (CIS-9.1.7)' do
      context file('/etc/cron.d') do
        it { should be_directory }
        it { should be_mode(0700) }
        it { should be_owned_by('root') }
        its(:group) { should eq('root') }
      end
    end

    describe 'restrict at/cron to authorized users (CIS-9.1.8)' do
      context file('/etc/cron.deny') do
        it { should_not be_file }
      end

      context file('/etc/at.deny') do
        it { should_not be_file }
      end

      {
          '/etc/cron.allow' => { mode: 0600, owner: 'root', group: 'root' },
          '/etc/at.allow' => { mode: 0600, owner: 'root', group: 'root' },
      }.each do |file_name, properties|

        context file(file_name) do
          it { should be_mode(properties[:mode]) }
          it { should be_owned_by(properties[:owner]) }
          its(:group) { should eq(properties[:group]) }
        end
      end
    end

    describe '/var/lock' do
      subject do
        output = command("stat -L -c %#{operator} /var/lock")
        output.stdout.split.first
      end

      describe 'owned by' do
        let(:operator) { 'U' }
        it { should eq('root') }
      end

      describe 'mode' do
        let(:operator) { 'a' }
        it { should eq('770') }
      end

      describe 'grouped into' do
        let(:operator) { 'G' }
        it { should eq('vcap') }
      end
    end

    %w(/etc/cron.allow /etc/at.allow).each do |allow_file|
      describe file(allow_file) do
        it('contains exactly vcap') { expect(subject.content).to match(/\Avcap\Z/)}
      end
    end

    describe file('/var/vcap/data') do
      it { should_not be_directory }
    end

    describe file('/var/vcap/monit/alerts.monitrc') do
      its(:content) { should match('set alert agent@local') }
    end
  end
end
