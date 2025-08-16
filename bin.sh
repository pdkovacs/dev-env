cat >${HOME}/bin/xcaliapp.sh <<EOF
#!/bin/bash
XCALIAPP_USERNAME="peter.dunay.kovacs@gmail.com" SERVER_PORT=8888 DRAWINGSTORE_LOCATION=${HOME}/gitlab/diagrams/xcalidraw ${HOME}/workspace/xcaliapp/server/xcaliapp_linux_amd64
EOF
chmod +x ${HOME}/bin/xcaliapp.sh
