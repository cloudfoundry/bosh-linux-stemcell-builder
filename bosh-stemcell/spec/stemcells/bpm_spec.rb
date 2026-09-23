require "spec_helper"

describe "Stemcell with BPM", stemcell_image: true do
  context "installed by bosh_bpm" do
    describe file("/usr/libexec/bpm") do
      it { should be_directory }
      it { should be_mode(0o755) }
      it { should be_owned_by("root") }
      its(:group) { should eq("root") }
    end

    %w[
      /usr/libexec/bpm/bin/bpm
      /usr/libexec/bpm/bin/runc
      /usr/libexec/bpm/bin/tini
      /usr/bin/bpm
    ].each do |path|
      describe file(path) do
        it { should be_file }
        it { should be_executable }
      end
    end

    # ShelloutTypes::File resolves symlinks and has no exist?, so test paths
    # with the shell.
    %w[/var/vcap/jobs/bpm /var/vcap/jobs/bpm/bin].each do |path|
      describe command("test -d #{path} && test ! -L #{path}") do
        its(:exit_status) { should eq 0 }
      end
    end

    describe file("/var/vcap/jobs/bpm/bin/bpm") do
      it { should be_file }
      it { should be_linked_to "/usr/bin/bpm" }
    end

    describe file("/var/vcap/jobs") do
      it { should be_directory }
      it { should be_mode(0o750) }
      it { should be_owned_by("root") }
      its(:group) { should eq("vcap") }
    end

    %w[/var/vcap/packages/bpm /var/vcap/bpm /etc/profile.d/bpm.sh /usr/libexec/bpm/lib].each do |path|
      describe command("test ! -e #{path} && test ! -L #{path}") do
        its(:exit_status) { should eq 0 }
      end
    end

    describe command("find /usr/libexec/bpm ! -type l -perm /022 | wc -l") do
      its(:stdout) { should match(/^0$/) }
    end

    describe command("find /usr/libexec/bpm -name '*.a' -o -name '*.h' | wc -l") do
      its(:stdout) { should match(/^0$/) }
    end
  end

  context "runc is statically linked" do
    # runc init runs from a sealed copy of the binary, where no library search
    # path relative to /usr/libexec/bpm resolves.
    describe command("file -b /usr/libexec/bpm/bin/runc") do
      its(:stdout) { should match(/static(-pie)? linked/) }
    end
  end

  context "bpm wrapper and help" do
    describe command("/usr/bin/bpm --help") do
      its(:stdout) { should match(/BPM_PACKAGE_DIR/) }
    end
  end

  context "the symlink watcher" do
    describe file("/usr/libexec/bpm-symlink-watcher") do
      it { should be_file }
      it { should be_executable }
    end

    describe command("file -b /usr/libexec/bpm-symlink-watcher") do
      its(:stdout) { should match(/ELF 64-bit.*statically linked/) }
    end

    describe service("bpm-symlink-watcher.service") do
      it { should be_enabled }
    end

    describe file("/usr/lib/systemd/system/bpm-symlink-watcher.service") do
      its(:content) { should_not match(/^\[Path\]$/) }
      its(:content) { should match(/^Restart=always$/) }
      its(:content) { should match(/^Before=bosh-agent\.service$/) }
      its(:content) { should match(%r{^ExecStart=/usr/libexec/bpm-symlink-watcher$}) }
    end
  end
end
