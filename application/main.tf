terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend          "s3"             {}
  required_version = "~> 0.11"
}

provider "aws" {
  region  = "${var.region}"
  version = "~> 1.16"
}

# Shared data and constants

locals {
  environment_name = "${var.project_name}-${var.environment_type}"
}

data "aws_vpc" "vpc" {
  tags = {
    Name = "${local.environment_name}"
  }
}

data "aws_subnet_ids" "private" {
  tags = {
    Type = "private"
  }

  vpc_id = "${data.aws_vpc.vpc.id}"
}

data "aws_subnet" "public_a" {
  tags = {
    Name = "${local.environment_name}_public_a"
  }

  vpc_id = "${data.aws_vpc.vpc.id}"
}

data "aws_security_group" "ssh_in" {
  tags = {
    Type = "SSH"
  }

  vpc_id = "${data.aws_vpc.vpc.id}"
}

data "aws_security_group" "egress_all" {
  tags = {
    Type = "ALL"
  }

  vpc_id = "${data.aws_vpc.vpc.id}"
}

data "aws_ami" "centos" {
  owners      = ["679593333241"]
  most_recent = true

  filter {
    name   = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS *"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_kms_key" "master" {
  key_id = "alias/${local.environment_name}-master"
}
