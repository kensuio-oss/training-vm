###########
# Training VM
#

variable "instances" {
  type = "string"
  default = "15"
}

resource "random_id" "password" {
  count = "${var.instances}"
  prefix = "${var.project}"
  byte_length = 8
}

variable "user"  {
  type = "map"
  default = {
    name     = "frbayart"
    password = ""
    sshkey   = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCKoW05YHcR2JgZnryTawkMZJBo4ol4P2I8KXTzHKgLxlEIEu7PiWB91hZha7wY6qQhIT/eWj65VNJmPoYkjO65S964eDU5yLbYEooZ6vEOtAVLqwW3O82o6gutDSk+WHyPcEq9esIuaGlPXAK98Br1xnBZqyQ4AKl4/1U35HokAAuFc9+xsDWSmTJ5e9YkHuP9hWEzDKIGCdS6bBh0TuhX3FFk7SkjdqN7+YDlwH03vckRCdjJn1akpjTWhH5b+uuPf7RU5s5uZpuavZNxdFjPZNB1xSgToxOVU5owjLTFO/ua0fxOYx9BGo4+9KN2R8hqmVzb7HuShNDL3Ea4lBG5 frbayart"
  }
}

provider "aws" {
  # This will default to using $AWS_ACCESS_KEY_ID, $AWS_SECRET_ACCESS_KEY, $AWS_DEFAULT_REGION, $AWS_SESSION_TOKEN
  region     = "eu-central-1"
}

data "aws_route53_zone" "kensuio" {
  name         = "kensu.io."
}


# create public IP
resource "azurerm_public_ip" "vm_public_ip" {
  count = "${var.instances}"
  name = "${format("vm%03d_public_ip_%s", count.index + 1, var.project)}"
  location = "${var.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  public_ip_address_allocation = "Dynamic"

  tags {
      environment = "${var.project}"
  }
}


# create network interface
resource "azurerm_network_interface" "vm_nic" {
  count = "${var.instances}"
  name = "${format("vm%03d_nic_%s", count.index + 1, var.project)}"
  location = "${var.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  ip_configuration {
      name = "${format("vm_configuration_%s", var.project)}"
      subnet_id = "${azurerm_subnet.subnet.id}"
      private_ip_address_allocation = "Dynamic"
      public_ip_address_id = "${element(azurerm_public_ip.vm_public_ip.*.id, count.index)}"
  }
}


# create storage container
resource "azurerm_storage_container" "vm_disk" {
  count = "${var.instances}"
  name = "${format("vm%03d-%s-vhd", count.index + 1, var.project)}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  # storage_account_name = "${azurerm_storage_account.storagestd.name}"
  storage_account_name = "kensuiotraining"
  container_access_type = "private"
}

# create virtual machine
resource "azurerm_virtual_machine" "vm_vm" {
    count = "${var.instances}"
    name = "${format("vm%03d-%s", count.index + 1, var.project)}"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.main.name}"
    network_interface_ids = ["${element(azurerm_network_interface.vm_nic.*.id, count.index)}"]
    vm_size = "Standard_D2_V3"

    storage_os_disk {
        name = "myosdisk"
        vhd_uri = "https://kensuiotraining.blob.core.windows.net/${element(azurerm_storage_container.vm_disk.*.name, count.index)}/myosdisk.vhd"
        caching = "ReadWrite"
        create_option = "FromImage"
        image_uri = "${var.imagevhd}"
        os_type = "linux"
    }

    os_profile {
        computer_name = "${format("vm-%s", var.project)}"
        admin_username = "${var.user["name"]}"
        admin_password = "${var.user["password"]}"
    }

    os_profile_linux_config {
      disable_password_authentication = true
      ssh_keys {
        path = "/home/${var.user["name"]}/.ssh/authorized_keys"
        # key_data = "${file("/home/ghagger/.ssh/ps.pem")}"
        key_data = "${var.user["sshkey"]}"
      }

    }

    tags {
      Name = "${format("TRAINING KENSU vm %03d", count.index + 1)}"
      User = "dynamic"
      project = "${var.project}"
      Environment = "${var.project}"
      Hostname = "${format("vm%03d-%s", count.index + 1, var.project)}"
  }
}


// ROUTE53 - vm
resource "aws_route53_record" "dns_vm_pub" {
  depends_on = ["azurerm_virtual_machine.vm_vm","azurerm_public_ip.vm_public_ip","azurerm_network_interface.vm_nic"]
  count   = "${azurerm_virtual_machine.vm_vm.count}"
  zone_id = "${data.aws_route53_zone.kensuio.zone_id}"
  name    = "${element(azurerm_virtual_machine.vm_vm.*.name, count.index )}.pub.${data.aws_route53_zone.kensuio.name}"
  type    = "A"
  ttl     = "60"
  records = ["${element(azurerm_public_ip.vm_public_ip.*.ip_address, count.index)}"]
}

resource "aws_route53_record" "dns_vm_lan" {
  depends_on = ["azurerm_virtual_machine.vm_vm","azurerm_network_interface.vm_nic"]
  count   = "${azurerm_virtual_machine.vm_vm.count}"
  zone_id = "${data.aws_route53_zone.kensuio.zone_id}"
  name    = "${element(azurerm_virtual_machine.vm_vm.*.name, count.index)}.lan.${data.aws_route53_zone.kensuio.name}"
  type    = "A"
  ttl     = "60"
  records = ["${element(azurerm_network_interface.vm_nic.*.private_ip_address, count.index)}"]
}

resource "null_resource" "ansible-provision" {
  triggers = {
    some_ansible_file = "${sha1(file("./inventory"))}"
  }

  ####################################################################
  ##Create vms Inventory
  provisioner "local-exec" {
    command =  "echo \"[vm]\" > inventory"
  }

  provisioner "local-exec" {
    command =  "echo \"${join("\n",formatlist("%s ansible_ssh_host=%s private_hostname=%s inventory_hostname=%s vm_password=%s",
                                                  azurerm_virtual_machine.vm_vm.*.name,
                                                  azurerm_public_ip.vm_public_ip.*.ip_address,
                                                  aws_route53_record.dns_vm_lan.*.name,
                                                  azurerm_virtual_machine.vm_vm.*.name,
                                                  random_id.password.*.hex))
                        }\n\" >> inventory"
  }


  provisioner "local-exec" {
    command =  "echo \"[training-cluster:children]\nvm\n\" >> inventory"
  }

  provisioner "local-exec" {
    command =  "echo \"[training-cluster:vars]\" >> inventory"
  }
  provisioner "local-exec" {
    command =  "echo \"ansible_python_interpreter=/usr/bin/python3\" >> inventory"
  }

  ####################################################################
  ## Create group_vars configuration

  provisioner "local-exec" {
    command = "echo \"---\nremote_user: frbayart\nbecome: yes\nbecome_method: sudo\n\ntimezone: Europe/Brussels\n\nhosts:\" > group_vars_training-cluster.yml"
  }

  provisioner "local-exec" {
    command = "echo \"${join("\n", formatlist("  - { \\\"fqdn\\\": \\\"%s\\\", \\\"shortname\\\": \\\"%s\\\", \\\"ip\\\": \\\"%s\\\" }",
                                                aws_route53_record.dns_vm_lan.*.name,
                                                azurerm_virtual_machine.vm_vm.*.name,
                                                azurerm_network_interface.vm_nic.*.private_ip_address ))
                      }\" >> group_vars_training-cluster.yml"
  }

}

output "vm_info" {
  value = ["${formatlist("%s  -  %s", azurerm_public_ip.vm_public_ip.*.ip_address, aws_route53_record.dns_vm_pub.*.name )}"]
}

