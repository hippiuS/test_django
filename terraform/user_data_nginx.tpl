#!/bin/bash
sudo su
apt-get update -y
apt-get install nginx -y
cat<<EOF > /etc/nginx/sites-enabled/default
server {
  listen 80 default_server;
  location / {
    proxy_pass http://127.0.0.1:8000;
  }
  index index.html index.htm index.nginx-debian.html;
}
EOF
nginx -s reload
export DJANGO_SECRET_KEY='${DJANGO_SECRET_KEY}'
export DJANGO_DEBUG='false'
apt-get install python3-pip -y
pip3 install django
git clone https://github.com/hippiuS/test_django.git
python3 test_django/python/projects/locallibrary/manage.py migrate
python3 test_django/python/projects/locallibrary/manage.py runserver
