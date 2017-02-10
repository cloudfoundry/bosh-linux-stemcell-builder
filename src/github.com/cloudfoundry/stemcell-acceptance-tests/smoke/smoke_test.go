package smoke_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/cloudfoundry/bosh-utils/system"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"fmt"
	"time"
	"io/ioutil"
	"os"
	"path/filepath"
)

var _ = Describe("Stemcell", func() {
	Context("When syslog release has been deployed", func() {
		cmdRunner := system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelNone))
		boshBinaryPath := os.Getenv("BOSH_BINARY_PATH")

		Context("when auditd is monitoring access to modprobe", func() {
			It("gets forwarded to the syslog storer", func() {
				stdOut, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", "sudo modprobe -r floppy")
				Expect(err).ToNot(HaveOccurred())
				Expect(exitStatus).To(Equal(0))

				stdOut, _, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_storer/0", `cat /var/vcap/store/syslog_storer/syslog.log`)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitStatus).To(Equal(0))
				Expect(stdOut).To(ContainSubstring("COMMAND=/sbin/modprobe -r floppy"))
			})
		})

		Context("when logging to syslog", func() {
			It("gets forwarded to the syslog storer", func() {
				stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", "logger -t vcap some vcap message")
				Expect(err).ToNot(HaveOccurred())
				Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))

				stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_storer/0", `cat /var/vcap/store/syslog_storer/syslog.log`)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitStatus).To(Equal(0))
				Expect(stdOut).To(ContainSubstring("some vcap message"))
			})
		})

		Context("when syslog threshold limit is reached", func() {
			It("should rotate the logs", func() {
				stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", `logger "old syslog content" \
	&& sudo bash -c "dd if=/dev/urandom count=10000 bs=1024 >> /var/log/syslog" \
	&& sudo sed -i "s/0,15,30,45/\*/" /etc/cron.d/logrotate`)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitStatus).To(Equal(0))

				time.Sleep(62 * time.Second)

				stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", `logger "new syslog content"`)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitStatus).To(Equal(0), fmt.Sprintf("Could not log using logger on the syslog forwarder! \n stdOut: %s \n stdErr: %s", stdOut, stdErr))

				stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", `sudo cat /var/vcap/data/root_log/syslog`)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitStatus).To(Equal(0))
				Expect(stdOut).To(ContainSubstring("new syslog content"))

				stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_storer/0", `sudo cat /var/vcap/data/root_log/syslog`)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitStatus).To(Equal(0), fmt.Sprintf("Could not read from syslog stdOut: %s \n stdErr: %s", stdOut, stdErr))
				Expect(stdOut).NotTo(ContainSubstring("old syslog content"))
			})
		})

		It("#134136191: auth.log should not contain 'No such file or directory' errors", func() {
			tempFile, err := ioutil.TempFile(os.TempDir(), "auth.log")
			Expect(err).ToNot(HaveOccurred())
			authLogAbsPath, err := filepath.Abs(tempFile.Name())
			Expect(err).ToNot(HaveOccurred())

			stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", `sudo cp /var/log/auth.log /tmp/ && sudo chmod 777 /tmp/auth.log`)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0), fmt.Sprintf("Could not create nested log path! \n stdOut: %s \n stdErr: %s", stdOut, stdErr))

			stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "scp", "syslog_forwarder/0:/tmp/auth.log", authLogAbsPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0))

			contents, err := ioutil.ReadAll(tempFile)
			Expect(err).ToNot(HaveOccurred())
			Expect(contents).ToNot(ContainSubstring("No such file or directory"))
		})

		It("#133776519: forwards deeply nested logs", func() {
			tempFile, err := ioutil.TempFile(os.TempDir(), "logfile")
			Expect(err).ToNot(HaveOccurred())
			_, err = tempFile.Write([]byte("test-blackbox-message"))
			Expect(err).ToNot(HaveOccurred())
			logFilePath, err := filepath.Abs(tempFile.Name())
			Expect(err).ToNot(HaveOccurred())

			stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", `sudo mkdir -p /var/vcap/sys/log/deep/path && sudo chmod 777 /var/vcap/sys/log/deep/path`)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0), fmt.Sprintf("Could not create nested log path! \n stdOut: %s \n stdErr: %s", stdOut, stdErr))

			_, _, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "scp", logFilePath, "syslog_forwarder/0:/var/vcap/sys/log/deep/path/deepfile.log")
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0))

			time.Sleep(35 * time.Second)

			stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_storer/0", `cat /var/vcap/store/syslog_storer/syslog.log`)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0))
			Expect(stdOut).To(ContainSubstring("test-blackbox-message"))
		})

		It("#135979501: produces CEF logs for all incoming NATs and https requests", func() {
			stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_storer/0", `sudo cat /var/vcap/store/syslog_storer/syslog.log`)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0), fmt.Sprintf("Could not read from syslog stdOut: %s \n stdErr: %s", stdOut, stdErr))
			Expect(stdOut).To(ContainSubstring("CEF:0|CloudFoundry|BOSH|1|agent_api|get_task"))
		})

		It("#137987887: produces audit logs for use of specific binaries", func() {
			stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", `chage -h`)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0), fmt.Sprintf("Unable to run 'chage -h' \n stdOut: %s \n stdErr: %s", stdOut, stdErr))

			stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_storer/0", `cat /var/vcap/store/syslog_storer/syslog.log`)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0), fmt.Sprintf("Could not read from syslog stdOut: %s \n stdErr: %s", stdOut, stdErr))
			Expect(stdOut).To(ContainSubstring(`exe="/usr/bin/chage"`))
		})
	})
})
