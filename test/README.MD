# Terratest Unit Tests

## Initialisation

On first set up of a new repository, run:

```
go mod init github.com/ministryofjustice/<repo-name>
```

Then run:

```
go mod tidy
```

# How to run the tests locally

Initialise terraform workspace within the `test/unit-test` directory

```
cd test/unit-test
aws-vault exec mod -- terraform init
aws-vault exec mod -- terraform workspace select testing-test
```

Run the tests from within the `test` directory using the `testing-ci` user credentials.

Get the crededtials from secrets manager using the helper script in the modernisation-platform main repo.

```
cd modernisation-platform/scripts/internal/
aws-vault exec mod -- go run get_testing_creds.go
```

Copy the credentials from the output of the script and paste them into the terminal from which you will run the tests.

Next go into the testing folder and run the tests.

```
cd test
go mod download
go test -v
```

Upon successful run, you should see an output similar to the below

```
TestS3Creation 2022-06-08T14:29:22+01:00 logger.go:66: Destroy complete! Resources: 3 destroyed.
TestS3Creation 2022-06-08T14:29:22+01:00 logger.go:66: 
--- PASS: TestS3Creation (20.60s)
PASS
ok      github.com/ministryofjustice/modernisation-platform-terraform-s3-bucket-replication-role        20.897s
```

## References

1. https://terratest.gruntwork.io/docs/getting-started/quick-start/
2. https://github.com/ministryofjustice/modernisation-platform-terraform-s3-bucket-replication-role/blob/main/.github/workflows/go-terratest.yml
