#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_URL="http://localhost:3000"
API_KEY="driva_test_key_abc123xyz789"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     DRIVA PIPELINE - API TEST SUITE                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"

# Função auxiliar
test_endpoint() {
  local method=$1
  local endpoint=$2
  local name=$3
  local query_params=${4:-""}
  
  echo -e "${YELLOW}Testing${NC}: $name"
  echo -e "  Endpoint: ${BLUE}$method $endpoint$query_params${NC}"
  
  if [ "$method" = "GET" ]; then
    response=$(curl -s -w "\n%{http_code}" \
      -H "Authorization: Bearer $API_KEY" \
      "$API_URL$endpoint$query_params")
  else
    response=$(curl -s -w "\n%{http_code}" \
      -X $method \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      "$API_URL$endpoint")
  fi
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    echo -e "  ${GREEN}✓ Status: $http_code${NC}"
  else
    echo -e "  ${RED}✗ Status: $http_code${NC}"
  fi
  
  echo -e "  Response Preview:"
  echo "$body" | jq '.' 2>/dev/null | head -20
  echo -e ""
}

# Health Check
echo -e "${BLUE}1. HEALTH CHECK${NC}"
test_endpoint "GET" "/health" "API Health"

# Simulação - Enriquecimentos
echo -e "${BLUE}2. SIMULAÇÃO DE ENRIQUECIMENTOS${NC}"
test_endpoint "GET" "/people/v1/enrichments" "Enriquecimentos (Página 1, Limit 5)" "?page=1&limit=5"

echo -e "${BLUE}3. ENRIQUECIMENTOS - PÁGINA 2${NC}"
test_endpoint "GET" "/people/v1/enrichments" "Enriquecimentos (Página 2, Limit 10)" "?page=2&limit=10"

# Analytics
echo -e "${BLUE}4. ANALYTICS - OVERVIEW${NC}"
test_endpoint "GET" "/analytics/overview" "Analytics Overview"

echo -e "${BLUE}5. ANALYTICS - ENRIQUECIMENTOS PAGINADOS${NC}"
test_endpoint "GET" "/analytics/enrichments" "Analytics Enriquecimentos (Página 1)" "?page=1&limit=5"

echo -e "${BLUE}6. ANALYTICS - COM FILTRO DE STATUS${NC}"
test_endpoint "GET" "/analytics/enrichments" "Filtro por Status: CONCLUIDO" "?status_processamento=CONCLUIDO&limit=5"

echo -e "${BLUE}7. ANALYTICS - TOP WORKSPACES${NC}"
test_endpoint "GET" "/analytics/workspaces/top" "Top 5 Workspaces" "?limit=5"

# Teste com API Key inválida
echo -e "${BLUE}8. TESTE DE AUTENTICAÇÃO (API Key Inválida)${NC}"
echo -e "${YELLOW}Testing${NC}: Invalid API Key"
echo -e "  Endpoint: ${BLUE}GET /health${NC}"

response=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer invalid_key" \
  "$API_URL/health")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "401" ]; then
  echo -e "  ${GREEN}✓ Corretamente rejeitada (401)${NC}"
else
  echo -e "  ${RED}✗ Erro: recebeu $http_code em vez de 401${NC}"
fi
echo -e "  Response: $body\n"

# Teste sem API Key
echo -e "${BLUE}9. TESTE DE AUTENTICAÇÃO (Sem API Key)${NC}"
echo -e "${YELLOW}Testing${NC}: No API Key"
echo -e "  Endpoint: ${BLUE}GET /health${NC}"

response=$(curl -s -w "\n%{http_code}" \
  "$API_URL/health")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "401" ]; then
  echo -e "  ${GREEN}✓ Corretamente rejeitada (401)${NC}"
else
  echo -e "  ${RED}✗ Erro: recebeu $http_code em vez de 401${NC}"
fi
echo -e "  Response: $body\n"

echo -e "${GREEN}═════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Testes Completos!${NC}\n"

# Resumo de banco de dados
echo -e "${BLUE}RESUMO DO BANCO DE DADOS${NC}"
echo -e "Contando registros por tabela...\n"

docker-compose exec -T postgres psql -U driva_user -d driva_warehouse << EOF 2>/dev/null
\x off
\pset format unaligned
\pset tuples_only on

SELECT 'Bronze' as tabela, COUNT(*) as quantidade FROM bronze_enriquecimentos
UNION ALL
SELECT 'Gold' as tabela, COUNT(*) as quantidade FROM gold_enriquecimentos
UNION ALL
SELECT 'Logs' as tabela, COUNT(*) as quantidade FROM workflow_logs;
EOF

echo ""
