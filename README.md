#  Script de Ingestão Automática

Script Python que faz ingestão de dados da API para PostgreSQL a cada 5 minutos.

##  Setup

```bash
# 1. Instale dependências
pip install -r requirements.txt

# 2. Configure as variáveis de ambiente
# Edite .env conforme necessário

# 3. Execute
python ingest.py
```

##  Com Docker

```bash
# Build
docker build -t driva-ingestion .

# Run
docker run -d --name driva-ingestion \
  --network driva-network \
  -e DB_HOST=postgres \
  -e API_URL=http://api:3000 \
  driva-ingestion
```

docker-compose up -d

## O que faz

1. **Fetch API** → Busca 100 registros de `/people/v1/enrichments`
2. **Insert BRONZE** → Insere raw data na tabela `bronze_enriquecimentos`
3. **Process GOLD** → Transforma e insere em `gold_enriquecimentos`
4. **Loop** → Repete a cada 5 minutos

## 🔧 Variáveis de Ambiente

| Variável | Default | Descrição |
|----------|---------|-----------|
| `API_URL` | http://localhost:3000 | URL da API |
| `API_KEY` | driva_test_key_abc123xyz789 | Bearer token |
| `DB_HOST` | localhost | Host PostgreSQL |
| `DB_USER` | driva_user | User DB |
| `DB_PASSWORD` | driva_password_secure | Pass DB |
| `DB_NAME` | driva_warehouse | Nome DB |
| `INTERVAL` | 300 | Segundos entre execuções |

## Log

```
Iniciando ingestão automática...
 Intervalo: 300s (5min)
 API: http://localhost:3000
 BD: driva_warehouse@localhost
----

[2026-01-16 18:20:00] ⏳ Iteração #1
   Fetchando API...
   Inserindo em BRONZE...
   100 registros inseridos
   Processando para GOLD...
   Processamento BRONZE → GOLD completo
   Próxima iteração em 300s...
```


##  Troubleshooting

**"Connection refused"** → PostgreSQL não está rodando
```bash
docker-compose ps
```

**"API error"** → API não está acessível
```bash
curl -H "Authorization: Bearer driva_test_key_abc123xyz789" http://localhost:3000/health
```

**Nenhum dado inserido** → Verifique logs e `.env`

##  Parar

```bash
Ctrl+C
```

---

**Pronto!** Agora seus dados fluem automaticamente. 🚀
