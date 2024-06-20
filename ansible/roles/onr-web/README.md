# Overview

Installs the Web-Tier software for ONR on the target server.

Currently this also relies on it being installed on a Rhel 6.9 server.

This role is part of the ONR project.

# Deploying multiple web-tier instances

No per-instance install changes are needed for the web-tier. This is all handled within the load-balancer set up in the `modernisation-platform-environments` repo.
