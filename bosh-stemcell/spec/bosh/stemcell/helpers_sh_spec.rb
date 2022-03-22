require 'spec_helper'

context 'helpers.sh' do
  context '#disable'

  context '#enable'

  context '#run_in_chroot' do
    context 'in root dir' do
      describe ShelloutTypes::Command.new(
        '../../../assets/run_in_chroot_pwd.sh',
        ShelloutTypes::Chroot.new('/')
      ) do
        its(:stdout) { should eq('/') }
        its(:exit_status) { should eq(0) }
      end
    end

    context 'in /bin dir' do
      describe ShelloutTypes::Command.new(
        '../../../assets/run_in_chroot_pwd.sh',
        ShelloutTypes::Chroot.new('/bin')
      ) do
        its(:stdout) { should eq('/bin') }
        its(:exit_status) { should eq(0) }
      end
    end

    context 'returns the executed script\'s exit code'  do
      describe ShelloutTypes::Command.new(
        '../../../assets/run_in_chroot_exit_with_error.sh',
        ShelloutTypes::Chroot.new('/bin')
      ) do
        its(:stdout) { should include '/bin' }
        its(:exit_status) { should eq(12) }
      end
    end
  end

  context '#on_exit'

  context '#add_on_exit' do
    context 'runs cleanup commands in LIFO order' do
      describe ShelloutTypes::Command.new(
        File.expand_path(
          '../../../assets/on_exit_with_normal_completion.sh',
          __FILE__
        ),
        ShelloutTypes::Chroot.new('/')
      ) do
        it('describes the on_exit actions in that order') { expect(subject.stdout).to match <<EOF }
end of script
Running 4 on_exit items...
Running cleanup command echo fourth on_exit action (try: 0)
fourth on_exit action
Running cleanup command echo third on_exit action (try: 0)
third on_exit action
Running cleanup command echo second on_exit action (try: 0)
second on_exit action
Running cleanup command echo first on_exit action (try: 0)
first on_exit action
EOF
      end

      describe ShelloutTypes::Command.new(
        File.expand_path(
          '../../../assets/on_exit_with_error_exit.sh',
          __FILE__
        ),
        ShelloutTypes::Chroot.new('/')
      ) do
        it('describes the on_exit actions in that order') { expect(subject.stdout).to match <<EOF }
Running 2 on_exit items...
Running cleanup command echo second on_exit action (try: 0)
second on_exit action
Running cleanup command echo first on_exit action (try: 0)
first on_exit action
EOF
      end
    end

    describe ShelloutTypes::Command.new(
      File.expand_path(
        '../../../assets/on_exit_with_failing_cleanup_command.sh',
        __FILE__
      ),
      ShelloutTypes::Chroot.new('/')
    ) do
      it('includes a retry count in its output') { expect(subject.stdout).to match <<EOF }
end of script
Running 1 on_exit items...
Running cleanup command false (try: 0)
Running cleanup command false (try: 1)
Running cleanup command false (try: 2)
Running cleanup command false (try: 3)
Running cleanup command false (try: 4)
Running cleanup command false (try: 5)
Running cleanup command false (try: 6)
Running cleanup command false (try: 7)
Running cleanup command false (try: 8)
Running cleanup command false (try: 9)
EOF
    end
  end

end
