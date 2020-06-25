#!/bin/bash

# You can tail -F /var/log/syslog to see the full startup and check for errors

source /etc/profile.d/load_env.sh

ES_MAJOR="6.x" # used for package installation
ES_VERSION="6.5.4"

# Increase open files limit
echo '*       soft    nofile      4096' >> /etc/security/limits.conf
echo '*       hard    nofile      8192' >> /etc/security/limits.conf

#set up ubuntu user
cat << EOF >> /home/ubuntu/.profile
export TERM="xterm-color"
export PS1='\[\e[0;33m\]\u\[\e[0m\]@\[\e[0;32m\]\h\[\e[0m\]:\[\e[0;34m\]\w\[\e[0m\]\$ '
alias dir='ls -alFGh'
alias hs='history'
alias mytail='tail -F /var/log/nuxeo/server.log'
alias vilog='vi /var/log/nuxeo/server.log'
alias mydu='du -sh */'
EOF

#set up vim for ubuntu user
cat << EOF > /home/ubuntu/.vimrc
" Set the filetype based on the file's extension, but only if
" 'filetype' has not already been set
au BufRead,BufNewFile *.conf setfiletype conf
EOF

# Upgrade packages and install apache, ssh, ...
export DEBIAN_FRONTEND=noninteractive
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
apt-get update
apt-get -q -y upgrade
apt-get -q -y install apache2 apt-transport-https openssh-server openssh-client vim jq
echo "Please wait a few minutes for you instance installation to complete" > /var/www/html/index.html

# Install latest aws cli using pip
apt-get install -q -y python3-pip
pip3 install awscli --upgrade --user
export PATH=$PATH:~/.local/bin/

# Install Java
apt-get -q -y install openjdk-11-jdk

# Install elasticsearch
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/${ES_MAJOR}/apt stable main" > /etc/apt/sources.list.d/elastic-${ES_MAJOR}.list
apt-get update
apt-get -q -y install elasticsearch=${ES_VERSION}
/bin/systemctl daemon-reload
/bin/systemctl enable elasticsearch.service

# Set default ES heap to 1G
sed -i 's/Xms2g/Xms1g/g' /etc/elasticsearch/jvm.options
sed -i 's/Xmx2g/Xmx1g/g' /etc/elasticsearch/jvm.options

service elasticsearch start

# Add the nuxeo repository to the repository list
code=$(lsb_release -cs)
echo "deb http://apt.nuxeo.org/ $code releases" > /etc/apt/sources.list.d/nuxeo.list

# Register the nuxeo key
wget -q -O- http://apt.nuxeo.org/nuxeo.key | apt-key add -

# Pre-accept Sun Java license & set Nuxeo options
echo nuxeo nuxeo/bind-address select 127.0.0.1 | debconf-set-selections
echo nuxeo nuxeo/http-port select 8080 | debconf-set-selections
echo nuxeo nuxeo/database select Autoconfigure PostgreSQL | debconf-set-selections

# Install Nuxeo
apt-get update
apt-get -q -y install nuxeo
service nuxeo stop

#fix imagemagick Policy
wget https://raw.githubusercontent.com/nuxeo-sandbox/nuxeo-sample-aws-cloudformation/master/ImageMagick/policy.xml -O /etc/ImageMagick-6/policy.xml

#decrease nuxeo startup priority
mv /etc/rc3.d/S*nuxeo /etc/rc3.d/S99nuxeo

#skip wizard
sed -i '/nuxeo.wizard.done=false/d' /etc/nuxeo/nuxeo.conf
sed -i '1inuxeo.wizard.done=true' /etc/nuxeo/nuxeo.conf
#enable dev mode
sed -i '1iorg.nuxeo.dev=true' /etc/nuxeo/nuxeo.conf
#use standalone elasticsearch
sed -i '1ielasticsearch.addressList=localhost:9200' /etc/nuxeo/nuxeo.conf
#enable remote debugging
sed -i '1iJAVA_OPTS=$JAVA_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n' /etc/nuxeo/nuxeo.conf

#add s3 bucket property
sed -i '1inuxeo.s3storage.bucket='${STACK_ID}-bucket /etc/nuxeo/nuxeo.conf
sed -i '1inuxeo.s3storage.bucket_prefix=binary_store/' /etc/nuxeo/nuxeo.conf
sed -i '1inuxeo.s3storage.region='${REGION} /etc/nuxeo/nuxeo.conf
sed -i '1inuxeo.s3storage.directdownload=true' /etc/nuxeo/nuxeo.conf
sed -i '1inuxeo.s3storage.directdownload.expire=3600' /etc/nuxeo/nuxeo.conf

#add s3 direct upload config
sed -i '1inuxeo.s3storage.useDirectUpload=true' /etc/nuxeo/nuxeo.conf
sed -i '1inuxeo.s3storage.transient.roleArn='${UPLOAD_ROLE_ARN} /etc/nuxeo/nuxeo.conf
sed -i '1inuxeo.s3storage.transient.bucket='${STACK_ID}-bucket /etc/nuxeo/nuxeo.conf
sed -i '1inuxeo.s3storage.transient.bucket_prefix=upload/' /etc/nuxeo/nuxeo.conf

#register the nuxeo instance
CREDENTIALS=$(aws secretsmanager get-secret-value --secret-id NuxeoConnectToken --region ${REGION} | jq -r '.SecretString|fromjson|.Token')
nuxeoctl register nuxeo_presales ${NX_STUDIO} "dev" "AWS_${STACK_ID}" "${CREDENTIALS}"
nuxeoctl mp-hotfix --accept true
nuxeoctl mp-install nuxeo-web-ui marketplace-disable-studio-snapshot-validation amazon-s3-online-storage amazon-s3-direct-upload ${NX_STUDIO}-0.0.0-SNAPSHOT --accept true

#set up profile for nuxeo user
cat << EOF > /var/lib/nuxeo/server/.profile
export NUXEO_CONF=/etc/nuxeo/nuxeo.conf
cd /var/lib/nuxeo/server/bin
echo  "Hi, nuxeo user. NUXEO_CONF is defined, and you are in /bin, ready to ./nuxeoctl"
alias ll='ls -al'
alias la='ls -a'
alias ..='cd ..'
export TERM="xterm-color"
export PS1='\[\e[0;33m\]\u\[\e[0m\]@\[\e[0;32m\]\h\[\e[0m\]:\[\e[0;34m\]\w\[\e[0m\]\$ '
alias dir='ls -alFGh'
alias hs='history'
alias mytail='tail -F /var/log/nuxeo/server.log'
alias vilog='vi /var/log/nuxeo/server.log'
EOF
chown nuxeo:nuxeo /var/lib/nuxeo/server/.profile

#set up vim for nuxeo user
cat << EOF > /var/lib/nuxeo/server/.vimrc
" Set the filetype based on the file's extension, but only if
" 'filetype' has not already been set
au BufRead,BufNewFile *.conf setfiletype conf
EOF
chown nuxeo:nuxeo /var/lib/nuxeo/server/.vimrc

# Configure reverse-proxy
cat << EOF > /etc/apache2/sites-available/nuxeo.conf
<VirtualHost _default_:80>

    CustomLog /var/log/apache2/nuxeo_access.log combined
    ErrorLog /var/log/apache2/nuxeo_error.log

    DocumentRoot /var/www

    ProxyRequests   Off
     <Proxy * >
        Order allow,deny
        Allow from all
     </Proxy>

    RewriteEngine   On
    RewriteRule ^/$ /nuxeo/ [R,L]
    RewriteRule ^/nuxeo$ /nuxeo/ [R,L]

    ProxyPass           /nuxeo/         http://localhost:8080/nuxeo/
    ProxyPassReverse    /nuxeo/         http://localhost:8080/nuxeo/
    ProxyPreserveHost   On

    # WSS
    ProxyPass         /_vti_bin/     http://localhost:8080/_vti_bin/
    ProxyPass         /_vti_inf.html http://localhost:8080/_vti_inf.html
    ProxyPassReverse  /_vti_bin/     http://localhost:8080/_vti_bin/
    ProxyPassReverse  /_vti_inf.html http://localhost:8080/_vti_inf.html

</VirtualHost>
EOF

# Add gzip compression for the REST API
cat > /etc/apache2/mods-available/deflate.conf <<EOF
<IfModule mod_deflate.c>
        <IfModule mod_filter.c>
                # these are known to be safe with MSIE 6
                AddOutputFilterByType DEFLATE text/html text/plain text/xml

                # everything else may cause problems with MSIE 6
                AddOutputFilterByType DEFLATE text/css
                AddOutputFilterByType DEFLATE application/x-javascript application/javascript application/ecmascript
                AddOutputFilterByType DEFLATE application/rss+xml
                AddOutputFilterByType DEFLATE application/xml
                AddOutputFilterByType DEFLATE application/json
        </IfModule>
</IfModule>
EOF

a2enmod proxy proxy_http rewrite ssl headers
a2dissite 000-default
a2ensite nuxeo
apache2ctl -k graceful
