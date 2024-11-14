# Provider
provider "aws" {
  region = "us-east-1"  # Change to your preferred region
}

terraform {
  backend "s3" {
    bucket = "zaftech-terraform"
    key    = "wordpress"
    region = "us-east-1" // Change this to match the region of your S3 bucket
  }
}

# Variables
variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "9004"
}

variable "instance_type" {
  description = "EC2 instance type for the WordPress server"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for the WordPress VM"
  type        = string
  default     = "ami-0ddc798b3f1a5117e"  # Example AMI for Amazon Linux 2
}

# VPC
resource "aws_vpc" "wordpress_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "wordpress-vpc"
  }
}

# Subnet
resource "aws_subnet" "wordpress_subnet" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"  # Change based on your availability zone

  tags = {
    Name = "wordpress-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "wordpress_igw" {
  vpc_id = aws_vpc.wordpress_vpc.id

  tags = {
    Name = "wordpress-igw"
  }
}

# Route Table
resource "aws_route_table" "wordpress_route_table" {
  vpc_id = aws_vpc.wordpress_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wordpress_igw.id
  }

  tags = {
    Name = "wordpress-route-table"
  }
}

# Route Table Association
resource "aws_route_table_association" "wordpress_rta" {
  subnet_id      = aws_subnet.wordpress_subnet.id
  route_table_id = aws_route_table.wordpress_route_table.id
}

# Security Group
resource "aws_security_group" "wordpress_sg" {
  vpc_id      = aws_vpc.wordpress_vpc.id
  name        = "wordpress-sg"
  description = "Allow HTTP and HTTPS traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress-sg"
  }
}

# EC2 Instance
resource "aws_instance" "wordpress_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.wordpress_subnet.id
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]

  user_data = <<-EOF
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
                EOF

  tags = {
    Name = "WordPressInstance"
  }
}

# Output the instance public IP
output "instance_public_ip" {
  value       = aws_instance.wordpress_instance.public_ip
  description = "Public IP of the WordPress instance"
}
