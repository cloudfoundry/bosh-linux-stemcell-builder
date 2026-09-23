package bpm_system_test

import (
	"fmt"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// The stemcell has python3 but not jq.
const tiniCommand = `sudo python3 -c 'import json; print(json.load(open("/var/vcap/data/bpm/bundles/syslog_forwarder/syslog_forwarder/config.json"))["process"]["args"][0])'`

var _ = Describe("Stemcell BPM System", func() {
	It("runs syslog_forwarder using stemcell bpm without bpm job", func() {
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
