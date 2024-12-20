#!/bin/bash

# -----------------------------------------------------------
# Step1 - Install & Configure NGINX
# -----------------------------------------------------------
yum update
yum install -y nginx

TOKEN=$(curl --request PUT "http://169.254.169.254/latest/api/token" --header "X-aws-ec2-metadata-token-ttl-seconds: 3600")
PUBLIC_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname --header "X-aws-ec2-metadata-token: $TOKEN")

# -----------------------------------------------------------
# Step2 - Install & Configure code-server
# -----------------------------------------------------------
mkdir ~/code-server && cd ~/code-server
wget https://github.com/coder/code-server/releases/download/v4.8.2/code-server-4.8.2-linux-amd64.tar.gz
tar -xzvf code-server-4.8.2-linux-amd64.tar.gz
cp -r code-server-4.8.2-linux-amd64 /usr/lib/code-server
ln -s /usr/lib/code-server/bin/code-server /usr/bin/code-server
mkdir /var/lib/code-server

cat <<EOF > /lib/systemd/system/code-server.service
[Unit]
Description=code-server
After=nginx.service

[Service]
Type=simple
Environment=PASSWORD=IloveEKS123@
ExecStart=/usr/bin/code-server --bind-addr 127.0.0.1:8080 --user-data-dir /var/lib/code-server --auth password
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl start code-server
systemctl enable code-server

cat <<EOF > /etc/nginx/conf.d/code-server.conf
server {
	listen 80;
	listen [::]:80;

	server_name $PUBLIC_HOSTNAME;

	location / {
	  proxy_pass http://localhost:8080/;
	  proxy_set_header Upgrade \$http_upgrade;
	  proxy_set_header Connection upgrade;
	  proxy_set_header Accept-Encoding gzip;
	}
}
EOF

ln -s /etc/nginx/conf.d/code-server.conf /etc/nginx/conf.d/code-server.conf
nginx -t > /home/ubuntu/log.txt

systemctl restart nginx

export HOME=/home/ec2-user
