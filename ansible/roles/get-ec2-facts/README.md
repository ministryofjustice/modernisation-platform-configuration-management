Use this module to retrieve information about the EC2 host.
You can then use the EC2 metadata and tag facts within other
roles.

See [ec2_metadata_facts_module.html](https://docs.ansible.com/ansible/latest/collections/amazon/aws/ec2_metadata_facts_module.html)
for available metadata variables.

Tags are registered to `ec2` host variable. Example usage
to debug the "application" tag value.

```
- debug:
    var: ec2.tags.application
```

Where tags have names that are hyphenated you need to reference them as follows:

```
- debug:
    var: ec2.tags['hyphenated-tag-name']
```
