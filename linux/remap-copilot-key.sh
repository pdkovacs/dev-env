sudo add-apt-repository ppa:keyd-team/ppa
sudo apt update
sudo apt install keyd
# Create /etc/keyd/default.conf with the following content
# [ids]

# *

# [main]

# leftshift+leftmeta+f23 = rightcontrol
sudo vim /etc/keyd/default.conf
sudo systemctl restart keyd
