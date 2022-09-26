package smoke_test

import (
	. "github.com/onsi/ginkgo/v2"
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
		getCurrentUserLoginAuditdLogScript := `
			last_user_login_log() {
				sudo cat /var/log/syslog | grep "type=USER_LOGIN"
			}
			sessionpid() {
				ps --no-headers -fp $(ps --no-headers -fp $$ | awk '{ print $3 }') | awk '{ print $3 }'
			}
			auditpid() {
				last_user_login_log | tail -n1 | sed 's/.*pid=\([0-9]*\).*/\1/g'
			}
			i=0
			while [[ "$(sessionpid)" != "$(auditpid)" ]]; do
				i=$((i + 1))
				if [[ "$i" -gt "5" ]]; then
					exit 1
				fi
				sleep 1
			done
			last_user_login_log
		`

		output, _, exitStatus, err := bosh.Run(
			"--column=stdout",
			"ssh", "default-auditd/0", "-r", "-c",
			getCurrentUserLoginAuditdLogScript,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))

		auditLoginRegexp := `.*type=USER_LOGIN.*exe="/usr/sbin/sshd".*res=success`
		Expect(output).To(MatchRegexp(auditLoginRegexp))
	})
})
