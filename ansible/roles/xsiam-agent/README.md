Role to install XSIAM cortex agent via RPM install

Agent software must be copied to S3 bucket using business unit KMS key, e.g.

```
aws s3 cp LIVE_linux_8_8_0_133595_rpm.tar.gz s3://mod-platform-image-artefact-bucket20230203091453221500000001/hmpps/XSIAM/Agents/Linux/LIVE/LIVE_linux_8_8_0_133595_rpm.tar.gz --sse aws:kms --sse-kms-key-id REDACTED --acl bucket-owner-full-control
```

Once installed, check status with `systemctl status traps_pmd`
