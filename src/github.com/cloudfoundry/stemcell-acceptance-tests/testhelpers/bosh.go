package testhelpers

import (
	"fmt"
	"os"
	"path/filepath"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"github.com/cloudfoundry/bosh-utils/system"

	. "github.com/onsi/gomega"
)

type BOSH struct {
	boshBinaryPath string
	cmdRunner      system.CmdRunner
	deploymentName string
}

func RequireEnv(env string) string {
	val, ok := os.LookupEnv(env)
	Expect(ok).To(BeTrue(), env+" was not set")
	return val
}

func NewBOSH() *BOSH {

	return &BOSH{
		cmdRunner:      system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelDebug)),
		boshBinaryPath: RequireEnv("BOSH_BINARY_PATH"),
		deploymentName: "stemcell-acceptance-tests",
	}
}

func (b *BOSH) Teardown() {
	stdOut, stdErr, exitStatus, err := b.Run("delete-deployment")
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))

	stdOut, stdErr, exitStatus, err = b.Run("clean-up", "--all")
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
}

func (b *BOSH) UploadStemcell(stemcellPath string) {
	stdOut, stdErr, exitStatus, err := b.Run("upload-stemcell", stemcellPath)
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
}

func (b *BOSH) UploadRelease(releasePath string) {
	stdOut, stdErr, exitStatus, err := b.Run("upload-release", releasePath)
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
}

func (b *BOSH) Deploy(args ...string) {
	manifestPath, err := filepath.Abs("manifest.yml")
	Expect(err).ToNot(HaveOccurred())

	deployCmd := []string{"deploy", "--vars-env=BOSH", manifestPath}

	if len(args) > 0 {
		deployCmd = append(deployCmd, args...)
	}

	// error early and more clearly if variables are missing
	stdOut, stdErr, exitStatus, err := b.Run("interpolate", "--vars-env=BOSH", "--var-errs", manifestPath)
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))

	stdOut, stdErr, exitStatus, err = b.Run(deployCmd...)
	Expect(err).ToNot(HaveOccurred())
	Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))
}

func (b *BOSH) Run(args ...string) (string, string, int, error) {
	return b.cmdRunner.RunCommand(b.boshBinaryPath, append([]string{"-n", "-d", b.deploymentName}, args...)...)
}
