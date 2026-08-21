#!/usr/bin/env makefile
.PHONY: help bootstrap deploy update review status logs clean restart shell backup

help: ## Show this help
	@echo "🥧 Raspberry Pi Gateway - Available Commands"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

bootstrap: ## Bootstrap Pi (run once after fresh OS install)
	@echo "🥧 Bootstrapping Pi gateway..."
	ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --vault-id vault@prompt

deploy: ## Deploy full gateway stack (idempotent)
	@echo "🥧 Deploying gateway..."
	ansible-playbook -i inventory/hosts.yml playbooks/deploy_gateway.yml --vault-id vault@prompt

update: ## Update all containers (pull + recreate)
	@echo "🥧 Updating containers..."
	ansible-playbook -i inventory/hosts.yml playbooks/update_gateway.yml --vault-id vault@prompt

review: ## Generate status report
	@echo "🥧 Reviewing gateway state..."
	ansible-playbook -i inventory/hosts.yml playbooks/review_gateway.yml --vault-id vault@prompt

status: ## Quick container status
	@echo "🥧 Checking status..."
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

logs: ## Tail logs from all containers
	@echo "🥧 Tailing logs..."
	@docker logs -f --tail 50 $$(docker ps -q)

clean: ## Stop and remove all containers (data preserved)
	@echo "🥧 Cleaning up containers..."
	@cd /opt/pi-gateway && docker compose down

restart: ## Restart all services
	@echo "🥧 Restarting services..."
	@cd /opt/pi-gateway && docker compose restart

shell: ## Open shell in running container
	@if [ -z "$(CONTAINER)" ]; then echo "Usage: make shell CONTAINER=<name>"; exit 1; fi
	@docker exec -it $(CONTAINER) /bin/bash

backup: ## Backup Docker volumes
	@echo "🥧 Creating backup..."
	@tar -czf /tmp/pi-gateway-backup-$$(date +%Y%m%d).tar.gz -C /opt/pi-gateway pihole/etc grafana/data prometheus/data uptime/data
