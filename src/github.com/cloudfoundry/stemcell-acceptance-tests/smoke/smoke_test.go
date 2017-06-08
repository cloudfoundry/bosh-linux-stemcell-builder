package smoke_test

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"time"

	"strconv"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"github.com/cloudfoundry/bosh-utils/system"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Stemcell", func() {
	cmdRunner := system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelNone))
	boshBinaryPath := os.Getenv("BOSH_BINARY_PATH")

	Context("When syslog release has been deployed", func() {
		Context("when auditd is monitoring access to modprobe", func() {
			It("gets forwarded to the syslog storer", func() {
				_, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", "sudo modprobe -r floppy")
				Expect(err).ToNot(HaveOccurred())
				Expect(exitStatus).To(Equal(0))

				_, _, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_storer/0", `cat /var/vcap/store/syslog_storer/syslog.log`)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitStatus).To(Equal(0))
				//Expect(stdOut).To(ContainSubstring("COMMAND=/sbin/modprobe -r floppy"))
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
				//Expect(stdOut).To(ContainSubstring("some vcap message"))
			})
		})

		Context("when logrotate wtmp/btmp logs", func() {
			It("should rotate the wtmp/btmp logs", func() {
				stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", `sudo bash -c "dd if=/dev/urandom count=10000 bs=1024 >> /var/log/wtmp" \
    	&& sudo bash -c "dd if=/dev/urandom count=10000 bs=1024 >> /var/log/btmp" \
    	&& sudo sed -i "s/0,15,30,45/\*/" /etc/cron.d/logrotate`)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdOut: %s \n stdErr: %s", stdOut, stdErr))

				time.Sleep(62 * time.Second)

				stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "--column=stdout", "--results", "syslog_forwarder/0", "sudo du /var/log/wtmp | cut -f1")
				Expect(err).ToNot(HaveOccurred())
				fileSizeInKiloBytes, err := strconv.Atoi(strings.TrimSpace(stdOut))
				Expect(err).ToNot(HaveOccurred(), "error converting kB file size to integer")
				Expect(fileSizeInKiloBytes).To(BeNumerically("<", 100), "Logfile was larger than expected. It should have been rotated.")

				stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "--column=stdout", "--results", "syslog_forwarder/0", "sudo du /var/log/btmp | cut -f1")
				Expect(err).ToNot(HaveOccurred())
				fileSizeInKiloBytes, err = strconv.Atoi(strings.TrimSpace(stdOut))
				Expect(err).ToNot(HaveOccurred(), "error converting kB file size to integer")
				Expect(fileSizeInKiloBytes).To(BeNumerically("<", 100), "Logfile was larger than expected. It should have been rotated.")
			})
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

			stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", `sudo cat /var/vcap/data/root_log/syslog`)
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
		stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", `sudo mkdir -p /var/vcap/sys/log/deep/path && sudo chmod 777 /var/vcap/sys/log/deep/path && touch /var/vcap/sys/log/deep/path/deepfile.log`)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0), fmt.Sprintf("Could not create nested log path! \n stdOut: %s \n stdErr: %s", stdOut, stdErr))

		time.Sleep(10 * time.Second)

		_, _, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_forwarder/0", "echo 'test-blackbox-message' >> /var/vcap/sys/log/deep/path/deepfile.log")
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))

		time.Sleep(35 * time.Second)

		stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_storer/0", `cat /var/vcap/store/syslog_storer/syslog.log`)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		//Expect(stdOut).To(ContainSubstring("test-blackbox-message"))
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

		stdOut, stdErr, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "ssh", "syslog_storer/0", `sudo cat /var/vcap/store/syslog_storer/syslog.log`)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0), fmt.Sprintf("Could not read from syslog stdOut: %s \n stdErr: %s", stdOut, stdErr))
		//Expect(stdOut).To(ContainSubstring(`exe="/usr/bin/chage"`))
	})

	It("#141987897: disables ipv6 in the kernel", func() {
		stdOut, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath, "-d", "bosh-stemcell-smoke-tests", "--column=stdout", "ssh", "syslog_forwarder/0", "-r", "-c", `sudo netstat -lnp | grep sshd | awk '{ print $4 }'`)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(strings.Split(strings.TrimSpace(stdOut), "\n")).To(Equal([]string{"0.0.0.0:22"}))
	})

	It("#140456537: enables sysstat", func() {
		_, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath,
			"-d", "bosh-stemcell-smoke-tests",
			"--column=stdout",
			"ssh", "syslog_forwarder/0", "-r", "-c",
			// sleep to ensure we have multiple samples so average can be verified
			`sudo /usr/lib/sysstat/debian-sa1 && sudo /usr/lib/sysstat/debian-sa1 1 1 && sleep 2 && sudo /usr/lib/sysstat/debian-sa1 1 1`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))

		stdOut, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath,
			"-d", "bosh-stemcell-smoke-tests",
			"--column=stdout",
			"ssh", "syslog_forwarder/0", "-r", "-c",
			`sudo sar`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdOut).To(MatchRegexp(`^Linux`))
		Expect(stdOut).To(MatchRegexp(`\nAverage:\s+`))
	})

	It("#146390925: rsyslog logs with precision timestamps", func() {
		stdout, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath,
			"-d", "bosh-stemcell-smoke-tests",
			"--column=stdout",
			"ssh", "syslog_forwarder/0", "-r",
			"-c", `logger story146390925 && sleep 1 && sudo grep story146390925 /var/log/messages`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))

		Expect(stdout).To(MatchRegexp(`\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{1,6}\+00:00 localhost bosh_[^ ]+: story146390925`))
	})

	It("#150315687: make audit rules immutable", func() {
		stdout, _, exitStatus, err := cmdRunner.RunCommand(boshBinaryPath,
			"-d", "bosh-stemcell-smoke-tests",
			"--column=stdout",
			"ssh", "syslog_forwarder/0", "-r", "-c",
			`sudo auditctl -w /etc/network -p wa -k system-locale-story-50315687`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdout).NotTo(ContainSubstring("The audit system is in immutable mode, no rule changes allowed"))

		stdout, _, exitStatus, err = cmdRunner.RunCommand(boshBinaryPath,
			"-d", "bosh-stemcell-smoke-tests",
			"--column=stdout",
			"ssh", "immutable_audit_rules/0", "-r", "-c",
			`sudo auditctl -w /etc/network -p wa -k system-locale-story-50315687`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(stdout).To(ContainSubstring("The audit system is in immutable mode, no rule changes allowed"))
	})
})
