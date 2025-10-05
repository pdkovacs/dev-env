######################################
# xcaliapp.sh
######################################
cat > ${HOME}/bin/xcaliapp.sh <<EOF
#!/bin/bash
XCALIAPP_USERNAME="peter.dunay.kovacs@gmail.com" \
  SERVER_PORT=8888 \
  XCALIAPP_DRAWINGREPO_LIST="wsgw:WebSocket Gateway,xcaliapp:Excalidraw Application" \
  XCALIAPP_DRAWINGREPO_wsgw_STORETYPE=LOCAL_GIT \
  XCALIAPP_DRAWINGREPO_wsgw_ROOT=${HOME}/github/pdkovacs/wsgw \
  XCALIAPP_DRAWINGREPO_wsgw_PATH=doc/design/diagrams \
  XCALIAPP_DRAWINGREPO_xcaliapp_STORETYPE=LOCAL_GIT \
  XCALIAPP_DRAWINGREPO_xcaliapp_ROOT=${HOME}/gitlab/diagrams/xcalidraw \
  XCALIAPP_DRAWINGREPO_xcaliapp_PATH=/ \
  ${HOME}/workspace/xcaliapp/server/xcaliapp_linux_amd64
EOF
chmod +x ${HOME}/bin/xcaliapp.sh


######################################
# z
######################################
curl https://codeload.github.com/rupa/z/tar.gz/refs/tags/v1.12 -o ~/Downloads/z-1.12.tar.gz
cd ~/Downloads/
tar xzf z-1.12.tar.gz
cd z-1.12/
mkdir ~/bin
cp z.sh ~/bin/
