package smoke_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"

	"github.com/cloudfoundry/stemcell-acceptance-tests/testhelpers"
)

var (
	bosh *testhelpers.BOSH
)

func TestSmoke(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Syslogrelease Suite")
}

var _ = BeforeSuite(func() {
	bosh = testhelpers.NewBOSH()
	stemcellPath := testhelpers.RequireEnv("STEMCELL_PATH")
	syslogReleasePath := testhelpers.RequireEnv("SYSLOG_RELEASE_PATH")

	bosh.UploadStemcell(stemcellPath)
	bosh.UploadRelease(syslogReleasePath)
	bosh.Deploy()
})

var _ = AfterSuite(func() {
	bosh.Teardown()
})
