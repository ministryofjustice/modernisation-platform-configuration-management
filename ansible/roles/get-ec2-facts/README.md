Use this module to retrieve information about the EC2 host.

The EC2 will require either ec2:DescribeInstances or ec2:DescribeTags
permissions. If the former, full ec2 instance info is available
under the ec2 fact. If just the tags, only tag information is
available under the ec2 fact.

For available metadata variables, see:

- [ec2_metadata_facts_module](https://docs.ansible.com/ansible/latest/collections/amazon/aws/ec2_metadata_facts_module.html)

For metadata made available under `ec2` fact, see:

- [ec2_instance_info_module](https://docs.ansible.com/ansible/latest/collections/amazon/aws/ec2_instance_info_module.html)
- [ec2_tag_info_module](https://docs.ansible.com/ansible/latest/collections/amazon/aws/ec2_tag_info_module.html)

Examples:

```
# this works if server has DescribeInstances or just DescribeTags permissions
- debug:
    var: ec2.tags.application


# this only works if server has DescribeInstances permissions
- debug:
    var: ec2.block_device_mappings
```

Where tags have names that are hyphenated you need to reference them as follows:

```
- debug:
    var: ec2.tags['hyphenated-tag-name']
```
