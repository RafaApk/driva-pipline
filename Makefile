.PHONY: help up down logs logs-api logs-db logs-n8n restart build clean seed test frontend install

help:
	@echo "╔════════════════════════════════════════════════════════════╗"
	@echo "║  DRIVA PIPELINE - Makefile Commands                        ║"
	@echo "╚════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Docker & Serviços:"
	@echo "  make up              - Inicia todos os serviços"
	@echo "  make down            - Para todos os serviços"
	@echo "  make restart         - Reinicia todos os serviços"
	@echo "  make build           - Reconstrói imagens Docker"
	@echo "  make logs            - Mostra logs de todos os serviços"
	@echo "  make logs-api        - Logs da API Node.js"
	@echo "  make logs-db         - Logs do PostgreSQL"
	@echo "  make logs-n8n        - Logs do n8n"
	@echo ""
	@echo "Banco de Dados:"
	@echo "  make seed            - Popula dados de exemplo"
	@echo "  make db-shell        - Acessa terminal PostgreSQL"
	@echo "  make db-stats        - Mostra estatísticas do banco"
	@echo ""
	@echo "Frontend:"
	@echo "  make frontend        - Inicia dashboard React (porta 5173)"
	@echo "  make install         - Instala dependências Node.js"
	@echo ""
	@echo "Testes:"
	@echo "  make test            - Executa suite de testes da API"
	@echo "  make health          - Verifica saúde de todos os serviços"
	@echo ""
	@echo "Limpeza:"
	@echo "  make clean           - Para serviços e remove volumes"
	@echo "  make prune           - Remove containers, images e volumes não utilizados"
	@echo ""

up:
	docker-compose up -d
	@echo "✓ Serviços iniciados. Aguardando estabilização..."
	@sleep 5
	@docker-compose ps

down:
	docker-compose down
	@echo "✓ Serviços parados"

restart:
	docker-compose restart
	@echo "✓ Serviços reiniciados"

logs:
	docker-compose logs -f

logs-api:
	docker-compose logs -f api

logs-db:
	docker-compose logs -f postgres

logs-n8n:
	docker-compose logs -f n8n

build:
	docker-compose build --no-cache
	@echo "✓ Imagens reconstruídas"

clean:
	docker-compose down -v
	@echo "✓ Containers e volumes removidos"

prune:
	docker system prune -af --volumes
	@echo "✓ Limpeza completa do Docker"

seed:
	@echo "Dados já são populados automaticamente no init.sql"
	@echo "Se quiser mais dados, rode:"
	@echo "  make db-shell"
	@echo "E execute INSERT statements no psql"

db-shell:
	docker-compose exec postgres psql -U driva_user -d driva_warehouse

db-stats:
	@docker-compose exec -T postgres psql -U driva_user -d driva_warehouse << EOF
	SELECT 
	  (SELECT COUNT(*) FROM bronze_enriquecimentos) as bronze_count,
	  (SELECT COUNT(*) FROM gold_enriquecimentos) as gold_count,
	  (SELECT COUNT(*) FROM workflow_logs) as logs_count;
	EOF

health:
	@echo "Verificando saúde dos serviços..."
	@echo ""
	@echo "PostgreSQL:"
	@docker-compose exec -T postgres pg_isready -U driva_user || echo "❌ Indisponível"
	@echo ""
	@echo "API:"
	@curl -s -H "Authorization: Bearer driva_test_key_abc123xyz789" http://localhost:3000/health | jq '.status' || echo "❌ Indisponível"
	@echo ""
	@echo "Docker Compose Status:"
	@docker-compose ps
	@echo ""

install:
	cd api && npm install
	cd ../frontend && npm install
	@echo "✓ Dependências instaladas"

frontend:
	@echo "Iniciando dashboard em http://localhost:5173"
	cd frontend && npm run dev

test:
	@bash test-api.sh

.DEFAULT_GOAL := help
