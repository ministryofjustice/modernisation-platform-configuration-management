Some AWS components time out idle connections after 350s, for example,
the network load balancer. This role sets TCP keepalive to be under
350s (300s by default) to ensure connections that have been opened
with `SO_KEEPALIVE` flag are not timed out.
