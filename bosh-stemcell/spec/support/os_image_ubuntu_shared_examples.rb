shared_examples_for 'an Ubuntu-based OS image' do
  context 'X Windows must not be enabled unless required (stig: V-38674)' do
    describe package('xserver-xorg') do
      it { should_not be_installed }
    end
  end
end
