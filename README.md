# AWS Examples
This repository contains AWS Examples. Individual directories contains examples to individual AWS Services.
## CloudFormation
- `infrastructure.yaml` ... nested stack that deploys basic infrastructure
  - `vpcSubnets.yaml`   ... creates vpc, private and public subnets
  - `vpcRouting.yaml`   ... sets up routing between subnets
  - `bastion.yaml`      ... creates bastion hosts in public subnet. Before creating this stack, make sure to create ssh key-pair and update `ImageId` if needed. (Replaced by `bastionV2.yaml`, because of EIPs limits per region.)
  - `bastionV2.yaml`    ... creates bastion hosts in public subnet
- `webapp.yaml` ... creates dummy web application.
## Deployment guide
### Prerequisites
- create IAM User and attach Administrator policy (for simplicity, not recommended in production environment). Create access key and secret access key and put into `./aws/credentials` file
- edit `Makefile` variables in order to reflect your environment
- install `python3` and `virtualenv`
### Makefile
Makefile simplifies deployment of Cloudformation templates. Available commands:
- `make infra`  ... creates basic AWS infrastructure (deploys `cloudformation/infrastructure.yaml`)
- `make webapp` ... create webapp stack (deploys `cloudformation/webapp.yaml`)
> All Makefile targets listed above have `clean_` counterpart (i.e. `clean_infra`) that deletes stack and its related resources.

Additionally `Makefile` provides `describe` target (usage `make describe`), that is describing relevant resources