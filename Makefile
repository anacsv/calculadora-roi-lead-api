NAMESPACE=ote

PROJECT_NAME = $(shell pwd | rev | cut -f1 -d'/' - | rev)

AWS_ACCOUNT_ID=$(shell aws sts get-caller-identity --query Account --output text)

CURRENT_VERSION=$(shell aws ecr describe-images --repository-name $(NAMESPACE)/$(PROJECT_NAME) \
		--region us-east-1 \
		--query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags' \
		|  grep -Eo '[0-9]{1,4}'| sort -rn |  head -1)

NEW_VERSION = $(shell expr $(CURRENT_VERSION) + 1 )

K8S_CONFIG_DIR = 'k8s'

clean: clean-eggs clean-build
	@find . -iname '*.pyc' -delete
	@find . -iname '*.pyo' -delete
	@find . -iname '*~' -delete
	@find . -iname '*.swp' -delete
	@find . -iname '__pycache__' -delete

clean-eggs:
	@find . -name '*.egg' -print0|xargs -0 rm -rf --
	@rm -rf .eggs/

clean-build:
	@rm -fr build/
	@rm -fr dist/
	@rm -fr *.egg-info

pip-install:
	poetry install

update-precommit:
	poetry run pre-commit autoupdate

lint:
	poetry run pre-commit install && poetry run pre-commit run -a -v

pyformat:
	black .

test:
	poetry run pytest -x -s roi

check-dead-fixtures:
	poetry run pytest --dead-fixtures

validate-envvars:
	poetry run pytest -x -s roi --validate-envvars

ecr-authenticate:
	aws ecr get-login-password \
		--region us-east-1 | docker login \
		--username AWS \
		--password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com

build-image:
	docker build -t $(PROJECT_NAME) . --build-arg \
POETRY_HTTP_BASIC_OLIST_USERNAME=$(POETRY_HTTP_BASIC_OLIST_USERNAME) --build-arg \
POETRY_HTTP_BASIC_OLIST_PASSWORD=$(POETRY_HTTP_BASIC_OLIST_PASSWORD)

tag-image:
	docker tag $(PROJECT_NAME):latest $(AWS_ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com/$(NAMESPACE)/$(PROJECT_NAME):v$(NEW_VERSION)

push-image:
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com/$(NAMESPACE)/$(PROJECT_NAME):v$(NEW_VERSION)

pull-image:
	@make ecr-authenticate
	docker pull $(AWS_ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com/$(NAMESPACE)/$(PROJECT_NAME):v$(CURRENT_VERSION)

validate-k8s-config:
	kubeval --skip-kinds ExternalSecret --strict -d $(K8S_CONFIG_DIR)

build-push-image:
	@make ecr-authenticate
	@make build-image
	@make tag-image
	@make push-image

check:
	kubectl exec -it $(shell kubectl get pods --field-selector status.phase=Running -l "app=$(PROJECT_NAME)" -n=$(NAMESPACE) -o jsonpath='{.items[0].metadata.name}') -n=$(NAMESPACE) -- roi/manage.py check --deploy

deploy-status:
	kubectl rollout status -w deployment/$(PROJECT_NAME) -n=$(NAMESPACE)

deploy:
	@make validate-k8s-config
	@make build-push-image
	kubectl apply -f $(K8S_CONFIG_DIR)/namespace.yml --record
	kubectl apply -f $(K8S_CONFIG_DIR)/auto-scale.yml --record
	kubectl apply -f $(K8S_CONFIG_DIR)/external-secrets.yml --record
	sed "s/{{VERSION}}/$(NEW_VERSION)/g" $(K8S_CONFIG_DIR)/deployment.yml | kubectl apply --record -f -
	kubectl apply -f $(K8S_CONFIG_DIR)/service.yml --record
	@make deploy-status
	@make check
	echo "deployed with success!"

rollback:
	kubectl rollout undo deployment/$(PROJECT_NAME) -n=$(NAMESPACE)

restart:
	kubectl rollout restart -f $(K8S_CONFIG_DIR)/deployment.yml
	@make deploy-status

logs:
	kubectl logs -f -l app=$(PROJECT_NAME) -n=$(NAMESPACE) -c $(PROJECT_NAME) --max-log-requests 100

logs-nginx:
	kubectl logs -f -l app=$(PROJECT_NAME) -n=$(NAMESPACE) -c roi-nginx --max-log-requests 100

bash:
	kubectl exec -it $(shell kubectl get pods --field-selector status.phase=Running -l "app=$(PROJECT_NAME)" -n=$(NAMESPACE) -o jsonpath='{.items[0].metadata.name}') -n=$(NAMESPACE) -- bash

bash-nginx:
	kubectl exec -it $(shell kubectl get pods --field-selector status.phase=Running -l "app=$(PROJECT_NAME)" -n=$(NAMESPACE) -o jsonpath='{.items[0].metadata.name}') -n=$(NAMESPACE) -c roi-nginx -- bash

show-envvars:
	kubectl exec $(shell kubectl get pods --field-selector status.phase=Running -l "app=$(PROJECT_NAME)" -n=$(NAMESPACE) -o jsonpath='{.items[0].metadata.name}') -n=$(NAMESPACE) -- env

pods-list:
	kubectl get pods -n $(NAMESPACE) --selector=app=$(PROJECT_NAME)

pods-info:
	kubectl top pod -n $(NAMESPACE) --selector=app=$(PROJECT_NAME)

deploy-history:
	kubectl rollout history deployment/$(PROJECT_NAME) -n=$(NAMESPACE)

shell:
	kubectl exec -it $(shell kubectl get pods --field-selector status.phase=Running -l "app=$(PROJECT_NAME)" -n=$(NAMESPACE) -o jsonpath='{.items[0].metadata.name}') -n=$(NAMESPACE) -- roi/manage.py shell_plus

migrate:
	kubectl exec -it $(shell kubectl get pods --field-selector status.phase=Running -l "app=$(PROJECT_NAME)" -n=$(NAMESPACE) -o jsonpath='{.items[0].metadata.name}') -n=$(NAMESPACE) -- roi/manage.py migrate

ocsim-list-permissions:
	heroku run -a olist-ocsim python ocsim/manage.py permissions search "roi"

info:
	kubectl get all -n=$(NAMESPACE)