#!/bin/bash
export PATH=$PATH:"{{ osw_install_dir }}/jdk1.7.0_80/bin"
java -jar "{{ osw_install_dir }}/osbws_install.jar" -ARGFILE "{{ osw_install_dir }}/osbws_argfile" -IAMRole "{{ ansible_ec2_iam_instance_profile_role }}" -useHttps | logger -p local3.info -t java
