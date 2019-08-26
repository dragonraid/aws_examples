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
- `make infra`  ... creates basic AWS infrastructure (deploys `cloudformation/infrastructure.yaml`)  in `alpha` account
- `make clean_infra` ... deletes basic AWS infrastructure in `alpha` accoint
- `make webapp` ... create webapp stack (deploys `cloudformation/webapp.yaml`)  in `alpha` account
- `make clean_webapp` ... deletes webapp stack in `alpha` account
- `make describe` ... describes bastions endpoint in `alpha` account
- `make beta_infra`  ... creates basic AWS infrastructure (deploys `cloudformation/infrastructure.yaml`) in `beta` account
- `make beta_clean_infra` ... deletes basic AWS infrastructure in `beta` accoint
- `make beta_describe` ... describes bastions endpoint in `beta` account

> NOTE: For deploying `webapp` stack, certificate must be created and uploaded either to ACM or IAM and referenced in SSM parameter store with `webappCertificate` key