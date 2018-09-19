package smoke_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Auditd", func() {
	var immutabilityError = "The audit system is in immutable mode, no rule changes allowed"

	It("#150315687: audit rules are mutable", func() {
		stdout, _, exitStatus, err := bosh.Run(
			"--column=stdout",
			"ssh", "default-auditd/0", "-r", "-c",
			`sudo auditctl -w /etc/network -p wa -k system-locale-story-50315687`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdout).NotTo(ContainSubstring(immutabilityError))
	})

	It("#150315687: make audit rules immutable", func() {
		stdout, _, exitStatus, err := bosh.Run(
			"--column=stdout",
			"ssh", "os-conf-auditd/0", "-r", "-c",
			`sudo auditctl -w /etc/network -p wa -k system-locale-story-50315687`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdout).To(ContainSubstring(immutabilityError))
	})

	It("creates a USER_LOGIN event for ssh access", func() {
		output1, _, exitStatus, err := bosh.Run(
			"--column=stdout",
			"ssh", "default-auditd/0", "-r", "-c",
			`sudo cat /var/log/syslog | grep "type=USER_LOGIN" | tail -n1`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))

		output2, _, exitStatus, err := bosh.Run(
			"--column=stdout",
			"ssh", "default-auditd/0", "-r", "-c",
			`sudo cat /var/log/syslog | grep "type=USER_LOGIN" | tail -n1`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))

		Expect(output1).ToNot(Equal(output2))

		auditLoginRegexp := `.*type=USER_LOGIN.*exe="/usr/sbin/sshd".*res=success`

		Expect(output1).To(MatchRegexp(auditLoginRegexp))
		Expect(output2).To(MatchRegexp(auditLoginRegexp))
	})
})
