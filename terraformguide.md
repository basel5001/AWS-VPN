# AWS VPN Deployment Guide

This guide provides instructions for deploying two different VPN solutions on AWS using Terraform:

1. **OpenVPN Server**: For secure internet browsing from anywhere
2. **WireGuard VPN**: For accessing your home PC remotely

## Prerequisites

Before you begin, make sure you have:

- [Terraform](https://www.terraform.io/downloads.html) installed (v1.0.0+)
- [AWS CLI](https://aws.amazon.com/cli/) installed and configured with your credentials
- SSH key pair created in your AWS account
- Your current public IP address (you can get it from [whatismyip.com](https://www.whatismyip.com/))
- Public IP address of your home PC (if using the WireGuard solution)

## Deployment Instructions

### Step 1: Prepare the Configuration Files

1. Create a new directory for your Terraform project:
   ```bash
   mkdir aws-vpn && cd aws-vpn
   ```

2. Copy the OpenVPN or WireGuard Terraform configuration into a file named `main.tf`.

3. Create a `terraform.tfvars` file with your variable values:
   ```
   region     = "us-east-1"  # Choose your preferred region
   key_name   = "your-key-name"  # The name of your SSH key in AWS
   my_ip      = "123.456.789.0/32"  # Your current IP address with /32 CIDR
   home_pc_ip = "98.765.432.1"  # Only needed for WireGuard solution
   ```

### Step 2: Deploy the Infrastructure

1. Initialize the Terraform project:
   ```bash
   terraform init
   ```

2. Preview the changes:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

4. Confirm by typing `yes` when prompted.

5. After deployment completes (5-10 minutes), Terraform will output:
   - The VPN server's public IP address
   - Instructions for connecting to your VPN

### Step 3: Connecting to Your VPN

#### For OpenVPN:

1. SSH into your server to retrieve the client configuration:
   ```bash
   ssh -i your-key.pem ec2-user@<openvpn_server_ip>
   sudo cat /root/client.ovpn
   ```

2. Copy the output to a file named `client.ovpn` on your local machine.

3. Import this configuration into an OpenVPN client like:
   - [OpenVPN Connect](https://openvpn.net/client/) (Windows, macOS, Linux, iOS, Android)
   - [Tunnelblick](https://tunnelblick.net/) (macOS)

#### For WireGuard (Accessing Home PC):

1. SSH into your server to retrieve the client configuration:
   ```bash
   ssh -i your-key.pem ubuntu@<wireguard_server_ip>
   sudo cat /etc/wireguard/client.conf
   ```

2. For mobile devices, you can scan the QR code:
   ```bash
   ssh -i your-key.pem ubuntu@<wireguard_server_ip>
   sudo cat /etc/wireguard/client_qr.txt
   ```

3. On your home PC, install WireGuard:
   - [WireGuard Download](https://www.wireguard.com/install/)

4. Get the home PC configuration:
   ```bash
   ssh -i your-key.pem ubuntu@<wireguard_server_ip>
   sudo cat /etc/wireguard/homepc.conf
   ```

5. Create a new WireGuard tunnel on your home PC with this configuration.

6. Start the WireGuard tunnel on your home PC.

7. Now, when you connect to the WireGuard VPN from your mobile/client device, you can access your home PC at `10.66.66.3`.

## Security Considerations

1. **SSH Access**: The configurations restrict SSH access to your current IP address. If your IP changes, you'll need to update the security group rules.

2. **Authentication**: The OpenVPN setup uses certificate-based authentication. The WireGuard setup uses cryptographic keys.

3. **Firewall Rules**: Both configurations create AWS security groups that act as firewalls, allowing only necessary traffic.

4. **Client Management**:
   - For OpenVPN, you can create additional client certificates using the provided script.
   - For WireGuard, you'll need to add new peer configurations manually.

## Clean Up

To destroy the infrastructure when no longer needed:

```bash
terraform destroy
```

Confirm by typing `yes` when prompted.

## Troubleshooting

1. **Connection Issues**: 
   - Verify security group rules are correct
   - Check if the VPN service is running on the instance
   - Verify client configuration files

2. **Home PC Connection**:
   - Ensure your home PC has a static public IP or use dynamic DNS
   - Make sure the WireGuard client is running on your home PC
   - Check if your home router allows incoming WireGuard connections

3. **Performance Issues**:
   - Consider upgrading the EC2 instance type if you need more performance
   - WireGuard typically offers better performance than OpenVPN