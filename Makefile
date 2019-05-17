SHELL:=/bin/bash
AWS_REGION:=us-west-2
AWS_PROFILE:=aws_alpha
S3_BUCKET:=alpha-cf-bucket
BASTION_KEY:=alpha_bastion
WEBAPP_KEY:=alpha_webapp

bastion_filter:=Name=tag:Service,Values=bastion
dns_query:=Reservations[*].Instances[*].PublicDnsName

define create_ssh_key
	@if test -f $1.pem; then \
		echo "Key $1.pem already exists."; \
	else \
		aws ec2 create-key-pair --key-name $1 --query 'KeyMaterial' --output text --profile $(AWS_PROFILE) --region $(AWS_REGION) > $1.pem; \
		chmod 400 $1.pem; \
	fi
endef

define describe_ec2 
	@echo 'Bastions public DNS'
	@aws ec2 describe-instances --filter "$1" --query "$2" --profile $(AWS_PROFILE) --region $(AWS_REGION) --output text
endef

describe:
	$(call describe_ec2,$(bastion_filter),$(dns_query))

infra:
	$(call create_ssh_key,$(BASTION_KEY))
	aws cloudformation package --template-file cloudformation/infrastructure.yaml --s3-bucket $(S3_BUCKET) --output-template-file pkg_infrastructure.yaml --profile $(AWS_PROFILE) --region $(AWS_REGION)
	aws cloudformation deploy --template-file pkg_infrastructure.yaml --stack-name infrastructure --profile $(AWS_PROFILE) --region $(AWS_REGION)
	$(call describe_ec2,$(bastion_filter),$(dns_query))

clean_infra:
	aws cloudformation delete-stack --stack-name infrastructure --profile $(AWS_PROFILE) --region $(AWS_REGION)
	aws ec2 delete-key-pair --key-name $(BASTION_KEY) --profile $(AWS_PROFILE) --region $(AWS_REGION)
	chmod 700 $(BASTION_KEY).pem && rm -f $(BASTION_KEY).pem

webapp:
	$(call create_ssh_key,$(WEBAPP_KEY))
	aws cloudformation package --template-file cloudformation/webapp.yaml --s3-bucket $(S3_BUCKET) --output-template-file pkg_webapp.yaml --profile $(AWS_PROFILE) --region $(AWS_REGION)
	aws cloudformation deploy --template-file pkg_webapp.yaml --stack-name webapp --profile $(AWS_PROFILE) --region $(AWS_REGION)

clean_webapp:
	aws cloudformation delete-stack --stack-name webapp --profile $(AWS_PROFILE) --region $(AWS_REGION)
	aws ec2 delete-key-pair --key-name $(WEBAPP_KEY) --profile $(AWS_PROFILE) --region $(AWS_REGION)
	chmod 700 $(WEBAPP_KEY).pem && rm -f $(WEBAPP_KEY).pem
