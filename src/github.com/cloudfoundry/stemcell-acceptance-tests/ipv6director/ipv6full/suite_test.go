package ipv6full_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

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
	bosh.SafeDeploy()
})

var _ = AfterSuite(func() {
	bosh.Teardown()
})
