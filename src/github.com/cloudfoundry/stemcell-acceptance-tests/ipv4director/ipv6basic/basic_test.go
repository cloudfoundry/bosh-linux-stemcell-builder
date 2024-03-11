package ipv6basic_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("IPv6 Basic", func() {
	// # NOBLE_TODO: this test doesn't make sense anymore since ssh is not listing on sockets see https://discourse.ubuntu.com/t/sshd-now-uses-socket-based-activation-ubuntu-22-10-and-later/30189
	// It("enables ipv6 in the kernel", func() {
	// 	stdOut, _, exitStatus, err := bosh.Run("--column=stdout", "ssh", "test/0", "-r", "-c", `sudo netstat -lnp | grep sshd`)
	// 	Expect(err).ToNot(HaveOccurred())
	// 	Expect(exitStatus).To(Equal(0))
	// 	Expect(stdOut).To(ContainSubstring("0.0.0.0:22"))
	// 	Expect(stdOut).To(ContainSubstring(":::22"))
	// })

	It("assigns link local ipv6 address", func() {
		stdOut, _, exitStatus, err := bosh.Run("--column=stdout", "ssh", "test/0", "-r", "-c", "ip a")
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdOut).To(ContainSubstring("fe80:"))
	})
})
