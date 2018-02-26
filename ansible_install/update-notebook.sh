#! /usr/bin/env bash

NOTEBOOK_URL="https://s3-eu-west-1.amazonaws.com/kensuio-training/mic-ds-2018/vm-notebooks-training.tar.gz"

if [[ "$USER" != "spark-notebook" ]] ; then
	echo "You must run this script as spark-notebook user"
	exit 1
fi

# Get latest version of notebook
echo -n "Download latest version of training notebooks from S3: "

wget -qO /tmp/notebooks.tar.gz ${NOTEBOOK_URL}

if [[ $? -eq 0 ]] ; then
	echo "done."
else
	echo "failed. Check network connectivity !"
	exit 2
fi

# Stop on error
set -e

if [[ ! -d "/usr/share/spark-notebook/notebooks/training" ]] ; then
	mkdir /usr/share/spark-notebook/notebooks/training
fi

echo -n "Extract new version of training notebooks: "
tar xf /tmp/notebooks.tar.gz -C /usr/share/spark-notebook/notebooks/training
echo " done."
