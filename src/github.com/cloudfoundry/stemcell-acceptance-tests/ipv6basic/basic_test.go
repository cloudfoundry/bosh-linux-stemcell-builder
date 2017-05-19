package ipv6basic_test

import (
	"os"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"github.com/cloudfoundry/bosh-utils/system"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("IPv6 Basic", func() {
	cmdRunner := system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelNone))
	boshBinaryPath := os.Getenv("BOSH_BINARY_PATH")

	It("enables ipv6 in the kernel", func() {
		stdOut, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-ipv6basic-tests", "--column=stdout", "ssh", "test/0", "-r", "-c", `sudo netstat -lnp | grep sshd`)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdOut).To(ContainSubstring("0.0.0.0:22"))
		Expect(stdOut).To(ContainSubstring(":::22"))
	})

	It("assigns link local ipv6 address", func() {
		stdOut, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-ipv6basic-tests", "--column=stdout", "ssh", "test/0", "-r", "-c", "ip a")
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdOut).To(ContainSubstring("fe80:"))
	})
})
