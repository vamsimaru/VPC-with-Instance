provider "aws" {
  region = "us-east-2"
  access_key = var.access_key
  secret_key = var.secret_key
}
# creating vpc
resource "aws_vpc" "vamsivpc" {
  cidr_block       = "10.0.0.0/26"
  instance_tenancy = "default"

  tags = {
    Name = "vamsivpc"
  }
}
# creating public subnet
resource "aws_subnet" "publicsubnet" {
  vpc_id     = "${aws_vpc.vamsivpc.id}"
  cidr_block = "10.0.0.0/28"

}
# creating private subnet
resource "aws_subnet" "privatesubnet" {
  vpc_id     = "${aws_vpc.vamsivpc.id}"
  cidr_block = "10.0.0.16/28"

}
# creating internet gateawy
resource "aws_internet_gateway" "internetgateway" {
  vpc_id = "${aws_vpc.vamsivpc.id}"

}
# elastic ip for nat
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.internetgateway]
}
# creating nat gateway
resource "aws_nat_gateway" "natgateway" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id     = "${aws_subnet.publicsubnet.id}"
  depends_on = [aws_internet_gateway.internetgateway]
}
# creating route table for public subnet
resource "aws_route_table" "publicroutetable" {
  vpc_id = "${aws_vpc.vamsivpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internetgateway.id}"
  }
}
# creating route table for private subnet
resource "aws_route_table" "privateroutetable" {
  vpc_id = "${aws_vpc.vamsivpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.natgateway.id}"
  }
}
# associating public route table with public subnet
resource "aws_route_table_association" "publicroutetable" {
  subnet_id      = "${aws_subnet.publicsubnet.id}"
  route_table_id = "${aws_route_table.publicroutetable.id}"
}
# associating private route table with private subnet
resource "aws_route_table_association" "privateroutetable" {
  subnet_id      = "${aws_subnet.privatesubnet.id}"
  route_table_id = "${aws_route_table.privateroutetable.id}"
}
# create security groups for vpc
resource "aws_security_group" "SGvpc" {
  name        = "SGvpc"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.vamsivpc.id}"

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.vamsivpc.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}
# create ec2 using above vpc
resource "aws_instance" "EC2" {
  ami                    = "ami-001089eb624938d9f" 
  instance_type          = "t2.micro"
  associate_public_ip_address = "true"
  subnet_id              = "${aws_subnet.publicsubnet.id}"
  vpc_security_group_ids = [aws_security_group.SGvpc.id]
  key_name = var.key_name
}
