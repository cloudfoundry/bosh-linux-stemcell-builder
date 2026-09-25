package bpm_restore_test

import (
	"fmt"
	"path/filepath"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// The stemcell has python3 but not jq.
const tiniCommand = `sudo python3 -c 'import json; print(json.load(open("/var/vcap/data/bpm/bundles/syslog_forwarder/blackbox/config.json"))["process"]["args"][0])'`

var _ = Describe("Stemcell BPM Restore", func() {
	It("deploys with bpm, then redeploys without bpm, asserting syslog_forwarder runs under /usr/libexec/bpm/bin/tini", func() {
		By("checking syslog_forwarder initially runs under BOSH package tini")
		stdout, _, exitStatus, err := bosh.Run(
			"--column=stdout",
			"ssh", "default/0", "-r", "-c",
			tiniCommand,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(strings.TrimSpace(stdout)).To(Equal("/var/vcap/packages/bpm/bin/tini"))

		By("redeploying without bpm job")
		removeBpmOps, err := filepath.Abs("remove_bpm_job.yml")
		Expect(err).NotTo(HaveOccurred())
		bosh.SafeDeploy("-o", removeBpmOps)

		By("asserting syslog_forwarder is running under stemcell tini")
		stdout, stderr, exitStatus, err := bosh.Run(
			"--column=stdout",
			"ssh", "default/0", "-r", "-c",
			`sudo /var/vcap/jobs/bpm/bin/bpm list`,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0), fmt.Sprintf("stdout: %s, stderr: %s", stdout, stderr))
		Expect(stdout).To(ContainSubstring("syslog_forwarder"))

		stdout, _, exitStatus, err = bosh.Run(
			"--column=stdout",
			"ssh", "default/0", "-r", "-c",
			tiniCommand,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(exitStatus).To(Equal(0))
		Expect(strings.TrimSpace(stdout)).To(Equal("/usr/libexec/bpm/bin/tini"))
	})
})
