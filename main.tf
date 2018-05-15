terraform {
  backend "s3" {}
}

### For connecting and provisioning
variable "region" {
  default = "ap-southeast-2"
}

variable "aws_access_key" {
  default = ""
}

variable "aws_secret_key" {
  default = ""
}

### For looking up info from the other Terraform States
variable "state_bucket" {
  description = "The bucket name where the chared Terraform state is kept"
}

variable "state_region" {
  description = "The region for the Terraform state bucket"
}

variable "env" {
  description = "The terraform workspace name."
}

### Local Variables
variable "db_user" {}

variable "db_pass" {}
variable "db_name" {}

variable "database_file" {
  default = ""
}

provider "aws" {
  region     = "${var.region}"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  version    = "~> 1.8"
}

locals {
  state_path = "${var.env == "default" ? "" : "env:/${var.env}/" }"
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket = "${var.state_bucket}"
    key    = "${local.state_path}vpc/state.tfstate"
    region = "${var.state_region}"
  }
}

data "terraform_remote_state" "rds" {
  backend = "s3"

  config {
    bucket = "${var.state_bucket}"
    key    = "${local.state_path}rds/state.tfstate"
    region = "${var.state_region}"
  }
}

data "template_file" "create" {
  template = "${file("${path.module}/database_create.sh")}"

  vars {
    master_db_host = "${data.terraform_remote_state.rds.db_host}"
    master_db_user = "${data.terraform_remote_state.rds.db_user}"
    master_db_pass = "${data.terraform_remote_state.rds.db_pass}"

    db_user = "${var.db_user}"
    db_pass = "${var.db_pass}"
    db_name = "${var.db_name}"
  }
}

data "template_file" "load" {
  template = "${file("${path.module}/database_load.sh")}"

  vars {
    master_db_host = "${data.terraform_remote_state.rds.db_host}"
    master_db_user = "${data.terraform_remote_state.rds.db_user}"
    master_db_pass = "${data.terraform_remote_state.rds.db_pass}"
    database_gz    = "${var.database_file}"

    db_name = "${var.db_name}"
  }
}

resource "null_resource" "db" {
  triggers {
    pem = "${data.terraform_remote_state.vpc.bastion_key_pem}"
    ip  = "${data.terraform_remote_state.vpc.bastion_ip}"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = "${data.terraform_remote_state.vpc.bastion_key_pem}"
    host        = "${data.terraform_remote_state.vpc.bastion_ip}"
  }

  provisioner "file" {
    content     = "${data.template_file.create.rendered}"
    destination = "/tmp/database_create_${var.db_name}.sh"
  }

  provisioner "file" {
    content     = "${data.template_file.load.rendered}"
    destination = "/tmp/database_load_${var.db_name}.sh"
  }

  provisioner "remote-exec" {
    # remove old ssh key so that file provisioner doesn't fail
    inline = ["sudo yum install -y mysql57",
      "bash /tmp/database_create_${var.db_name}.sh",
    ]
  }
}

resource "null_resource" "db" {
  count = "${length(var.database_file) ? 1 : 0}"

  triggers {
    pem = "${data.terraform_remote_state.vpc.bastion_key_pem}"
    ip  = "${data.terraform_remote_state.vpc.bastion_ip}"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = "${data.terraform_remote_state.vpc.bastion_key_pem}"
    host        = "${data.terraform_remote_state.vpc.bastion_ip}"
  }

  # Copies the SSH keys over
  provisioner "file" {
    source      = "${path.module}/${var.database_file}"
    destination = "/tmp/${var.database_file}"
  }

  provisioner "remote-exec" {
    # load database if there is none
    inline = ["bash /tmp/database_load_${var.db_name}.sh"]
  }
}

output "create" {
  value = "${data.template_file.create.rendered}"
}

output "load" {
  value = "${data.template_file.load.rendered}"
}

output "db_user" {
  value = "${var.db_user}"
}

output "db_name" {
  value = "${var.db_name}"
}

output "db_pass" {
  value = "${var.db_pass}"
}
