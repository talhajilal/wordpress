# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}

# Create a VPC
resource "aws_vpc" "wordpress_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "WordPress VPC"
  }
}

# Create a subnet
resource "aws_subnet" "wordpress_subnet" {
  vpc_id            = (link unavailable)
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "WordPress Subnet"
  }
}

# Create a security group
resource "aws_security_group" "wordpress_sg" {
  name        = "WordPress SG"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = (link unavailable)

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an EC2 instance
resource "aws_instance" "wordpress_instance" {
  ami           = "ami-0c94855ba95c71c99" # Ubuntu 20.04 LTS
  instance_type = "t2.micro"
  subnet_id     = (link unavailable)
  vpc_security_group_ids = [(link unavailable)]
  key_name               = "your_ssh_key"

  tags = {
    Name = "WordPress Instance"
  }
}

# Create an Elastic IP
resource "aws_eip" "wordpress_eip" {
  instance = (link unavailable)
  vpc      = true
}

# Install and configure WordPress
resource "null_resource" "install_wordpress" {
  connection {
    type        = "ssh"
    host        = aws_eip.wordpress_eip.public_ip
    user        = "ubuntu"
    private_key = file("~/.ssh/your_ssh_key")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2 mysql-server php7.4 php7.4-mysql",
      "sudo mysql -u root <<EOF",
      "CREATE DATABASE wordpress;",
      "CREATE USER 'wordpressuser'@'%' IDENTIFIED BY 'password';",
      "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpressuser'@'%';",
      "FLUSH PRIVILEGES;",
      "EOF",
      "sudo wget (link unavailable)",
      "sudo tar -xvf latest.tar.gz",
      "sudo mv wordpress/* /var/www/html/",
      "sudo chown -R www-data:www-data /var/www/html/",
      "sudo systemctl restart apache2"
    ]
  }
}

