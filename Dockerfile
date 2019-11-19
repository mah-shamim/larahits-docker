#Download base image ubuntu 16.04
FROM ubuntu:16.04
MAINTAINER MD ARIFUL HAQUE <mah.shamim@gmail.com>

# set some environment variables
ENV APP_NAME app
ENV APP_EMAIL app@haqueitsolution.com
ENV APP_DOMAIN app.dev
ENV DEBIAN_FRONTEND noninteractive

# upgrade the container
RUN apt-get update && \
    apt-get upgrade -y

# install some prerequisites
RUN apt-get install -y software-properties-common curl build-essential \
    dos2unix gcc git libmcrypt4 libpcre3-dev memcached make python2.7-dev \
    python-pip re2c unattended-upgrades whois vim libnotify-bin nano wget \
    debconf-utils

# set the locale
RUN apt-get -y install locales
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# add some repositories
RUN apt-add-repository ppa:nginx/stable -y && \
    #apt-add-repository ppa:rwky/redis -y && \
    apt-add-repository ppa:chris-lea/redis-server -y && \
    apt-add-repository ppa:ondrej/php -y && \
    apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 5072E1F5 && \
    sh -c 'echo "deb http://repo.mysql.com/apt/ubuntu/ trusty mysql-8.0" >> /etc/apt/sources.list.d/mysql.list' && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" >> /etc/apt/sources.list.d/postgresql.list' && \
    curl -s https://packagecloud.io/gpg.key | apt-key add - && \
    echo "deb http://packages.blackfire.io/debian any main" | tee /etc/apt/sources.list.d/blackfire.list && \
    curl --silent --location https://deb.nodesource.com/setup_5.x | bash - && \
    apt-get update

# setup bash
COPY .bash_aliases /root

# install nginx
RUN apt-get install -y --force-yes nginx
COPY homestead /etc/nginx/sites-available/
RUN rm -rf /etc/nginx/sites-available/default && \
    rm -rf /etc/nginx/sites-enabled/default && \
    ln -fs "/etc/nginx/sites-available/homestead" "/etc/nginx/sites-enabled/homestead" && \
    sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
    sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf && \
    echo "daemon off;" >> /etc/nginx/nginx.conf && \
    usermod -u 1000 www-data && \
    chown -Rf www-data.www-data /var/www/html/ && \
    sed -i -e"s/worker_processes  1/worker_processes 5/" /etc/nginx/nginx.conf
VOLUME ["/var/www/html/app"]
VOLUME ["/var/cache/nginx"]
VOLUME ["/var/log/nginx"]

# install php
#RUN apt-get install -y --force-yes php7.2 php7.2-fpm php7.2-mysql php7.2-curl php7.2-json php7.2-cgi php7.2-mbstring php7.2-xmlrpc php7.2-soap php7.2-gd php7.2-xml php7.2-intl php7.2-cli php7.2-zip php-xdebug php-common
RUN apt-get install -y --force-yes php7.2 php7.2-fpm php7.2-cli php7.2-dev php7.2-pgsql php7.2-sqlite3 php7.2-gd \
    php-apcu php7.2-curl php7.2-mcrypt php7.2-imap php7.2-mysql php7.2-readline php-xdebug php-common \
    php7.2-mbstring php7.2-xml php7.2-zip
COPY fastcgi_params /etc/nginx/
RUN sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.2/cli/php.ini && \
    sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.2/cli/php.ini && \
    sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.2/cli/php.ini && \
    sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.2/fpm/php.ini && \
    sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.2/fpm/php.ini && \
    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.2/fpm/php.ini && \
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.2/fpm/php.ini && \
    sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/7.2/fpm/php.ini && \
    sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.2/fpm/php.ini && \
    sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.2/fpm/php-fpm.conf && \
    sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php/7.2/fpm/pool.d/www.conf && \
    find /etc/php/7.2/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;
RUN phpenmod mcrypt && \
    mkdir -p /run/php/ && chown -Rf www-data.www-data /run/php

# install sqlite 
RUN apt-get install -y sqlite3 libsqlite3-dev

# install mysql 
RUN echo mysql-server mysql-server/root_password password $DB_PASS | debconf-set-selections;\
    echo mysql-server mysql-server/root_password_again password $DB_PASS | debconf-set-selections;\
    apt-get install -y mysql-server && \
    echo "default_password_lifetime = 0" >> /etc/mysql/my.cnf && \
    sed -i '/^bind-address/s/bind-address.*=.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
RUN /usr/sbin/mysqld & \
    sleep 10s && \
    echo "GRANT ALL ON *.* TO root@'0.0.0.0' IDENTIFIED BY 'secret' WITH GRANT OPTION; CREATE USER 'homestead'@'0.0.0.0' IDENTIFIED BY 'secret'; GRANT ALL ON *.* TO 'homestead'@'0.0.0.0' IDENTIFIED BY 'secret' WITH GRANT OPTION; GRANT ALL ON *.* TO 'homestead'@'%' IDENTIFIED BY 'secret' WITH GRANT OPTION; FLUSH PRIVILEGES; CREATE DATABASE homestead;" | mysql
VOLUME ["/var/lib/mysql"]

# install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    printf "\nPATH=\"~/.composer/vendor/bin:\$PATH\"\n" | tee -a ~/.bashrc
    
# install prestissimo
# RUN composer global require "hirak/prestissimo"

# install laravel envoy
RUN composer global require "laravel/envoy"

#install laravel installer
RUN composer global require "laravel/installer"

# install nodejs
RUN apt-get install -y nodejs

# install gulp
RUN /usr/bin/npm install -g gulp

# install bower
RUN /usr/bin/npm install -g bower

# install redis 
RUN apt-get install -y redis-server

# install blackfire
RUN apt-get install -y blackfire-agent blackfire-php

# install beanstalkd
RUN apt-get install -y --force-yes beanstalkd && \
    sed -i "s/BEANSTALKD_LISTEN_ADDR.*/BEANSTALKD_LISTEN_ADDR=0.0.0.0/" /etc/default/beanstalkd && \
    sed -i "s/#START=yes/START=yes/" /etc/default/beanstalkd && \
    /etc/init.d/beanstalkd start

# install supervisor
RUN apt-get install -y supervisor && \
    mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
VOLUME ["/var/log/supervisor"]

# clean up our mess
RUN apt-get remove --purge -y software-properties-common && \
    apt-get autoremove -y && \
    apt-get clean && \
    apt-get autoclean && \
    echo -n > /var/lib/apt/extended_states && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /usr/share/man/?? && \
    rm -rf /usr/share/man/??_*

# expose ports
EXPOSE 80 443 3306 6379

# set container entrypoints
ENTRYPOINT ["/bin/bash","-c"]
CMD ["/usr/bin/supervisord"]
