#!/bin/bash

set -eo pipefail

# Terraform
brew install terraform || brew upgrade terraform

# Spark
brew install apache-spark || brew upgrade apache-spark
