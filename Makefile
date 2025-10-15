# Paths to tools needed in dependencies
TERRAFORM := $(shell which terraform 2>/dev/null)

# AWS configuration
AWS_REGION ?= eu-central-1
ENV ?= dev
TEAM ?= fabric
SERVICE ?= sqs

###############################################################################
# TERRAFORM

.PHONY: tfstate
tfstate: terraform-dep
	@echo terraform init state
	@${TERRAFORM} -chdir=tf/workspaces/state init

	@echo terraform apply state
	@${TERRAFORM} -chdir=tf/workspaces/state apply \
		-var aws_region=${AWS_REGION} \
		-var env=${ENV} \
		-var team=${TEAM} \
		-var service=${SERVICE} \
		-var tfstate=${TEAM}-${ENV}-tfstate \
		-auto-approve \
		-input=false \

.PHONY: tfplan
tfplan: terraform-dep
	@echo terraform init root
	@${TERRAFORM} -chdir=tf/workspaces/root init \
		-backend-config="region=${AWS_REGION}" \
		-backend-config="bucket=${TEAM}-${ENV}-tfstate" \
		-backend-config="key=${TEAM}-${ENV}-tfstate/terraform.tfstate" \
		-upgrade

	@echo terraform plan root
	@${TERRAFORM} -chdir=tf/workspaces/root plan \
		-var aws_region=${AWS_REGION} \
		-var env=${ENV} \
		-var team=${TEAM} \
		-var service=root \
		-input=false

.PHONY: tfapply
tfapply: terraform-dep
	@echo terraform init root
	@${TERRAFORM} -chdir=tf/workspaces/root init \
		-backend-config="region=${AWS_REGION}" \
		-backend-config="bucket=${TEAM}-${ENV}-tfstate" \
		-backend-config="key=${TEAM}-${ENV}-tfstate/terraform.tfstate" \
		-upgrade

	@echo terraform apply root
	@${TERRAFORM} -chdir=tf/workspaces/root apply \
		-var aws_region=${AWS_REGION} \
		-var env=${ENV} \
		-var team=${TEAM} \
		-var service=root \
		-input=false \
		-auto-approve

###############################################################################
# GO COMMANDS

.PHONY: build-publish
build-publish:
	@echo "Building publish command..."
	@go build -o bin/publish ./cmd/publish

.PHONY: build-subscribe
build-subscribe:
	@echo "Building subscribe command..."
	@go build -o bin/subscribe ./cmd/subscribe

.PHONY: build
build: build-publish build-subscribe

.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf bin/

###############################################################################
# DEPENDENCIES

.PHONY: terraform-dep
terraform-dep:
	@test -f "${TERRAFORM}" && test -x "${TERRAFORM}"  || (echo "Missing terraform binary" && exit 1)
