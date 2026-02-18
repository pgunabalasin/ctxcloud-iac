provider "aws" {
  region = var.region
}

module "vpc" {
  source              = "./modules/vpc"
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
}

module "firewall" {
  source            = "./modules/firewall"
  public_subnet_id  = module.vpc.public_subnet_id
  private_subnet_id = module.vpc.private_subnet_id
  fw_instance_type  = var.fw_instance_type
  fw_ami            = var.fw_ami
  key_name          = var.key_name
}

module "k8s_server" {
  source        = "./modules/k8s_server"
  subnet_id     = module.vpc.private_subnet_id
  ami_id        = var.k8s_ami_id
  instance_type = var.k8s_instance_type
  key_name      = var.key_name
}

module "honeypot" {
  source           = "./modules/honeypot"
  subnet_id        = module.vpc.private_subnet_id  # Assuming private subnet from VPC module
  ami_id           = var.honeypot_ami_id
  instance_type    = var.honeypot_instance_type
  key_name         = var.key_name
  dshield_email    = var.dshield_email
  dshield_api_key  = var.dshield_api_key
}
# EC2 Instance for ctxcloud - 
module "ec2" {
  source          = "./modules/ec2"
  region          = var.region
  ami_id          = var.ec2_ami_id
  instance_type   = var.ec2_instance_type
  subnet_id       = module.vpc.public_subnet_id
  instance_name   = "ctxcloud-ec2"
}

# Route table for private subnet to route traffic through the firewall's trust interface
resource "aws_route_table" "private" {
  vpc_id = module.vpc.vpc_id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = module.firewall.trust_eni_id
  }
  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = module.vpc.private_subnet_id
  route_table_id = aws_route_table.private.id
}
