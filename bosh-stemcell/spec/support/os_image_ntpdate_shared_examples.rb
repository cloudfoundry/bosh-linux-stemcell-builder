shared_examples_for 'an os with ntpdate' do
  describe command('crontab -l') do
    it 'keeps the system clock up to date (stig: V-38620 V-38621)' do
      expect(subject.stdout).to include '0,15,30,45 * * * * /var/vcap/bosh/bin/sync-time'
    end
  end
end
