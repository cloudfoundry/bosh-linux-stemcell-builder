package smoke_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"testing"

	"github.com/cloudfoundry/stemcell-acceptance-tests/testhelpers"
)

var (
	bosh *testhelpers.BOSH
)

func TestSmoke(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Auditd Suite")
}

var _ = BeforeSuite(func() {
	bosh = testhelpers.NewBOSH()
	stemcellPath := testhelpers.RequireEnv("STEMCELL_PATH")
	osConfReleasePath := testhelpers.RequireEnv("OS_CONF_RELEASE_PATH")

	bosh.UploadStemcell(stemcellPath)
	bosh.UploadRelease(osConfReleasePath)
	bosh.SafeDeploy()
})

var _ = AfterSuite(func() {
	bosh.Teardown()
})
