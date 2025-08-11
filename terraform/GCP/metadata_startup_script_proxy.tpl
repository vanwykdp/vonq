#!/bin/bash
apt-get update
apt-get install -y nginx

cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80;
    location / {
        proxy_pass http://${internal_lb_ip};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

systemctl restart nginx
systemctl enable nginx
