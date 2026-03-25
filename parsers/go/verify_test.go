package kappa

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAllExamples(t *testing.T) {
	dir := "../../examples/dense"
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".kappa") {
			continue
		}
		src, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			t.Fatal(err)
		}
		result := Parse(string(src))
		fields := 0
		for _, ent := range result.Entities {
			fields += len(ent.Fields)
		}
		if len(result.Diagnostics) > 0 {
			t.Errorf("FAIL %s: %s", e.Name(), result.Diagnostics[0].Message)
		} else {
			t.Logf("PASS %s: %d entities, %d fields", e.Name(), len(result.Entities), fields)
		}
	}
}
