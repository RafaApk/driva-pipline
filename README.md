# 🚀 DRIVA Pipeline

**Sistema automatizado de ingestão, processamento e visualização de dados com arquitetura data lake.**

![Status](https://img.shields.io/badge/Status-Ativo-green)
![License](https://img.shields.io/badge/License-MIT-blue)

---

## 📋 IDENTIFICAÇÃO

**Projeto:** DRIVA Pipeline  
**Descrição:** Pipeline completo de ETL (Extract, Transform, Load) com orquestração automática para enriquecimento de dados de contatos.

**Repositório:** https://github.com/RafaApk/driva-pipline

---

## 👥 AUTORES

- **Rafael Fulgêncio Rosário da Cruz**  
  Email: rcruz@alunos.utfpr.edu.br

---

## 🏗️ ARQUITETURA DO PROJETO

```
┌─────────────────────────────────────────────────────────┐
│                    DRIVA Pipeline                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐    │
│  │   API    │──→   │ Ingestão │──→   │PostgreSQL│    │
│  │ Node.js  │      │  Python  │      │  Data    │    │
│  │ (porta   │      │ (5 min)  │      │ Warehouse│    │
│  │  3000)   │      │          │      │ BRONZE   │    │
│  └──────────┘      └──────────┘      │  ↓       │    │
│                                       │ GOLD     │    │
│  ┌──────────┐      ┌──────────┐      │          │    │
│  │ Frontend │←──   │   n8n    │←──   └──────────┘    │
│  │  React   │      │Orquestrador                      │
│  │ (porta   │      │(porta 5678)                      │
│  │ 5173)    │      │Workflows                         │
│  └──────────┘      └──────────┘                       │
│                                                       │
└─────────────────────────────────────────────────────────┘
```

---

## 🛠️ AMBIENTE DE DESENVOLVIMENTO E COMPILAÇÃO

### **Sistema Operacional**
- Windows 11 (64-bit) / macOS / Linux

### **Ferramenta de Containerização**
- Docker & Docker Compose

### **Gerenciamento de Versão**
- GitHub

### **Stack Tecnológico**

| Componente | Tecnologia | Versão |
|-----------|-----------|--------|
| **API** | Node.js + Express | 14+ |
| **Banco de Dados** | PostgreSQL | 14 |
| **Ingestão** | Python | 3.9+ |
| **Orquestração** | n8n | Latest |
| **Frontend** | React + Vite | 18+ |
| **Containerização** | Docker | Latest |

---

## 📦 ESTRUTURA DO PROJETO

```
driva-pipline/
├── api/                          # API Node.js
│   ├── src/
│   │   ├── index.js             # Servidor Express
│   │   └── db.js                # Conexão PostgreSQL
│   ├── Dockerfile
│   └── package.json
│
├── frontend/                      # Dashboard React
│   ├── src/
│   │   ├── App.jsx
│   │   ├── api.js               # Cliente HTTP
│   │   └── main.jsx
│   ├── vite.config.js
│   └── package.json
│
├── ingestion/                     # Script Python de Ingestão
│   ├── ingest.py                # ETL (BRONZE → GOLD)
│   ├── Dockerfile
│   ├── requirements.txt
│   └── README.md
│
├── db/                            # Scripts SQL
│   ├── init.sql                 # Inicialização do banco
│   └── fix-gold-data.sql        # Migrations
│
├── n8n-workflows/                # Orquestração Visual
│   ├── 1-ingestao-api-bronze.json
│   ├── 2-processamento-bronze-gold.json
│   └── 3-orquestrador-5-minutos.json
│
├── docker-compose.yml            # Orquestração containers
├── Makefile                       # Comandos úteis
└── README.md
```

---

## 🚀 COMO COMEÇAR

### **Pré-requisitos**
- Docker e Docker Compose instalados
- Git
- Terminal/PowerShell

### **Instalação**

1. **Clone o repositório**
```bash
git clone https://github.com/RafaApk/driva-pipline.git
cd driva-pipline
```

2. **Inicie todos os serviços**
```bash
make up
```

3. **Aguarde a estabilização (30-60s)**

### **Acesso aos Serviços**

| Serviço | URL | Credenciais |
|---------|-----|-----------|
| **API** | http://localhost:3000 | Bearer: `driva_test_key_abc123xyz789` |
| **Dashboard** | http://localhost:5173 | Sem autenticação |
| **n8n** | http://localhost:5678 | Primeira execução solicita admin |
| **PostgreSQL** | localhost:5432 | `driva_user` / `driva_password_secure` |

---

## 📊 FUNCIONAMENTO

### **Fluxo de Dados**

```
1. API Node.js
   ↓
2. Script Python (a cada 5 minutos)
   ├─ Busca dados do /people/v1/enrichments
   └─ Insere em BRONZE (tabela raw)
   ↓
3. Processamento BRONZE → GOLD
   ├─ Limpeza de dados
   ├─ Transformações
   └─ Validação
   ↓
4. Dashboard React
   └─ Visualiza dados em tempo real
```

### **Componentes Principais**

#### **API (Node.js)**
- `GET /people/v1/enrichments` - Dados simulados com paginação
- `GET /analytics/overview` - KPIs e estatísticas
- Autenticação via Bearer Token
- Simula rate limiting (429)

#### **Ingestão (Python)**
- Executa a cada 5 minutos
- Fetch → BRONZE → GOLD
- Tratamento de erros
- Logs detalhados

#### **n8n (Orquestração)**
- 3 workflows sincronizados
- Ingestão automática
- Processamento agendado
- Sem código visual

#### **Frontend (React)**
- Dashboard com gráficos
- KPIs em tempo real
- Filtros e buscas
- Exportação de dados

---

## 🔧 COMANDOS ÚTEIS

```bash
# Iniciar todos os serviços
make up

# Parar todos os serviços
make down

# Ver logs em tempo real
make logs

# Acessar terminal PostgreSQL
make db-shell

# Estatísticas do banco
make db-stats

# Iniciar apenas frontend
make frontend

# Executar testes da API
make test

# Verificar saúde dos serviços
make health

# Limpar tudo (parar + remover volumes)
make clean
```

---

## 📝 VARIÁVEIS DE AMBIENTE

Criar arquivo `.env` na raiz do projeto:

```bash
# API
API_KEY=driva_test_key_abc123xyz789
API_URL=http://localhost:3000

# PostgreSQL
DB_HOST=postgres
DB_PORT=5432
DB_USER=driva_user
DB_PASSWORD=driva_password_secure
DB_NAME=driva_warehouse

# Ingestão
INTERVAL=300  # segundos (5 minutos)

# n8n
N8N_HOST=0.0.0.0
N8N_PORT=5678

# Frontend
VITE_API_URL=http://localhost:3000
```

---

## 🧪 TESTES

```bash
# Testar API
curl -H "Authorization: Bearer driva_test_key_abc123xyz789" \
  http://localhost:3000/people/v1/enrichments

# Testar analytics
curl -H "Authorization: Bearer driva_test_key_abc123xyz789" \
  http://localhost:3000/analytics/overview

# Verificar banco de dados
docker exec -it driva-postgres psql -U driva_user -d driva_warehouse \
  -c "SELECT COUNT(*) FROM gold_enriquecimentos;"
```

---


