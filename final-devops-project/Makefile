# SpendWise - one-command shortcuts for the whole project. Run from final-devops-project/.
#   make help
# The CI pipeline runs the same tools with the same versions (.github/workflows/final-devops-project.yml).

SHELL        := /bin/bash
NAMESPACE    ?= spendwise
TRIVY        ?= aquasec/trivy:0.74.0
GITLEAKS     ?= zricethezav/gitleaks:v8.30.1
VENV         ?= .venv
PY           := $(VENV)/bin

.DEFAULT_GOAL := help
.PHONY: help venv test frontend-build scan scan-iac compose-up compose-down images deploy-helm \
        monitoring argocd gitops mode-gitops mode-monitoring port-forward tf-check status clean

help: ## List the targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-15s %s\n", $$1, $$2}'

venv: $(PY)/pytest ## Create the Python virtualenv for the backend
$(PY)/pytest: backend/requirements-dev.txt
	python3 -m venv $(VENV) && $(PY)/pip install -q -r backend/requirements-dev.txt
	@touch $@

test: venv ## Lint and test the backend (SQLite test database), like the CI job
	cd backend && ../$(PY)/ruff check . && ../$(PY)/pytest --cov=app --cov-report=term-missing

frontend-build: ## npm ci + production build of the React app
	cd frontend && npm ci --no-audit --no-fund && npm run build

scan: ## Secret scan + dependency scans + IaC scan (same tools as CI)
	docker run --rm -v "$$PWD:/src" $(GITLEAKS) dir /src --config /src/security/gitleaks.toml --redact --exit-code 1
	for dir in backend frontend; do docker run --rm -v "$$PWD:/src" -w /src $(TRIVY) fs --config security/trivy.yaml --format table $$dir || exit 1; done
	$(MAKE) scan-iac

scan-iac: ## Trivy misconfiguration scan of Terraform and the rendered Helm chart
	docker run --rm -v "$$PWD:/src" -w /src $(TRIVY) config --quiet --severity HIGH,CRITICAL \
	  --ignorefile security/trivyignore-iac --exit-code 1 terraform
	docker run --rm -v "$$PWD:/src" -w /src $(TRIVY) config --quiet --severity HIGH,CRITICAL \
	  --helm-set backend.image.tag=scan,frontend.image.tag=scan --exit-code 1 helm/spendwise

compose-up: ## Run the stack with Docker Compose on http://localhost:3000 (creates .env once)
	@test -f .env || sed "s/change-me/$$(openssl rand -hex 16)/" .env.example > .env
	docker compose up --build --detach
	docker compose ps

compose-down: ## Stop Docker Compose and delete its volume
	docker compose down --volumes

images: ## Build both images locally and load them into Minikube (tag "local")
	docker compose build
	minikube image load spendwise-backend:local
	minikube image load spendwise-frontend:local

deploy-helm: ## Install/upgrade the chart by hand with values-local.yaml (skip this when Argo CD manages the namespace)
	kubectl apply -f k8s/namespace.yaml
	bash k8s/create-db-secret.sh $(NAMESPACE)
	helm upgrade --install spendwise helm/spendwise -n $(NAMESPACE) -f helm/spendwise/values-local.yaml --wait --timeout 6m
	helm test spendwise -n $(NAMESPACE) --logs

monitoring: ## Install kube-prometheus-stack (Prometheus, Alertmanager, Grafana) into "monitoring"
	kubectl get namespace monitoring >/dev/null 2>&1 || kubectl create namespace monitoring
	kubectl -n monitoring get secret grafana-admin >/dev/null 2>&1 || kubectl -n monitoring create secret generic grafana-admin \
	  --from-literal=admin-user=admin --from-literal=admin-password="$$(openssl rand -hex 12)"
	helm upgrade --install kps prometheus-community/kube-prometheus-stack -n monitoring \
	  -f monitoring/kube-prometheus-stack-values.yaml --wait --timeout 15m

argocd: ## Install Argo CD into "argocd"
	helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace -f gitops/argocd-values.yaml --wait --timeout 10m

gitops: ## Hand the namespace to Argo CD: remove a hand-run Helm release (the PVC keeps the data), apply the Application
	kubectl apply -f k8s/namespace.yaml
	bash k8s/create-db-secret.sh $(NAMESPACE)
	-helm uninstall spendwise -n $(NAMESPACE) --wait
	kubectl apply -f gitops/argocd-application.yaml
	@echo "Watch it: kubectl -n argocd get applications.argoproj.io spendwise -w"

# An 8 GB laptop gives Minikube about 3.4 GB: run Argo CD or the monitoring stack, not both at full size.
mode-gitops: ## Laptop mode for the GitOps demo: Argo CD on, Prometheus/Alertmanager/Grafana and demo traffic paused
	kubectl -n monitoring patch prometheus kps-kube-prometheus-stack-prometheus --type merge -p '{"spec":{"replicas":0}}'
	kubectl -n monitoring patch alertmanager kps-kube-prometheus-stack-alertmanager --type merge -p '{"spec":{"replicas":0}}'
	kubectl -n monitoring scale deploy/kps-grafana --replicas=0
	-kubectl -n $(NAMESPACE) scale deploy/spendwise-traffic --replicas=0
	kubectl -n argocd scale statefulset/argocd-application-controller deploy/argocd-repo-server deploy/argocd-server --replicas=1

mode-monitoring: ## Laptop mode for the monitoring demo: Prometheus, Alertmanager, Grafana and demo traffic on, Argo CD paused
	kubectl -n argocd scale statefulset/argocd-application-controller deploy/argocd-repo-server deploy/argocd-server --replicas=0
	kubectl -n monitoring patch prometheus kps-kube-prometheus-stack-prometheus --type merge -p '{"spec":{"replicas":1}}'
	kubectl -n monitoring patch alertmanager kps-kube-prometheus-stack-alertmanager --type merge -p '{"spec":{"replicas":1}}'
	kubectl -n monitoring scale deploy/kps-grafana --replicas=1
	-kubectl apply -f monitoring/traffic-generator.yaml && kubectl -n $(NAMESPACE) scale deploy/spendwise-traffic --replicas=1

port-forward: ## Ingress :18080, Argo CD :8081, Prometheus :9090, Grafana :3000 (Ctrl+C stops them)
	@echo "App http://spendwise.local:18080 (add '127.0.0.1 spendwise.local' to /etc/hosts) | Argo CD http://localhost:8081 | Prometheus http://localhost:9090 | Grafana http://localhost:3000"
	@trap 'kill 0' INT TERM; \
	kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 18080:80 >/dev/null & \
	kubectl -n argocd port-forward svc/argocd-server 8081:80 >/dev/null & \
	kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 >/dev/null & \
	kubectl -n monitoring port-forward svc/kps-grafana 3000:80 >/dev/null & \
	wait

tf-check: ## terraform fmt, init and validate (no AWS credentials needed)
	cd terraform && terraform fmt -check && terraform init -input=false -backend=false >/dev/null && terraform validate

status: ## What is running: Argo CD app, Pods, HPA, deployed images
	-kubectl -n argocd get applications.argoproj.io spendwise -o jsonpath='Argo CD: sync={.status.sync.status} health={.status.health.status} revision={.status.sync.revision}{"\n"}'
	kubectl get pods,hpa -n $(NAMESPACE)
	kubectl get deploy -n $(NAMESPACE) -o custom-columns='DEPLOYMENT:.metadata.name,IMAGE:.spec.template.spec.containers[0].image'

clean: ## Remove local build output and caches
	rm -rf $(VENV) frontend/dist frontend/node_modules
	find backend -name __pycache__ -o -name .pytest_cache -o -name .ruff_cache -o -name .coverage | xargs rm -rf
