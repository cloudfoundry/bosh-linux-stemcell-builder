require 'spec_helper'

describe 'CIS test case verification', {stemcell_image: true, security_spec: true} do
  let(:base_cis_test_cases) do %W{
        CIS-2.18
        CIS-2.19
        CIS-2.20
        CIS-2.21
        CIS-2.22
        CIS-2.23
        CIS-3.2.4
        CIS-4.1
        CIS-7.2.5
        CIS-7.2.6
        CIS-7.2.7
        CIS-7.3.1
        CIS-7.3.2
        CIS-7.5.3
        CIS-11.1
        CIS-8.1.3
        CIS-8.1.4
        CIS-8.1.5
        CIS-4.1.6
        CIS-4.1.7
        CIS-8.1.8
        CIS-8.1.9
        CIS-8.1.10
        CIS-8.1.11
        CIS-8.1.13
        CIS-8.1.14
        CIS-8.1.15
        CIS-8.1.16
        CIS-8.1.18
        CIS-9.1.2
        CIS-9.1.3
        CIS-9.1.4
        CIS-9.1.5
        CIS-9.1.6
        CIS-9.1.7
        CIS-9.1.8
        CIS-9.2.1
        CIS-9.4
        CIS-9.5
        CIS-10.2
        CIS-5.2.12
        CIS-5.2.13
      }
  end


  context "For all infrastructure except Azure and Cloudstack and FIPS", {exclude_on_azure:true, exclude_on_cloudstack:true, exclude_on_fips: true} do
    it 'confirms that all CIS test cases ran' do
      expect($cis_test_cases.to_a).to match_array(base_cis_test_cases + ['CIS-2.24', 'CIS-8.1.12' ])
    end
  end

  # not sure if include is a thing
  context "For FIPS stemcells", {
    exclude_on_alicloud: true,
    exclude_on_aws: true,
    exclude_on_azure: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_cloudstack: true,
    exclude_on_softlayer: true,
  } do
    it 'confirms that all CIS test cases ran' do
      expect($cis_test_cases.to_a).to match_array(base_cis_test_cases + ['CIS-2.24', ])
    end
  end

  # TODO: how should we hanlde the cis test cases for FIPS as this is missing "CIS-8.1.12"

  context "For Azure infrastructure", {
    exclude_on_alicloud: true,
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_cloudstack: true,
    exclude_on_softlayer: true,
  } do
    it 'confirms that all CIS test cases ran' do
      expect($cis_test_cases.to_a).to match_array(base_cis_test_cases + ['CIS-8.1.12'])
    end
  end
end
