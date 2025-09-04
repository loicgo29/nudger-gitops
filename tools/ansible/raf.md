apt install ansible-core  # version 2.12.0-1ubuntu0.1, or
apt install ansible       # version 2.10.7+merged+base+2.10.8+dfsg-1
# Téléchargement + permission + déplacement
curl -Lo kube-linter https://github.com/stackrox/kube-linter/releases/download/v0.7.5/kube-linter-linux
chmod +x kube-linter
sudo mv kube-linter /usr/local/bin/
