.PHONY: up down stop start restart logs health status root-password create-token reset

ENV_FILE ?= .env
HTTP_PORT ?= $(shell grep -E '^GITLAB_HTTP_PORT=' $(ENV_FILE) 2>/dev/null | cut -d= -f2)
ifeq ($(HTTP_PORT),)
	HTTP_PORT := 8929
endif

EXTERNAL_URL ?= $(shell grep -E '^GITLAB_EXTERNAL_URL=' $(ENV_FILE) 2>/dev/null | cut -d= -f2)
ifeq ($(EXTERNAL_URL),)
	EXTERNAL_URL := http://localhost:$(HTTP_PORT)
endif

## Start GitLab container and wait until healthy
up:
	@if [ ! -f .env ]; then \
		echo "ℹ️  No .env file found. Creating from .env.example..."; \
		cp .env.example .env; \
	fi
	docker compose up -d
	@echo "⏳ Waiting for GitLab to be ready at $(EXTERNAL_URL) ..."
	@echo "   (Note: GitLab takes 2-4 minutes on first start for database migrations and Puma initialization)"
	@for i in $$(seq 1 60); do \
		if curl -sf -k $(EXTERNAL_URL)/users/sign_in > /dev/null 2>&1; then \
			echo "✅ GitLab is ready at $(EXTERNAL_URL)"; \
			echo "👉 Retrieve initial root password: make root-password"; \
			exit 0; \
		fi; \
		echo "   ... waiting ($$i/60 - $$(($$i * 5))s)"; \
		sleep 5; \
	done; \
	echo "⚠️  GitLab did not report healthy yet. It may still be initializing. Run 'make logs' to monitor progress."

## Stop the GitLab container (keeps data intact)
down:
	docker compose down

## Pause the container
stop:
	docker compose stop

## Resume the container
start:
	docker compose start

## Restart the container
restart:
	docker compose restart

## Show container status
status:
	docker compose ps

## Tail logs (Ctrl-C to exit)
logs:
	docker compose logs -f

## Check if the instance is responding
health:
	@echo "Checking $(EXTERNAL_URL)/users/sign_in ..."
	@if curl -sf -k $(EXTERNAL_URL)/users/sign_in > /dev/null 2>&1; then \
		echo "✅ GitLab is healthy and responding"; \
	else \
		echo "❌ GitLab is not responding yet. Run 'make status' or 'make logs'."; \
		exit 1; \
	fi


## Display the initial root password (valid for 24 hours after container creation)
root-password:
	@echo "Fetching initial root password from container..."
	@docker compose exec gitlab grep 'Password:' /etc/gitlab/initial_root_password 2>/dev/null || \
		(echo "❌ Could not read /etc/gitlab/initial_root_password. Either GitLab is still booting or password file expired." && exit 1)

## Create a test Personal Access Token for the root user
create-token:
	@echo "Generating root Personal Access Token 'fox-local-dev'..."
	@docker compose exec gitlab gitlab-rails runner "\
		user = User.find_by_username('root'); \
		token = user.personal_access_tokens.create(scopes: ['api', 'read_user', 'read_repository', 'write_repository'], name: 'fox-local-dev', expires_at: 1.year.from_now); \
		token.set_token('glpat-fox-local-dev-token-12345'); \
		token.save!; \
		puts 'Personal Access Token created: ' + token.token" || \
		(echo "❌ Failed to create token. Is GitLab running?" && exit 1)

## Destroy container and reset all persistent volumes (CAUTION: deletes all data)
reset:
	@echo "⚠️  This will permanently delete all GitLab data, repos, and settings."
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || (echo "Aborted." && exit 1)
	docker compose down -v
