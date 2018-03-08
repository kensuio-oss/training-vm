# Overview

During Kensu training we use Spark-Notebook, Spark, Cassandra; to offer an easy way to use it we propose a VM to import in VMWare or VirtualBox

- build image template with Packer
- create VM instances with Terraform

# Azure
You need to have set your Azure credentials ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID.

# Packer
## Requirements
You need to have an Azure resource group and storage account created and set the related variables AZURE_STORAGE_ACCOUNT, AZURE_RESOURCE_GROUP.

Example:
```
export AZURE_STORAGE_ACCOUNT=kensuiotraining
export AZURE_RESOURCE_GROUP=training
```

During the build Packer create an user to install configuration on VM, you need to set it with variables PACKER_SSH_USER and PACKER_SSH_PASS

Example:
```
export PACKER_SSH_USER=kensu
export PACKER_SSH_PASS=world
```


## Build Azure image
the VM image is built with Packer

```
packer build packer-azure.json
```

## Build Hyper-V image
the VM image is built with Packer

```
packer build packer-hyperv.json
```

# Spark notebook Debian package
https://s3.eu-central-1.amazonaws.com/spark-notebook/deb/spark-notebook_master-scala-2.11.8-spark-2.2.0-hadoop-2.7.2_all.deb

# Terraform

## Destroy
Destroy all resources except resource_group.
`terraform plan -destroy $(for r in `terraform state list | fgrep -v azurerm_resource_group.main` ; do echo "-target ${r} "; done) -out destroy.plan`

And now apply it
`terraform apply "destroy.plan"`

