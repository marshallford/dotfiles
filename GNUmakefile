default: lint

DOCKER_FLAGS += --rm
ifeq ($(shell tty > /dev/null && echo 1 || echo 0), 1)
DOCKER_FLAGS += -i
endif

DOCKER := docker
DOCKER_RUN := $(DOCKER) run $(DOCKER_FLAGS)
DOCKER_PULL := $(DOCKER) pull -q

EDITORCONFIG_CHECKER_VERSION ?= 3.6.1
EDITORCONFIG_CHECKER_IMAGE ?= docker.io/mstruebing/editorconfig-checker:v$(EDITORCONFIG_CHECKER_VERSION)
EDITORCONFIG_CHECKER := $(DOCKER_RUN) -v=$(CURDIR):/check $(EDITORCONFIG_CHECKER_IMAGE)

SHELLCHECK_VERSION ?= 0.11.0
SHELLCHECK_IMAGE ?= docker.io/koalaman/shellcheck:v$(SHELLCHECK_VERSION)
SHELLCHECK := $(DOCKER_RUN) -v=$(CURDIR):/mnt $(SHELLCHECK_IMAGE)

YAMLLINT_VERSION ?= 0.35.9
YAMLLINT_IMAGE ?= docker.io/pipelinecomponents/yamllint:$(YAMLLINT_VERSION)
YAMLLINT := $(DOCKER_RUN) -v=$(CURDIR):/code $(YAMLLINT_IMAGE) yamllint

.PHONY: pull pull/editorconfig pull/shellcheck pull/yamllint
pull: pull/editorconfig pull/shellcheck pull/yamllint

pull/editorconfig:
	$(DOCKER_PULL) $(EDITORCONFIG_CHECKER_IMAGE)

pull/shellcheck:
	$(DOCKER_PULL) $(SHELLCHECK_IMAGE)

pull/yamllint:
	$(DOCKER_PULL) $(YAMLLINT_IMAGE)

.PHONY: lint lint/editorconfig lint/shellcheck lint/yamllint
lint: lint/editorconfig lint/shellcheck lint/yamllint

lint/editorconfig:
	$(EDITORCONFIG_CHECKER)

lint/shellcheck:
	$(SHELLCHECK) $(shell grep -rlI '^#!' --exclude-dir=.git .)

lint/yamllint:
	$(YAMLLINT) .
