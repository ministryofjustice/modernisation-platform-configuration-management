Takes the value of `fixngo-connection-target` from hosts in an environment and pings them using netcat to return a 'connected' metric. 

In the modernisation-platform-environments repo you can add this tag (e.g. fixngo-connection-target = "<ip address>") and an associated alarm config to set up an alarm which will trigger if connection from that EC2 instance to the target IP address is lost.