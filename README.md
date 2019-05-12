# AWS Examples
This repository contains AWS Examples. Individual directories contains examples to individual AWS Services.
## CloudFormation
- `infrastructure.yaml` ... nested stack that deploys basic infrastructure
  - `vpc.yaml`          ... creates vpc 
  - `subnets.yaml`      ... creates public and private subnets 
  - `routing.yaml`      ... sets up routing between subnets
  - `bastion.yaml`      ... creates bastion hosts in public subnet. Before creating this stack, make sure to create ssh key-pair and update `ImageId` if needed.
- `webapp.yaml` ... creates dummy web application.
## Deployment guide
Use `awscli` to deploy CloudFormation stacks. See install guide [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).
### Prerequisites
- create IAM User and attach Administrator policy (for simplicity, not recommended in production environment). Create access key and secret access key and put into `./aws/credentials` file
- edit `Makefile` variables in order to reflect your environment:
### Makefile
Makefile simplifies deployment of Cloudformation templates. Available commands
- `make infra`  ... creates basic AWS infrastructure
- `make webapp` ... create webapp stack
All sections have `clean_` counterpart (i.e. `clean_infra`) that deletes stack and its related resources