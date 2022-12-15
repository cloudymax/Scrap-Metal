# Networking options

There are multiple ways to handle networking. Example diagrams for SLIRP and Tap/Tun networking are porvided below.

- [SLIRP manpage](https://manpages.ubuntu.com/manpages/kinetic/man1/slirp4netns.1.html)
- [QEMU networking docs](https://wiki.qemu.org/Documentation/Networking#User_Networking_.28SLIRP.29)
- [How To Set Up WireGuard on Ubuntu](https://www.digitalocean.com/community/tutorials/how-to-set-up-wireguard-on-ubuntu-20-04)
- [Cloud-inint Wireguard module](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#wireguard)

## User Mode (SLIRP)

User Networking is implemented using "slirp", which provides a full TCP/IP stack within QEMU and uses that stack to implement a virtual NAT'd network. This is the default networking backend and generally is the easiest to use. It does not require root / Administrator privileges. It has the following limitations:

  1. there is a lot of overhead so the performance is poor
  2. in general, ICMP traffic does not work (so you cannot use ping within a guest)
  3. on Linux hosts, ping does work from within the guest, but it needs initial setup by root (once per host) -- see the steps below
  4. the guest is not directly accessible from the host or the external network

<img align="center" src="https://raw.githubusercontent.com/cloudymax/Scrap-Metal/main/media/ScrapMetal2.png">


## Tap

The tap networking backend makes use of a tap networking device in the host. It offers very good performance and can be configured to create virtually any type of network topology. Unfortunately, it requires configuration of that network topology in the host which tends to be different depending on the operating system you are using. Generally speaking, it also requires that you have root privileges. 

The scripts located in https://github.com/cloudymax/Scrap-Metal/tree/main/virtual-machines/host-config-resources will help you set this up.

<img align="center" src="https://raw.githubusercontent.com/cloudymax/Scrap-Metal/main/media/ScrapMetal.png">
