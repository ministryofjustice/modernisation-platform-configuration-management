# Role for creating SWAP as file on existing disk

To use a dedicated EBS volume for SWAP, please use the `disks` role.

This role will create a swapfile and mount it - so it persists reboot.
It will add additional swap if required.
It won't remove any existing swap.

The swap filename will get a numeric postfix added, e.g.

```
/swapfile.0
/swapfile.1
```
