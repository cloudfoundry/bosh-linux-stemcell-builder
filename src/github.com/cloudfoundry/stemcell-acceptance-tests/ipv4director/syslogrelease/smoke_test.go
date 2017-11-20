package smoke_test

import (
	"fmt"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Syslogrelease", func() {
	Context("when auditd is monitoring access to modprobe", func() {
		It("gets forwarded to the syslog storer", func() {
			_, _, exitStatus, err := bosh.Run("ssh", "syslog_forwarder/0", "sudo modprobe -r floppy")
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0))

			stdOut, _, exitStatus, err := bosh.Run("ssh", "syslog_storer/0", `cat /var/vcap/store/syslog_storer/syslog.log`)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0))
			Expect(stdOut).To(ContainSubstring("COMMAND=/sbin/modprobe -r floppy"))
		})
	})

	Context("when logging to syslog", func() {
		It("gets forwarded to the syslog storer", func() {
			stdOut, stdErr, exitStatus, err := bosh.Run("ssh", "syslog_forwarder/0", "logger -t vcap some vcap message")
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))

			stdOut, _, exitStatus, err = bosh.Run("ssh", "syslog_storer/0", `cat /var/vcap/store/syslog_storer/syslog.log`)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0))
			Expect(stdOut).To(ContainSubstring("some vcap message"))
		})
	})

	It("#133776519: forwards deeply nested logs", func() {
		stdOut, stdErr, exitStatus, err := bosh.Run(
			"ssh",
			"syslog_forwarder/0",
			`sudo mkdir -p /var/vcap/sys/log/deep/path && sudo chmod -R 777 /var/vcap/sys/log/deep && touch /var/vcap/sys/log/deep/path/deepfile.log`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0), fmt.Sprintf("Could not create nested log path! \n stdOut: %s \n stdErr: %s", stdOut, stdErr))

		time.Sleep(10 * time.Second)

		_, _, exitStatus, err = bosh.Run("ssh", "syslog_forwarder/0", "echo 'test-blackbox-message' >> /var/vcap/sys/log/deep/path/deepfile.log")
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))

		time.Sleep(35 * time.Second)

		stdOut, stdErr, exitStatus, err = bosh.Run("ssh", "syslog_storer/0", `cat /var/vcap/store/syslog_storer/syslog.log`)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdOut).To(ContainSubstring("test-blackbox-message"))
	})

	It("#135979501: produces CEF logs for all incoming NATs and https requests", func() {
		stdOut, stdErr, exitStatus, err := bosh.Run("ssh", "syslog_storer/0", `sudo cat /var/vcap/store/syslog_storer/syslog.log`)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0), fmt.Sprintf("Could not read from syslog stdOut: %s \n stdErr: %s", stdOut, stdErr))
		Expect(stdOut).To(ContainSubstring("CEF:0|CloudFoundry|BOSH|1|agent_api|get_task"))
	})

	It("#137987887: produces audit logs for use of specific binaries", func() {
		stdOut, stdErr, exitStatus, err := bosh.Run("ssh", "syslog_forwarder/0", `chage -h`)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0), fmt.Sprintf("Unable to run 'chage -h' \n stdOut: %s \n stdErr: %s", stdOut, stdErr))

		stdOut, stdErr, exitStatus, err = bosh.Run("ssh", "syslog_storer/0", `sudo cat /var/vcap/store/syslog_storer/syslog.log`)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0), fmt.Sprintf("Could not read from syslog stdOut: %s \n stdErr: %s", stdOut, stdErr))
		Expect(stdOut).To(ContainSubstring(`exe="/usr/bin/chage"`))
	})
})
