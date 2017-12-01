package ipv6full_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"

	"github.com/cloudfoundry/stemcell-acceptance-tests/testhelpers"
)

var (
	bosh *testhelpers.BOSH
)

func TestReg(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "ipv6full")
}

var _ = BeforeSuite(func() {
	// This test suite assumes that targeted Director contains:
	// - network named 'ipv6' in its cloud config
	// - is multi homed with an IPv6 address

	bosh = testhelpers.NewBOSH()
	stemcellPath := testhelpers.RequireEnv("STEMCELL_PATH")
	bosh.UploadStemcell(stemcellPath)
	bosh.Deploy()
})

var _ = AfterSuite(func() {
	bosh.Teardown()
})
