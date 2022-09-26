package ipv6basic_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"testing"

	"github.com/cloudfoundry/stemcell-acceptance-tests/testhelpers"
)

var (
	bosh *testhelpers.BOSH
)

func TestReg(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "ipv6basic")
}

var _ = BeforeSuite(func() {
	bosh = testhelpers.NewBOSH()
	stemcellPath := testhelpers.RequireEnv("STEMCELL_PATH")
	bosh.UploadStemcell(stemcellPath)
	bosh.SafeDeploy()
})

var _ = AfterSuite(func() {
	bosh.Teardown()
})
