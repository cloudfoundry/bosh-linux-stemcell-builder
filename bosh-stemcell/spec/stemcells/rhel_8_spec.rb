require 'spec_helper'

describe 'RHEL 8 stemcell', stemcell_image: true do

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

    let(:rpm_list) { File.readlines(spec_asset('rpm-list-rhel-8.txt')).map(&:chop) }
    let(:rpm_list_google) { File.readlines(spec_asset('rpm-list-rhel-8-google-additions.txt')).map(&:chop) }
    let(:rpm_list_vsphere) { File.readlines(spec_asset('rpm-list-rhel-8-vsphere-additions.txt')).map(&:chop) }
    let(:rpm_list_azure) { File.readlines(spec_asset('rpm-list-rhel-8-azure-additions.txt')).map(&:chop) }
    let(:rpm_list_softlayer) { File.readlines(spec_asset('rpm-list-rhel-8-softlayer-additions.txt')).map(&:chop) }

    describe command(rpm_list_packages), {
      exclude_on_google: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_azure: true,
    } do
      let(:installed_packages_aws) { rpm_list }
      it 'contains only the base set of packages for aws, openstack, warden' do
        expect(subject.stdout.split("\n")).to match_array(installed_packages_aws)
      end
      it 'contains only the base set of packages for aws, openstack, warden (full list)' do
        expect(subject.stdout.split("\n")).to match_array(installed_packages_aws), -> { "actual packages: '#{subject.stdout}'" }
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
      let(:installed_packages_google) { rpm_list_google }
      it 'contains only the base set of packages plus google-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list.concat(installed_packages_google))
      end
      it 'contains only the base set of packages plus google-specific packages (full list)' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list.concat(installed_packages_google)), -> { "actual packages: '#{subject.stdout}'" }
      end
    end

    describe command(rpm_list_packages), {
      exclude_on_aws: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
    } do
      let(:installed_packages_vsphere) { rpm_list_vsphere }
      it 'contains only the base set of packages plus vsphere-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list.concat(installed_packages_vsphere))
      end
      it 'contains only the base set of packages plus vsphere-specific packages (full list)' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list.concat(installed_packages_vsphere)), -> { "actual packages: '#{subject.stdout}'" }
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
      let(:installed_packages_azure) { rpm_list_azure }
      it 'contains only the base set of packages plus azure-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list.concat(installed_packages_azure))
      end
      it 'contains only the base set of packages plus azure-specific packages (full list)' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list.concat(installed_packages_azure)), -> { "actual packages: '#{subject.stdout}'" }
      end
    end

    describe command(rpm_list_packages), {
      exclude_on_alicloud: true,
      exclude_on_aws: true,
      exclude_on_cloudstack: true,
      exclude_on_vcloud: true,
      exclude_on_vsphere: true,
      exclude_on_google: true,
      exclude_on_warden: true,
      exclude_on_azure: true,
      exclude_on_openstack: true,
    } do
      let(:installed_packages_softlayer) { rpm_list_softlayer }
      it 'contains only the base set of packages plus softlayer-specific packages' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list.concat(installed_packages_softlayer))
      end
      it 'contains only the base set of packages plus softlayer-specific packages (full list)' do
        expect(subject.stdout.split("\n")).to match_array(rpm_list.concat(installed_packages_softlayer)), -> { "actual packages: '#{subject.stdout}'" }
      end
    end
  end

end
