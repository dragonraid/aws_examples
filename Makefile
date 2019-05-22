SHELL:=/bin/bash
AWS_REGION:=us-west-2
AWS_PROFILE:=aws_alpha
S3_BUCKET:=alpha-cf-bucket
BASTION_KEY:=alpha_bastion
WEBAPP_KEY:=alpha_webapp

EXEC:=.venv/bin/python3 scripts/cloudformation.py -p $(AWS_PROFILE) -r $(AWS_REGION)

venv: venv/bin/activate
venv/bin/activate: requirements.txt
	@echo 'Updating python virtualenv...'
	@test -d .venv || virtualenv -p python3 .venv
	@.venv/bin/pip install -qUr requirements.txt
	@touch .venv/bin/activate

infra: venv
	@$(EXEC) package -t cloudformation/infrastructure.yaml -b $(S3_BUCKET)
	@$(EXEC) create-key-pair -k $(BASTION_KEY)
	@$(EXEC) launch-stack -s infra -t pkg_infrastructure.yaml -P cloudformation/infrastructureParameters.json
	@$(EXEC) get-bastions-endpoints -k $(BASTION_KEY)

clean_infra: venv
	@$(EXEC) delete-stack -s infra
	@$(EXEC) delete-key-pair -k $(BASTION_KEY)

webapp: venv
	@$(EXEC) create-key-pair -k $(WEBAPP_KEY)
	@$(EXEC) launch-stack -s webapp -t cloudformation/webapp.yaml -P cloudformation/webappParameters.json

clean_webapp: venv
	@$(EXEC) delete-stack -s webapp
	@$(EXEC) delete-key-pair -k $(WEBAPP_KEY)

debug:
	@$(EXEC) get-bastions-endpoints -k $(BASTION_KEY)