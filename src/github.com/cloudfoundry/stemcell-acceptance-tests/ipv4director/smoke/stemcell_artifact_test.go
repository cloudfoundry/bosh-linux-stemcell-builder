package smoke_test

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	"github.com/cloudfoundry/bosh-utils/system"
	"github.com/cloudfoundry/stemcell-acceptance-tests/testhelpers"
	"gopkg.in/yaml.v2"
)

type stemcellManifest struct {
	Name            string   `yaml:"name"`
	Version         string   `yaml:"version"`
	Sha1            string   `yaml:"sha1"`
	OperatingSystem string   `yaml:"operating_system"`
	StemcellFormats []string `yaml:"stemcell_formats"`
	BoshProtocol    int      `yaml:"bosh_protocol"`
	ApiVersion      int      `yaml:"api_version"`
}

func loadStemcellManifest(manifestPath string) (stemcellManifest, error) {
	ret := stemcellManifest{}

	manifest, err := ioutil.ReadFile(manifestPath)
	if err != nil {
		return ret, err
	}

	err = yaml.Unmarshal(manifest, &ret)
	if err != nil {
		return ret, err
	}

	return ret, nil
}

var _ = Describe("stemcell.tgz", func() {
	var stemcellPath string
	var cmdRunner system.CmdRunner
	var tmpdir string

	BeforeEach(func() {
		var err error

		stemcellPath = testhelpers.RequireEnv("STEMCELL_PATH")
		cmdRunner = system.NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelDebug))

		tmpdir, err = ioutil.TempDir("", "")
		Expect(err).To(Succeed())
	})

	Context("stemcell manifest", func() {
		It("contains a stemcell manifest", func() {
			stdOut, stdErr, exitStatus, err := cmdRunner.RunCommand("tar", "-C", tmpdir, "-xvf", stemcellPath, "stemcell.MF")
			Expect(err).ToNot(HaveOccurred())
			Expect(exitStatus).To(Equal(0), fmt.Sprintf("tar exited nonzero. stdOut: %s \n stdErr: %s", stdOut, stdErr))

			info, err := os.Stat(filepath.Join(tmpdir, "stemcell.MF"))
			Expect(err).ToNot(HaveOccurred())
			Expect(info.IsDir()).To(Equal(false))

			stemcellManifest, err := loadStemcellManifest(filepath.Join(tmpdir, "stemcell.MF"))
			Expect(err).ToNot(HaveOccurred())

			Expect(stemcellManifest.Name).NotTo(Equal(""))
			Expect(stemcellManifest.Version).NotTo(Equal(""))
			Expect(stemcellManifest.Sha1).NotTo(Equal(""))
			Expect(stemcellManifest.OperatingSystem).NotTo(Equal(""))
			Expect(stemcellManifest.StemcellFormats).NotTo(Equal([]string{}))

			Expect(stemcellManifest.BoshProtocol).To(Equal(1))
			Expect(stemcellManifest.ApiVersion).To(Equal(3))
		})
	})
})
