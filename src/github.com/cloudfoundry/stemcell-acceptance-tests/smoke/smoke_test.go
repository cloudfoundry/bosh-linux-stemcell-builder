package smoke_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Stemcell", func() {
	Context("When syslog release has been deployed", func() {
		It("hello", func() {
			Expect(true).To(BeTrue())
		})
	})
})
