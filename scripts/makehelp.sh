# =========[ Makefile GitOps helper ]=========
# Prérequis: kubectl, flux (CLI), git, (optionnel) gh, kubeconform
# Modifie les variables si besoin.
SHELL := /usr/bin/env bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

# --- Config générale ---
KUBECTL ?= kubectl
FLUX    ?= flux
GH      ?= gh
KUSTOMIZE ?= kustomize

# Dossier kustomize par défaut (sur lequel opèrent diff/dry-run)
DIR ?= apps/whoami

# Kustomizations Flux (adaptées à ton setup)
FLUX_NS ?= flux-system
KZ_APPS ?= apps
KZ_ING  ?= ingress-nginx
KZ_ROOT ?= lab-root

# Branches Git
BASE_BRANCH ?= main
AUTO_UPDATE_BRANCH ?= flux-imageupdates

# --------------------------------------------
.DEFAULT_GOAL := help
.PHONY: help diff dry-run dry-run-client dry-run-server render validate \
        flux-reconcile flux-annotate flux-build \
        pr-open pr-workflow pr-clean \
        tools-kustomize tools-kubeconform tools-all

help: ## Affiche cette aide
	@awk 'BEGIN{FS=":.*?## "; printf "\n\033[1mCibles disponibles\033[0m\n\n"} /^[a-zA-Z0-9_.-]+:.*?## /{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Variables utiles: DIR=$(DIR), FLUX_NS=$(FLUX_NS), AUTO_UPDATE_BRANCH=$(AUTO_UPDATE_BRANCH)"
	@echo "Exemples:"
	@echo "  make diff DIR=apps/whoami"
	@echo "  make flux-reconcile"
	@echo "  make pr-open (nécessite 'gh')"
	@echo

# ---------- Kustomize / kubectl ----------
diff: ## Affiche le diff entre le cluster et le rendu Kustomize (kubectl diff)
	$(KUBECTL) diff -k $(DIR) || true

dry-run: dry-run-server ## Dry-run server (par défaut)

dry-run-client: ## kubectl apply --dry-run=client -k $(DIR)
	$(KUBECTL) apply --dry-run=client -k $(DIR)

dry-run-server: ## kubectl apply --dry-run=server -k $(DIR)
	$(KUBECTL) apply --dry-run=server -k $(DIR)

render: ## kustomize build $(DIR) (rendu local)
	$(KUSTOMIZE) build $(DIR)

validate: ## kustomize build | kubeconform (si installé)
	@if command -v kubeconform >/dev/null 2>&1; then \
	  echo ">> Validating $(DIR)"; \
	  $(KUSTOMIZE) build $(DIR) | kubeconform -strict -ignore-missing-schemas -summary; \
	else \
	  echo "kubeconform non trouvé, skip validation. (make tools-kubeconform pour l’installer)"; \
	fi

# ---------- Flux ----------
flux-reconcile: ## Reconcile source + toutes les Kustomizations (avec source)
	@echo ">> Reconcile GitRepository 'gitops' (namespace $(FLUX_NS))"
	$(FLUX) reconcile source git gitops -n $(FLUX_NS)
	@echo ">> Reconcile Kustomizations"
	$(KUBECTL) get kustomization -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
	| while read ns name; do \
	    echo " - $$ns/$$name"; \
	    $(FLUX) reconcile kustomization $$name -n $$ns --with-source || exit $$?; \
	  done
	@echo
	$(FLUX) get kustomizations -A

flux-annotate: ## Force un run de l'ImageUpdateAutomation (bump auto) via annotation
	@echo ">> Annotate ImageUpdateAutomation whoami-update (namespace $(FLUX_NS))"
	$(KUBECTL) -n $(FLUX_NS) annotate imageupdateautomation whoami-update \
	  reconcile.fluxcd.io/requestedAt="$$(date +%s)" --overwrite

flux-build: ## Affiche le rendu que Flux appliquerait pour KZ=$(KZ_APPS) (ou KZ=name)
	@KZ_NAME=$${KZ:-$(KZ_APPS)}; \
	echo ">> flux build kustomization $$KZ_NAME -n $(FLUX_NS)"; \
	$(FLUX) build kustomization $$KZ_NAME -n $(FLUX_NS)

# ---------- Pull Requests ----------
pr-open: ## Ouvre une PR depuis $(AUTO_UPDATE_BRANCH) -> $(BASE_BRANCH) (utilise gh). Idempotent.
	@if ! command -v $(GH) >/dev/null 2>&1; then \
	  echo "'gh' n'est pas installé. Installe GitHub CLI ou utilise 'pr-workflow'."; exit 1; \
	fi
	@echo ">> Vérification commits ahead sur origin/$(AUTO_UPDATE_BRANCH) vs origin/$(BASE_BRANCH)"
	git fetch origin
	AHEAD=$$(git rev-list --count origin/$(BASE_BRANCH)..origin/$(AUTO_UPDATE_BRANCH) || echo 0); \
	echo "Commits ahead: $$AHEAD"; \
	if [ "$$AHEAD" -eq 0 ]; then \
	  echo "Aucun commit en avance → rien à PR. (Utilise 'flux-annotate' pour relancer Flux)"; \
	  exit 0; \
	fi
	@echo ">> Création/MAJ PR (gh pr create)..."
	if $(GH) pr list --head $(AUTO_UPDATE_BRANCH) --base $(BASE_BRANCH) --state all --json number,state -q '.[0]' >/dev/null 2>&1; then \
	  PR=$$($(GH) pr list --head $(AUTO_UPDATE_BRANCH) --base $(BASE_BRANCH) --state all --json number,state -q '.[0].number'); \
	  STATE=$$($(GH) pr view $$PR --json state -q .state); \
	  if [ "$$STATE" = "CLOSED" ]; then $(GH) pr reopen $$PR; fi; \
	  $(GH) pr view $$PR --json url -q .url; \
	else \
	  $(GH) pr create --head $(AUTO_UPDATE_BRANCH) --base $(BASE_BRANCH) \
	    --title "chore(images): updates from Flux" \
	    --body "PR auto depuis \`$(AUTO_UPDATE_BRANCH)\`" || true; \
	  $(GH) pr list --head $(AUTO_UPDATE_BRANCH) --base $(BASE_BRANCH) --state open --json url -q '.[0].url'; \
	fi

pr-workflow: ## Déclenche le workflow auto-PR (workflow_dispatch) avec head_branch=$(AUTO_UPDATE_BRANCH)
	@if ! command -v $(GH) >/dev/null 2>&1; then \
	  echo "'gh' n'est pas installé."; exit 1; \
	fi
	@WF=$$(basename .github/workflows/auto-pr-from-flux.yml); \
	echo ">> gh workflow run $$WF -f head_branch=$(AUTO_UPDATE_BRANCH)"; \
	$(GH) workflow run $$WF -f head_branch=$(AUTO_UPDATE_BRANCH) || true; \
	echo ">> Attends quelques secondes puis: gh run list --limit 5 && gh run watch <run-id>"

pr-clean: ## Supprime les branches 'flux-imageupdates-*' sur le remote (ménage)
	git fetch origin
	for b in $$(git branch -r | grep 'origin/$(AUTO_UPDATE_BRANCH)-' | sed 's|origin/||'); do \
	  echo "Deleting $$b"; \
	  git push origin :$$b; \
	done

# ---------- Install outils (direct URL) ----------
tools-all: tools-kustomize tools-kubeconform ## Installe kustomize + kubeconform

tools-kustomize: ## Installe kustomize (direct URL)
	@set -euo pipefail
	KVER="v5.4.2"
	OS=$$(uname -s | tr '[:upper:]' '[:lower:]')   # linux|darwin
	ARCH_RAW=$$(uname -m)
	case "$$ARCH_RAW" in x86_64|amd64) ARCH="amd64" ;; arm64|aarch64) ARCH="arm64" ;; *) echo "Unsupported arch: $$ARCH_RAW"; exit 1 ;; esac
	BASE="https://github.com/kubernetes-sigs/kustomize/releases/download"
	TAG="kustomize%2F$$KVER"
	ASSET="kustomize_$${KVER#v}_$${OS}_$${ARCH}.tar.gz"
	URL="$$BASE/$$TAG/$$ASSET"
	echo "Downloading $$URL"
	curl -fSL "$$URL" -o kustomize.tgz
	test -s kustomize.tgz
	file kustomize.tgz | grep -qi 'gzip compressed data'
	tar -xzf kustomize.tgz
	sudo mv kustomize /usr/local/bin/kustomize
	kustomize version

tools-kubeconform: ## Installe kubeconform (direct URL)
	@set -euo pipefail
	KCONF_VER="v0.6.7"
	case "$$(uname -s)" in Linux) OS="linux" ;; Darwin) OS="darwin" ;; *) echo "Unsupported OS"; exit 1 ;; esac
	case "$$(uname -m)" in x86_64|amd64) ARCH="amd64" ;; arm64|aarch64) ARCH="arm64" ;; *) echo "Unsupported arch"; exit 1 ;; esac
	ASSET="kubeconform-$${OS}-$${ARCH}.tar.gz"
	URL="https://github.com/yannh/kubeconform/releases/download/$${KCONF_VER}/$${ASSET}"
	echo "Downloading $$URL"
	curl -fSL "$$URL" -o kubeconform.tgz
	test -s kubeconform.tgz
	file kubeconform.tgz | grep -qi 'gzip compressed data'
	tar -xzf kubeconform.tgz kubeconform
	sudo mv kubeconform /usr/local/bin/kubeconform
	kubeconform -v
# ===============================================

