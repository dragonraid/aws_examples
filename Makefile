AWS_REGION:=us-west-2
AWS_PROFILE:=aws_alpha
S3_BUCKET:=alpha-cf-bucket
BASTION_KEY:=alpha_bastion

infra:
	aws ec2 create-key-pair --key-name $(BASTION_KEY) --query 'KeyMaterial' --output text --profile $(AWS_PROFILE) --region $(AWS_REGION) > $(BASTION_KEY).pem
	chmod 400 $(BASTION_KEY).pem
	aws cloudformation package --template-file cloudformation/infrastructure.yaml --s3-bucket $(S3_BUCKET) --output-template-file pkg_infrastructure.yaml --profile $(AWS_PROFILE) --region $(AWS_REGION)
	aws cloudformation deploy --template-file pkg_infrastructure.yaml --stack-name infrastructure --profile $(AWS_PROFILE) --region $(AWS_REGION)

clean_infra:
	aws cloudformation delete-stack --stack-name infrastructure --profile $(AWS_PROFILE) --region $(AWS_REGION)
	aws ec2 delete-key-pair --key-name $(BASTION_KEY) --profile $(AWS_PROFILE) --region $(AWS_REGION)
	chmod 700 $(BASTION_KEY).pem && rm -f $(BASTION_KEY).pem