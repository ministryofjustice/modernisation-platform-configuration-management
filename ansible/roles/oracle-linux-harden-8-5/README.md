# Role for hardening Oracle Linux
This role is based on the DISA STIG for Oracle Linux 8 profile generated using OSCAP.

Tags can be added to the existing tasks, e.g. - amibuild to include them in the build, bootstrap or patch process

By default the `sssd` authselect profile is enabled, to change this set the `authselect_profile` var.

```
# Find info about a profile
oscap info --profile xccdf_org.ssgproject.content_profile_standard /usr/share/xml/scap/ssg/content/ssg-ol8-ds.xml

# Generate security guide for a profile
oscap xccdf generate guide --profile standard \
/usr/share/xml/scap/ssg/content/ssg-ol8-ds.xml > security_guide.html
# Can be found here - https://static.open-scap.org/ssg-guides/ssg-ol8-guide-index.html

# Evaluate a profile - STIG
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig --fetch-remote-resources --results oscap-results.xml --report oscap-report.html /usr/share/xml/scap/ssg/content/ssg-ol8-ds.xml

# Generate fix - ansible (STIG)
oscap xccdf generate fix --profile xccdf_org.ssgproject.content_profile_stig --fix-type ansible --output ansible.yml results.xml
```
