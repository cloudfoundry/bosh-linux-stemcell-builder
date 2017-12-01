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
			"ssh", "mutable/0", "-r", "-c",
			`sudo auditctl -w /etc/network -p wa -k system-locale-story-50315687`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdout).NotTo(ContainSubstring(immutabilityError))
	})

	It("#150315687: make audit rules immutable", func() {
		stdout, _, exitStatus, err := bosh.Run(
			"--column=stdout",
			"ssh", "immutable/0", "-r", "-c",
			`sudo auditctl -w /etc/network -p wa -k system-locale-story-50315687`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdout).To(ContainSubstring(immutabilityError))
	})
})
