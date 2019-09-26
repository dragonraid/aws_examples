SHELL:=/bin/bash
CERTGEN:=scripts/certs.sh

ALPHA_AWS_REGION:=us-west-2
ALPHA_AWS_PROFILE:=aws_alpha
ALPHA_S3_BUCKET:=alpha-cfn-bucket
ALPHA_BASTION_KEY:=alpha_bastion
ALPHA_WEBAPP_KEY:=alpha_webapp

BETA_AWS_REGION:=us-west-2
BETA_AWS_PROFILE:=aws_beta
BETA_S3_BUCKET:=beta-cfn-bucket
BETA_BASTION_KEY:=beta_bastion
BETA_WEBAPP_KEY:=beta_webapp

ALPHA_EXEC:=scripts/cloudformation.sh -P $(ALPHA_AWS_PROFILE) -R $(ALPHA_AWS_REGION) -B $(ALPHA_S3_BUCKET)
BETA_EXEC:=scripts/cloudformation.sh -P $(BETA_AWS_PROFILE) -R $(BETA_AWS_REGION) -B $(BETA_S3_BUCKET)

infra:
	@$(ALPHA_EXEC) launch -p -n infrastructure -t services/vpc/infrastructure.yaml -r services/vpc/infraParamAlpha.json

clean_infra: 
	@$(ALPHA_EXEC) delete -n infrastructure

webapp:
	@$(CERTGEN) $(ALPHA_AWS_REGION) $(ALPHA_AWS_PROFILE) create 
	@$(ALPHA_EXEC) launch -n webapp -t services/ec2/webapp.yaml -r services/ec2/webappParameters.json -c CAPABILITY_NAMED_IAM

clean_webapp: 
	@$(ALPHA_EXEC) delete -n webapp 
	@$(CERTGEN) $(ALPHA_AWS_REGION) $(ALPHA_AWS_PROFILE) delete