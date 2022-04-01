require 'spec_helper'

describe 'RHEL 7 stemcell', stemcell_image: true do

  it_behaves_like 'All Stemcells'
  it_behaves_like 'a CentOS or RHEL stemcell'
  it_behaves_like 'udf module is disabled'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/operating_system') do
      its(:content) { should include('centos') }
    end
  end

  context 'installed by bosh_openstack_agent_settings', {
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_azure: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      its(:content) { should_not include('"CreatePartitionIfNoEphemeralDisk": true') }
      its(:content) { should include('"Type": "ConfigDrive"') }
      its(:content) { should include('"Type": "HTTP"') }
    end
  end

  describe 'installed packages' do
    # NOTE: Installed packages' names aren't necessarily unique, which is why there are some duplicate names.
    # However, including the VERSION, RELEASE, and/or ARCH values would make this spec fail if any of those values vary between builds.
    # SEE: https://prefetch.net/blog/2009/05/19/duplicate-rpm-names-are-showing-up-in-the-rpm-query-output/
    # rpm_list_packages = 'rpm --query --all --queryformat="%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n"'
    rpm_list_packages = 'rpm --query --all --queryformat="%{NAME}\n"'

    let(:rpm_list_rhel) { File.readlines(spec_asset('rpm-list-rhel-7.txt')).map(&:chop) }
    let(:rpm_list_google_rhel) { File.readlines(spec_asset('rpm-list-rhel-7-google-additions.txt')).map(&:chop) }
    let(:rpm_list_vsphere_rhel) { File.readlines(spec_asset('rpm-list-rhel-7-vsphere-additions.txt')).map(&:chop) }
    let(:rpm_list_azure_rhel) { File.readlines(spec_asset('rpm-list-rhel-7-azure-additions.txt')).map(&:chop) }

    describe command(rpm_list_packages), {
      exclude_on_google: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_azure: true,
    } do
      it 'contains only the base set of packages for aws, openstack, warden' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list_rhel)
      end
    end

    describe command(rpm_list_packages), {
      exclude_on_aws: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
    } do
      it 'contains only the base set of packages plus google-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list_rhel.concat(rpm_list_google_rhel))
      end
    end

    describe command(rpm_list_packages), {
      exclude_on_aws: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
    } do
      it 'contains only the base set of packages plus vsphere-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list_rhel.concat(rpm_list_vsphere_rhel))
      end
    end

    describe command(rpm_list_packages), {
      exclude_on_aws: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_openstack: true,
    } do
      it 'contains only the base set of packages plus azure-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list_rhel.concat(rpm_list_azure_rhel))
      end
    end
  end

end
