package main

import (
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"regexp"
	"testing"
)

func TestS3Creation(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "./unit-test",
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	exampleName := terraform.Output(t, terraformOptions, "example_name")

	assert.Regexp(t, regexp.MustCompile(`^example-name*`), exampleName)
}
