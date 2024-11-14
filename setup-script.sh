                #!/bin/bash
                # Variables
                DB_NAME="wordpress_db"
                DB_USER="wordpress_user"
                DB_PASSWORD=""  # Replace with a strong password
                WP_URL="https://wordpress.org/latest.tar.gz"

                # Update the system
                sudo yum update -y

                # Install Apache web server
                sudo yum install -y httpd
                sudo systemctl start httpd
                sudo systemctl enable httpd

                # Install PHP and other required PHP extensions
                sudo amazon-linux-extras enable php8.0
                sudo yum clean metadata
                sudo yum install -y php php-mysqlnd php-fpm

                # Install MariaDB (MySQL) server
                sudo yum install -y mariadb-server
                sudo systemctl start mariadb
                sudo systemctl enable mariadb

                # Secure MariaDB installation (non-interactive)
                sudo mysql -e "UPDATE mysql.user SET Password = PASSWORD('${DB_PASSWORD}') WHERE User = 'root'"
                sudo mysql -e "DELETE FROM mysql.user WHERE User=''"
                sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host != 'localhost'"
                sudo mysql -e "DROP DATABASE IF EXISTS test"
                sudo mysql -e "FLUSH PRIVILEGES"

                # Create WordPress database and user
                sudo mysql -u root -p"${DB_PASSWORD}" <<EOF
                CREATE DATABASE ${DB_NAME};
                CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
                GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
                FLUSH PRIVILEGES;
                EOF

                # Download and extract WordPress
                wget ${WP_URL} -P /tmp
                sudo tar -xzf /tmp/latest.tar.gz -C /var/www/html --strip-components=1

                # Configure WordPress database connection
                sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
                sudo sed -i "s/database_name_here/${DB_NAME}/" /var/www/html/wp-config.php
                sudo sed -i "s/username_here/${DB_USER}/" /var/www/html/wp-config.php
                sudo sed -i "s/password_here/${DB_PASSWORD}/" /var/www/html/wp-config.php

                # Set permissions for Apache
                sudo chown -R apache:apache /var/www/html
                sudo chmod -R 755 /var/www/html

                # Start Apache web server
                sudo systemctl restart httpd

                # Open HTTP and HTTPS ports in the firewall
                sudo firewall-cmd --permanent --add-service=http
                sudo firewall-cmd --permanent --add-service=https
                sudo firewall-cmd --reload

                echo "WordPress installation is complete. Access your site at http://$(curl -s ifconfig.me)"
