package ipv6full_test

import (
	"os"
	"net"
	"fmt"
	"strings"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"github.com/cloudfoundry/bosh-utils/system"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("IPv6 Full", func() {
	cmdRunner := system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelNone))
	boshBinaryPath := os.Getenv("BOSH_BINARY_PATH")

	It("enables ipv6 in the kernel", func() {
		stdOut, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-ipv6full-tests", "--column=stdout", "ssh", "test/0", "-r", "-c", `sudo netstat -lnp | grep sshd`)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdOut).To(ContainSubstring("0.0.0.0:22"))
		Expect(stdOut).To(ContainSubstring(":::22"))
	})

	type Instance struct {
		Name string
		IP   net.IP
	}

	parseInstanceAddrs := func(stdOut string) []Instance {
		lines := strings.Split(stdOut, "\n")
		Expect(len(lines)).To(BeNumerically(">", 0))

		instances := []Instance{}

		for _, line := range lines {
			if len(line) == 0 {
				continue
			}

			pieces := strings.Fields(line)
			Expect(pieces).To(HaveLen(2), fmt.Sprintf("Expected line '%s' (within stdout: >>>'%s'<<<) to include 2 pieces", line, stdOut))

			ip := net.ParseIP(pieces[1])
			Expect(ip).ToNot(BeNil())

			instances = append(instances, Instance{Name: pieces[0], IP: ip})
		}

		return instances
	}

	It("assigns global ipv6 addresses to each instance", func() {
		// This test assumes that it can use bosh ssh to ssh into an IPv6 machine.
		// That could be achieve either by:
		// - configuring tests to use Director as a SSH gateway
		// - having machine running these tests have an IPv6 address routable to test VMs

		stdOut, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-ipv6full-tests", "--column=instance", "--column=ips", "instances")
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))

		for _, instance := range parseInstanceAddrs(stdOut) {
			Expect(instance.IP.String()).To(ContainSubstring(":")) // ipv6 address
			Expect(instance.IP.String()).ToNot(ContainSubstring("fe80"))
		}
	})

	It("one instance can talk to another via IPv6", func() {
		stdOut, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-ipv6full-tests", "--column=instance", "--column=ips", "instances")
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))

		instances := parseInstanceAddrs(stdOut)
		Expect(len(instances)).To(BeNumerically(">", 2))

		instance1 := instances[0].Name
		ip2 := instances[1].IP

		stdOut, _, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-ipv6full-tests", "--column=stdout", "ssh", instance1, "-r", "-c", "sudo ping6 -c 2 " + ip2.String())
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdOut).To(ContainSubstring("2 packets transmitted, 2 received, 0% packet loss"))
	})

	It("assigns link local ipv6 address", func() {
		stdOut, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-ipv6full-tests", "--column=stdout", "ssh", "test/0", "-r", "-c", "ip a")
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdOut).To(ContainSubstring("fe80:"))
	})
})
