# AWS OpenVPN Server Terraform Configuration

# Configure AWS provider
provider "aws" {
  region = var.region
}

# Variables
variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR for VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR for subnet"
  default     = "10.0.1.0/24"
}

variable "key_name" {
  description = "SSH key name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "my_ip" {
  description = "Your IP address to allow SSH access"
  type        = string
}

# Create VPC
resource "aws_vpc" "vpn_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "vpn-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "vpn_igw" {
  vpc_id = aws_vpc.vpn_vpc.id
  
  tags = {
    Name = "vpn-igw"
  }
}

# Create Subnet
resource "aws_subnet" "vpn_subnet" {
  vpc_id                  = aws_vpc.vpn_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
  
  tags = {
    Name = "vpn-subnet"
  }
}

# Create Route Table
resource "aws_route_table" "vpn_route_table" {
  vpc_id = aws_vpc.vpn_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpn_igw.id
  }
  
  tags = {
    Name = "vpn-route-table"
  }
}

# Associate Route Table to Subnet
resource "aws_route_table_association" "vpn_rta" {
  subnet_id      = aws_subnet.vpn_subnet.id
  route_table_id = aws_route_table.vpn_route_table.id
}

# Security Group for OpenVPN
resource "aws_security_group" "vpn_sg" {
  name        = "vpn-security-group"
  description = "Security group for OpenVPN server"
  vpc_id      = aws_vpc.vpn_vpc.id
  
  # SSH access from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
    description = "SSH access"
  }
  
  # OpenVPN access
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "OpenVPN UDP"
  }

  # Web Admin Console (optional)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
    description = "HTTPS Admin"
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "vpn-sg"
  }
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create EC2 instance for OpenVPN
resource "aws_instance" "openvpn" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.vpn_subnet.id
  vpc_security_group_ids = [aws_security_group.vpn_sg.id]
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y amazon-linux-extras
              amazon-linux-extras install epel -y
              yum install -y wget net-tools
              
              # Install OpenVPN
              wget -O /tmp/openvpn-install.sh https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
              chmod +x /tmp/openvpn-install.sh
              
              # Auto-install OpenVPN with default settings
              export AUTO_INSTALL=y
              export APPROVE_IP=y
              export IPV4_SUPPORT=y
              export IPV6_SUPPORT=n
              export PORT_CHOICE=1
              export PROTOCOL_CHOICE=1
              export DNS=1
              export COMPRESSION_ENABLED=n
              export CUSTOMIZE_ENC=n
              export CLIENT="client"
              export PASS=1
              
              /tmp/openvpn-install.sh
              
              # Create a script to generate more client certificates
              cat > /usr/local/bin/create-client.sh <<'EOT'
              #!/bin/bash
              if [ -z "$1" ]; then
                echo "Please provide a client name"
                exit 1
              fi
              cd /etc/openvpn/easy-rsa/
              ./easyrsa build-client-full "$1" nopass
              newclient "$1"
              cat ~/"$1.ovpn"
              EOT
              
              chmod +x /usr/local/bin/create-client.sh
              EOF
  
  root_block_device {
    volume_size = 10
    volume_type = "gp2"
  }
  
  tags = {
    Name = "openvpn-server"
  }
}

# Output the server's public IP
output "openvpn_server_ip" {
  value = aws_instance.openvpn.public_ip
}

# Instructions output
output "openvpn_instructions" {
  value = <<EOF
    
    OpenVPN server has been deployed.
    
    To access your OpenVPN server:
    1. SSH into the server: ssh -i your-key.pem ec2-user@${aws_instance.openvpn.public_ip}
    2. The client configuration file is at: /root/client.ovpn
    3. Copy this file to your local machine: scp -i your-key.pem ec2-user@${aws_instance.openvpn.public_ip}:/root/client.ovpn .
    4. Import this .ovpn file into your OpenVPN client
    
    To create additional client certificates:
    ssh -i your-key.pem ec2-user@${aws_instance.openvpn.public_ip}
    sudo /usr/local/bin/create-client.sh client2
    
    This will output a new client2.ovpn file that you can transfer to another device.
    
  EOF
}