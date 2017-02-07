package smoke_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
	"github.com/cloudfoundry/bosh-utils/system"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"text/template"
)

func TestSmoke(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Smoke Suite")
}

var _ = BeforeSuite(func() {
	assertRequiredParams()
	uploadRelease()
	uploadStemcell()
	deploy()
})

var _ = AfterSuite(func() {
	stdOut, stdErr, exitStatus, err := system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelDebug)).RunCommand(os.Getenv("BOSH_BINARY_PATH"), "-n",  "-d", "bosh-stemcell-smoke-tests", "delete-deployment")
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))

	stdOut, stdErr, exitStatus, err = system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelDebug)).RunCommand(os.Getenv("BOSH_BINARY_PATH"), "-n", "clean-up", "--all")
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
})

func deploy() {
	syslogReleaseVersion, err := ioutil.ReadFile("../syslog-release/version")
	Expect(err).ToNot(HaveOccurred())
	stemcellVersion, err := ioutil.ReadFile("../stemcell/version")
	Expect(err).ToNot(HaveOccurred())
	tempFile, err := ioutil.TempFile(os.TempDir(), "manifest")
	Expect(err).ToNot(HaveOccurred())
	contents, err := ioutil.ReadFile("../assets/manifest.yml")
	Expect(err).ToNot(HaveOccurred())

	template, err := template.New("syslog-release").Parse(string(contents))
	Expect(err).ToNot(HaveOccurred())
	err = template.Execute(tempFile, struct {
		SyslogReleaseVersion string
		StemcellVersion      string
	}{
		SyslogReleaseVersion: string(syslogReleaseVersion),
		StemcellVersion:      string(stemcellVersion),
	})
	Expect(err).ToNot(HaveOccurred())
	manifestPath, err := filepath.Abs(tempFile.Name())
	Expect(err).ToNot(HaveOccurred())
	stdOut, stdErr, exitStatus, err := system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelDebug)).RunCommand(os.Getenv("BOSH_BINARY_PATH"), "-n", "-d", "bosh-stemcell-smoke-tests", "deploy", manifestPath)
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
}

func uploadRelease() {
	stdOut, stdErr, exitStatus, err := system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelDebug)).RunCommand(os.Getenv("BOSH_BINARY_PATH"), "upload-release", os.Getenv("SYSLOG_RELEASE_PATH"))
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
}

func assertRequiredParams() {
	_, ok := os.LookupEnv("BOSH_BINARY_PATH")
	Expect(ok).To(BeTrue(), "BOSH_BINARY_PATH was not set")
	_, ok = os.LookupEnv("SYSLOG_RELEASE_PATH")
	Expect(ok).To(BeTrue(), "SYSLOG_RELEASE_PATH was not set")
	_, ok = os.LookupEnv("STEMCELL_PATH")
	Expect(ok).To(BeTrue(), "STEMCELL_PATH was not set")
}

func uploadStemcell() {
	stdOut, stdErr, exitStatus, err := system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelDebug)).RunCommand(os.Getenv("BOSH_BINARY_PATH"), "upload-stemcell", os.Getenv("STEMCELL_PATH"))
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
}