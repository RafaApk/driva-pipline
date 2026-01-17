#!/bin/bash

# ╔════════════════════════════════════════════════════════════╗
# ║     DRIVA PIPELINE - CHECKLIST DE VALIDAÇÃO                ║
# ╚════════════════════════════════════════════════════════════╝

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     VALIDANDO ESTRUTURA DO PROJETO                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Cores
check_file() {
  if [ -f "$1" ]; then
    echo -e "${GREEN}✓${NC} $1"
    return 0
  else
    echo -e "${RED}✗${NC} $1 (FALTA)"
    return 1
  fi
}

check_dir() {
  if [ -d "$1" ]; then
    echo -e "${GREEN}✓${NC} $1/"
    return 0
  else
    echo -e "${RED}✗${NC} $1/ (FALTA)"
    return 1
  fi
}

# Contadores
total=0
ok=0

# Root files
echo -e "${BLUE}Arquivos Raiz:${NC}"
for file in docker-compose.yml README.md QUICKSTART.md N8N-SETUP.md API-EXAMPLES.md SUMMARY.md START.md Makefile .env.example .gitignore test-api.sh; do
  check_file "$file" && ((ok++)) || true
  ((total++))
done

echo ""
echo -e "${BLUE}Diretório DB:${NC}"
check_dir "db" && ((ok++)) || true
((total++))
check_file "db/init.sql" && ((ok++)) || true
((total++))

echo ""
echo -e "${BLUE}Diretório API:${NC}"
check_dir "api" && ((ok++)) || true
((total++))
check_file "api/Dockerfile" && ((ok++)) || true
((total++))
check_file "api/package.json" && ((ok++)) || true
((total++))
check_file "api/.env" && ((ok++)) || true
((total++))
check_dir "api/src" && ((ok++)) || true
((total++))
check_file "api/src/index.js" && ((ok++)) || true
((total++))
check_file "api/src/db.js" && ((ok++)) || true
((total++))

echo ""
echo -e "${BLUE}Diretório Frontend:${NC}"
check_dir "frontend" && ((ok++)) || true
((total++))
check_file "frontend/package.json" && ((ok++)) || true
((total++))
check_file "frontend/vite.config.js" && ((ok++)) || true
((total++))
check_file "frontend/index.html" && ((ok++)) || true
((total++))
check_dir "frontend/src" && ((ok++)) || true
((total++))
check_file "frontend/src/App.jsx" && ((ok++)) || true
((total++))
check_file "frontend/src/App.css" && ((ok++)) || true
((total++))
check_file "frontend/src/main.jsx" && ((ok++)) || true
((total++))
check_file "frontend/src/api.js" && ((ok++)) || true
((total++))

echo ""
echo -e "${BLUE}Diretório n8n-workflows:${NC}"
check_dir "n8n-workflows" && ((ok++)) || true
((total++))
check_file "n8n-workflows/1-ingestao-api-bronze.json" && ((ok++)) || true
((total++))
check_file "n8n-workflows/2-processamento-bronze-gold.json" && ((ok++)) || true
((total++))
check_file "n8n-workflows/3-orquestrador-5-minutos.json" && ((ok++)) || true
((total++))

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Resumo
percentage=$((ok * 100 / total))

if [ $percentage -eq 100 ]; then
  echo -e "${GREEN}✓ SUCESSO: $ok/$total arquivos encontrados (100%)${NC}"
  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║  ESTRUTURA DO PROJETO ESTÁ COMPLETA E PRONTA PARA USO!    ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "Próximos passos:"
  echo -e "  1. ${YELLOW}cd driva-pipline${NC}"
  echo -e "  2. ${YELLOW}docker-compose up -d${NC}"
  echo -e "  3. ${YELLOW}curl http://localhost:3000/health${NC}"
  echo -e "  4. ${YELLOW}cd frontend && npm install && npm run dev${NC}"
  echo -e "  5. Acesse ${BLUE}http://localhost:5173${NC}"
  echo ""
  echo -e "Documentação:"
  echo -e "  • ${BLUE}START.md${NC} - Comece aqui (10 minutos)"
  echo -e "  • ${BLUE}README.md${NC} - Documentação completa"
  echo -e "  • ${BLUE}QUICKSTART.md${NC} - Setup rápido"
  echo -e "  • ${BLUE}N8N-SETUP.md${NC} - Configurar workflows"
  echo -e "  • ${BLUE}API-EXAMPLES.md${NC} - Exemplos de uso"
  echo ""
  exit 0
else
  echo -e "${RED}✗ ERRO: Apenas $ok/$total arquivos encontrados ($percentage%)${NC}"
  echo -e "${RED}Verifique os arquivos marcados como FALTA${NC}"
  exit 1
fi
