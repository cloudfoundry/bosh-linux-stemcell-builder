shared_examples_for 'an os with chrony' do
  describe command('systemctl is-enabled chrony.service') do
    it 'keeps the system clock up to date (stig: V-38620 V-38621)' do
      expect(subject.stdout).to include 'enabled'
    end
  end
end
