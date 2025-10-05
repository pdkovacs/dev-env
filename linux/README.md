# AMD

## Work around wireless issues

### Wifi

#### Disable power management in kernel module

```
pkovacs@dell14-1:~ $ cat /etc/modprobe.d/iwlwifi.conf
# /etc/modprobe.d/iwlwifi.conf
# iwlwifi will dyamically load either iwldvm or iwlmvm depending on the
# microcode file installed on the system.  When removing iwlwifi, first
# remove the iwl?vm module and then iwlwifi.
remove iwlwifi \
(/sbin/lsmod | grep -o -e ^iwlmvm -e ^iwldvm -e ^iwlwifi | xargs /sbin/rmmod) \
&& /sbin/modprobe -r mac80211
options iwlwifi disable_11ax=Y
options iwlwifi power_save=0
options iwlmvm power_scheme=1

pkovacs@dell14-1:~ $ sudo modprobe iwlwifi
```

#### Disable power management in NetworkManager

```
pkovacs@dell14-1:~ $ cat /etc/NetworkManager/conf.d/wifi-powersave-off.conf
[connection]
wifi.powersave = 2
pkovacs@dell14-1:~ $ 
```

```
pkovacs@dell14-1:~ $sudo systemctl restart NetworkManager
```

```
pkovacs@dell14-1:~ $iwconfig wlp194s0 | grep "Power Management"
```

### Bluetooth

```
pkovacs@dell14-1:~ $ grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash btusb.enable_autosuspend=n"
pkovacs@dell14-1:~ $ 
```

```
sudo update-grub
```

# Gnome

## Terminal

```
bash -c "$(wget -qO- https://git.io/vQgMr)"
```

Then select `217 219 220 247` (I guess)
