package smoke_test

import (
	"strconv"
	"strings"

	"github.com/onsi/gomega/types"

	"fmt"

	. "github.com/onsi/gomega"
)

// This matcher is expected to be run with an Eventually, and not an Expect.

func BeLogRotated() types.GomegaMatcher {
	return &beLogRotatedMatcher{
		previousFileSize: -1,
		currentFileSize:  -1,
	}
}

type beLogRotatedMatcher struct {
	previousFileSize int
	currentFileSize  int
}

func getFileSize(filepath string) int {
	command := fmt.Sprintf("sudo du %s | cut -f1", filepath)

	stdOut, _, _, err := bosh.Run("ssh", "--column=stdout", "--results", "default/0", command)
	Expect(err).ToNot(HaveOccurred())
	size, err := strconv.Atoi(strings.TrimSpace(stdOut))
	Expect(err).ToNot(HaveOccurred(), "error converting kB file size to integer")

	return size
}

func (matcher *beLogRotatedMatcher) Match(actual interface{}) (success bool, err error) {
	filepath := actual.(string)
	if matcher.currentFileSize == -1 {
		matcher.currentFileSize = getFileSize(filepath)
		return false, nil
	}

	matcher.previousFileSize = matcher.currentFileSize
	matcher.currentFileSize = getFileSize(filepath)

	return matcher.currentFileSize < matcher.previousFileSize, nil
}

func (matcher *beLogRotatedMatcher) FailureMessage(actual interface{}) (message string) {
	return fmt.Sprintf("Logfile '%v' was larger than expected. It should have been rotated.", actual)
}

func (matcher *beLogRotatedMatcher) NegatedFailureMessage(actual interface{}) (message string) {
	return fmt.Sprintf("Logfile '%v' was smaller than expected. It should not have been rotated.", actual)
}
