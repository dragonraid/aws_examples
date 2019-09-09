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

ALPHA_EXEC:=.venv/bin/python3 scripts/cloudformation.py -p $(ALPHA_AWS_PROFILE) -r $(ALPHA_AWS_REGION)
BETA_EXEC:=.venv/bin/python3 scripts/cloudformation.py -p $(BETA_AWS_PROFILE) -r $(BETA_AWS_REGION)

venv: venv/bin/activate
venv/bin/activate: requirements.txt
	@echo 'Updating python virtualenv...'
	@test -d .venv || virtualenv -p python3 .venv
	@.venv/bin/pip install -qUr requirements.txt
	@touch .venv/bin/activate

infra: venv
	@$(ALPHA_EXEC) package -t services/vpc/infrastructure.yaml -b $(ALPHA_S3_BUCKET)
	@$(ALPHA_EXEC) create-key-pair -k $(ALPHA_BASTION_KEY)
	@$(ALPHA_EXEC) launch-stack -s infra -t pkg_infrastructure.yaml -P services/vpc/infraParamAlpha.json
	@$(ALPHA_EXEC) get-bastions-endpoints -k $(ALPHA_BASTION_KEY)

clean_infra: venv
	@$(ALPHA_EXEC) delete-stack -s infra
	@$(ALPHA_EXEC) delete-key-pair -k $(ALPHA_BASTION_KEY)

webapp: venv
	@$(CERTGEN) $(ALPHA_AWS_REGION) $(ALPHA_AWS_PROFILE) create 
	@$(ALPHA_EXEC) create-key-pair -k $(ALPHA_WEBAPP_KEY)
	@$(ALPHA_EXEC) launch-stack -r -s webapp -t services/ec2/webapp.yaml -P services/ec2/webappParameters.json -c "CAPABILITY_NAMED_IAM"

clean_webapp: venv
	@$(ALPHA_EXEC) delete-stack -s webapp
	@$(ALPHA_EXEC) delete-key-pair -k $(ALPHA_WEBAPP_KEY)
	@$(CERTGEN) $(ALPHA_AWS_REGION) $(ALPHA_AWS_PROFILE) delete

describe:
	@$(ALPHA_EXEC) get-bastions-endpoints -k $(ALPHA_BASTION_KEY)

beta_infra: venv
	@$(BETA_EXEC) package -t services/vpc/infrastructure.yaml -b $(BETA_S3_BUCKET)
	@$(BETA_EXEC) create-key-pair -k $(BETA_BASTION_KEY)
	@$(BETA_EXEC) launch-stack -s infra -t pkg_infrastructure.yaml -P services/vpc/infraParamBeta.json
	@$(BETA_EXEC) get-bastions-endpoints -k $(BETA_BASTION_KEY)

beta_clean_infra: venv
	@$(BETA_EXEC) delete-stack -s infra
	@$(BETA_EXEC) delete-key-pair -k $(BETA_BASTION_KEY)

beta_describe:
	@$(BETA_EXEC) get-bastions-endpoints -k $(BETA_BASTION_KEY)