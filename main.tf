# Define the AWS provider configuration.
provider "aws" {
  region = "us-east-2" # Replace with your desired AWS region.
}


# Variable declaration for VPC CIDR block.
variable "cidr" {
  default = "10.0.0.0/16"
}

# Key pair resource.
resource "aws_key_pair" "example" {
  key_name   = "terraform-demo-new" # Replace with your desired key name.
  public_key =  file("/home/mathias/Desktop/projects/terraform/terraform-demo.pem.pub") # Path to your public key file.
}

# VPC resource.
resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

# Subnet resource.
resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
}

# Internet Gateway resource.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

# Route table resource.
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Route table association.
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

# Security group resource.
resource "aws_security_group" "webSg" {
  name   = "web"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
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

  tags = {
    Name = "Web-sg"
  }
}

# EC2 instance resource.
resource "aws_instance" "example" {
  ami                    = "ami-036841078a4b68e14" # Replace with the correct AMI ID.
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.example.key_name
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.sub1.id

  # SSH connection settings.
  connection {
    type        = "ssh"
    user        = "ubuntu"               # Username for the EC2 instance.
    private_key = file("/home/mathias/Desktop/projects/terraform/terraform-demo.pem")  # Path to your private key file.
    host        = self.public_ip
  }

  # File provisioner: Copies app.py to the remote instance.
  provisioner "file" {
    source      = "/home/mathias/Desktop/projects/terraform/app.py" # Path to the local file.
    destination = "/home/ubuntu/app.py"                        # Path on the remote instance.
  }

  # Remote-exec provisioner: Runs commands on the EC2 instance.
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ubuntu",
      "echo 'Hello from the remote instance'",
      "sudo apt update -y",                  # Update package lists.
      "sudo apt-get install -y python3-pip", # Install Python pip.
      "cd /home/ubuntu",
      "sudo pip3 install flask",             # Install Flask.
      "sudo python3 app.py &",               # Run app.py in the background.
    ]
  }
}



