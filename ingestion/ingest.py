#!/usr/bin/env python3
"""
Ingestão automática de dados da API para PostgreSQL (Bronze)
Roda a cada 5 minutos
"""

import requests
import psycopg2
import json
import time
import os
from datetime import datetime
from dotenv import load_dotenv

# Carregar variáveis de ambiente
load_dotenv()

# Configuração
API_URL = os.getenv("API_URL", "http://localhost:3000")
API_KEY = os.getenv("API_KEY", "driva_test_key_abc123xyz789")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_USER = os.getenv("DB_USER", "driva_user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "driva_password_secure")
DB_NAME = os.getenv("DB_NAME", "driva_warehouse")
INTERVAL = int(os.getenv("INTERVAL", "300"))  # 5 minutos

def connect_db():
    """Conecta ao PostgreSQL"""
    return psycopg2.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME
    )

def fetch_api(page=1, limit=100):
    """Fetch de dados da API"""
    try:
        url = f"{API_URL}/people/v1/enrichments"
        headers = {"Authorization": f"Bearer {API_KEY}"}
        params = {"page": page, "limit": limit}
        
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        
        return response.json()
    except Exception as e:
        print(f"❌ Erro ao fetch da API: {e}")
        return None

def insert_bronze(data):
    """Insere dados na tabela BRONZE"""
    if not data or "data" not in data:
        print("⚠️ Resposta da API inválida")
        return 0
    
    records = data.get("data", [])
    if not records:
        print("⚠️ Nenhum registro para inserir")
        return 0
    
    try:
        conn = connect_db()
        cursor = conn.cursor()
        
        inserted = 0
        for record in records:
            try:
                cursor.execute("""
                    INSERT INTO bronze_enriquecimentos (
                        id_enriquecimento,
                        id_workspace,
                        nome_workspace,
                        total_contatos,
                        tipo_contato,
                        status_processamento,
                        data_criacao,
                        data_atualizacao,
                        payload_original
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (id_enriquecimento) DO NOTHING;
                """, (
                    record.get("id_enriquecimento"),
                    record.get("id_workspace"),
                    record.get("nome_workspace"),
                    record.get("total_contatos", 0),
                    record.get("tipo_contato"),
                    record.get("status_processamento"),
                    record.get("data_criacao"),
                    record.get("data_atualizacao"),
                    json.dumps(record)
                ))
                inserted += 1
            except Exception as e:
                print(f"⚠️ Erro ao inserir registro: {e}")
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return inserted
    except Exception as e:
        print(f"❌ Erro ao conectar/inserir no banco: {e}")
        return 0

def process_bronze_to_gold():
    """Processa dados de BRONZE para GOLD"""
    try:
        conn = connect_db()
        cursor = conn.cursor()
        
        # Atualizar status
        cursor.execute("""
            INSERT INTO gold_enriquecimentos (
                id_enriquecimento,
                id_workspace,
                nome_workspace,
                total_contatos,
                tipo_contato,
                status_processamento,
                data_criacao,
                data_atualizacao,
                duracao_processamento_minutos,
                tempo_por_contato_minutos,
                processamento_sucesso,
                categoria_tamanho_job,
                necessita_reprocessamento
            )
            SELECT
                id_enriquecimento,
                id_workspace,
                nome_workspace,
                total_contatos,
                tipo_contato,
                'CONCLUIDO',
                data_criacao,
                data_atualizacao,
                0,
                0,
                true,
                CASE
                    WHEN total_contatos < 100 THEN 'PEQUENO'
                    WHEN total_contatos < 500 THEN 'MEDIO'
                    WHEN total_contatos < 1000 THEN 'GRANDE'
                    ELSE 'MUITO_GRANDE'
                END,
                false
            FROM bronze_enriquecimentos
            WHERE status_processamento = 'PROCESSING'
            ON CONFLICT (id_enriquecimento) DO UPDATE SET
                status_processamento = 'CONCLUIDO'
        """)
        
        conn.commit()
        cursor.close()
        conn.close()
        
        print("✅ Processamento BRONZE → GOLD completo")
        return True
    except Exception as e:
        print(f"❌ Erro ao processar: {e}")
        return False

def run():
    """Loop principal"""
    print("🚀 Iniciando ingestão automática...")
    print(f"⏱️ Intervalo: {INTERVAL}s ({INTERVAL/60:.0f}min)")
    print(f"🔗 API: {API_URL}")
    print(f"📊 BD: {DB_NAME}@{DB_HOST}")
    print("-" * 60)
    
    iteration = 0
    while True:
        iteration += 1
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        print(f"\n[{timestamp}] ⏳ Iteração #{iteration}")
        
        # Fetch API
        print("  📡 Fetchando API...")
        data = fetch_api()
        
        if data:
            # Inserir em BRONZE
            print("  💾 Inserindo em BRONZE...")
            inserted = insert_bronze(data)
            print(f"  ✅ {inserted} registros inseridos")
            
            # Processar para GOLD
            print("  ⚙️ Processando para GOLD...")
            process_bronze_to_gold()
        else:
            print("  ❌ Falha no fetch")
        
        # Aguardar próxima iteração
        print(f"  ⏰ Próxima iteração em {INTERVAL}s...")
        time.sleep(INTERVAL)

if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        print("\n\n🛑 Ingestão parada pelo usuário")
    except Exception as e:
        print(f"\n❌ Erro fatal: {e}")
