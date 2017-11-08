package smoke_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"os"
	"path/filepath"
	"testing"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"github.com/cloudfoundry/bosh-utils/system"
)

func TestSmoke(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Smoke Suite")
}

var _ = BeforeSuite(func() {
	cmdRunner := system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelDebug))
	boshBinaryPath := os.Getenv("BOSH_BINARY_PATH")
	assertRequiredParams()
	uploadRelease(cmdRunner, boshBinaryPath)
	uploadStemcell(cmdRunner, boshBinaryPath)
	deploy(cmdRunner, boshBinaryPath)
})

var _ = AfterSuite(func() {
	cmdRunner := system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelDebug))
	boshBinaryPath := os.Getenv("BOSH_BINARY_PATH")
	stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-n", "-d", "bosh-stemcell-smoke-tests", "delete-deployment")
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))

	stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-n", "clean-up", "--all")
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
})

func deploy(cmdRunner system.CmdRunner, boshBinaryPath string) {
	manifestPath, err := filepath.Abs("../../assets/manifest.yml")
	Expect(err).ToNot(HaveOccurred())
	stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-n", "-d", "bosh-stemcell-smoke-tests", "deploy", "--vars-env=BOSH", manifestPath)
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
}

func uploadRelease(cmdRunner system.CmdRunner, boshBinaryPath string) {
	stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "upload-release", os.Getenv("SYSLOG_RELEASE_PATH"))
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))

	stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "upload-release", os.Getenv("OS_CONF_RELEASE_PATH"))
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
}

func assertRequiredParams() {
	_, ok := os.LookupEnv("BOSH_BINARY_PATH")
	Expect(ok).To(BeTrue(), "BOSH_BINARY_PATH was not set")
	_, ok = os.LookupEnv("SYSLOG_RELEASE_PATH")
	Expect(ok).To(BeTrue(), "SYSLOG_RELEASE_PATH was not set")
	_, ok = os.LookupEnv("OS_CONF_RELEASE_PATH")
	Expect(ok).To(BeTrue(), "OS_CONF_RELEASE_PATH was not set")
	_, ok = os.LookupEnv("STEMCELL_PATH")
	Expect(ok).To(BeTrue(), "STEMCELL_PATH was not set")
	_, ok = os.LookupEnv("BOSH_stemcell_version")
	Expect(ok).To(BeTrue(), "BOSH_stemcell_version was not set")
}

func uploadStemcell(cmdRunner system.CmdRunner, boshBinaryPath string) {
	stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "upload-stemcell", os.Getenv("STEMCELL_PATH"))
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
}
