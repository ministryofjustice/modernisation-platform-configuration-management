#!/bin/bash
export PATH=$PATH:"{{ osw_stage_dir }}/jdk1.7.0_80/bin"
java -jar "{{ osw_stage_dir }}/osbws_install.jar" -ARGFILE "{{ osw_stage_dir }}/{{ osbws_config.name }}_argfile" -IAMRole "{{ ansible_ec2_iam_instance_profile_role }}" -useHttps -no-check-certificate -trustedCerts "{{ osw_stage_dir }}/AmazonRootCA1.pem" | logger -p local3.info -t java
