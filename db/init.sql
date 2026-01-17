-- =========================================================
-- EXTENSÕES
-- =========================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- TABELA BRONZE - DADOS BRUTOS
-- =========================================================
CREATE TABLE IF NOT EXISTS bronze_enriquecimentos (
  id_enriquecimento UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  id_workspace VARCHAR(255) NOT NULL,
  nome_workspace VARCHAR(500),
  total_contatos INTEGER,
  tipo_contato VARCHAR(50),
  status_processamento VARCHAR(50),
  data_criacao TIMESTAMP,
  data_atualizacao TIMESTAMP,
  payload_original JSONB,

  -- Controle DW
  processado_gold BOOLEAN DEFAULT FALSE,
  dw_ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  dw_updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  UNIQUE (id_enriquecimento)
);

CREATE INDEX IF NOT EXISTS idx_bronze_workspace
  ON bronze_enriquecimentos(id_workspace);

CREATE INDEX IF NOT EXISTS idx_bronze_status
  ON bronze_enriquecimentos(status_processamento);

CREATE INDEX IF NOT EXISTS idx_bronze_processado_gold
  ON bronze_enriquecimentos(processado_gold);

CREATE INDEX IF NOT EXISTS idx_bronze_dw_updated
  ON bronze_enriquecimentos(dw_updated_at);

-- =========================================================
-- TABELA GOLD - DADOS TRATADOS
-- =========================================================
CREATE TABLE IF NOT EXISTS gold_enriquecimentos (
  id_enriquecimento UUID PRIMARY KEY,
  id_workspace VARCHAR(255) NOT NULL,
  nome_workspace VARCHAR(500),
  total_contatos INTEGER,
  tipo_contato VARCHAR(50),
  status_processamento VARCHAR(50),
  data_criacao TIMESTAMP,
  data_atualizacao TIMESTAMP,

  duracao_processamento_minutos NUMERIC(10,2),
  tempo_por_contato_minutos NUMERIC(10,4),
  processamento_sucesso BOOLEAN,
  categoria_tamanho_job VARCHAR(20),
  necessita_reprocessamento BOOLEAN,

  data_atualizacao_dw TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_gold_bronze
    FOREIGN KEY (id_enriquecimento)
    REFERENCES bronze_enriquecimentos(id_enriquecimento)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_gold_workspace
  ON gold_enriquecimentos(id_workspace);

CREATE INDEX IF NOT EXISTS idx_gold_status
  ON gold_enriquecimentos(status_processamento);

CREATE INDEX IF NOT EXISTS idx_gold_categoria
  ON gold_enriquecimentos(categoria_tamanho_job);

CREATE INDEX IF NOT EXISTS idx_gold_sucesso
  ON gold_enriquecimentos(processamento_sucesso);

CREATE INDEX IF NOT EXISTS idx_gold_dw_updated
  ON gold_enriquecimentos(data_atualizacao_dw);

-- =========================================================
-- VIEW CANÔNICA DE TRANSFORMAÇÃO (BRONZE → GOLD)
-- =========================================================
CREATE OR REPLACE VIEW vw_bronze_para_gold AS
SELECT
  b.id_enriquecimento,
  b.id_workspace,
  b.nome_workspace,
  b.total_contatos,

  CASE
    WHEN b.tipo_contato = 'PERSON' THEN 'PESSOA'
    WHEN b.tipo_contato = 'COMPANY' THEN 'EMPRESA'
    ELSE b.tipo_contato
  END AS tipo_contato,

  CASE
    WHEN b.status_processamento = 'PROCESSING' THEN 'EM_PROCESSAMENTO'
    WHEN b.status_processamento = 'COMPLETED' THEN 'CONCLUIDO'
    WHEN b.status_processamento = 'FAILED' THEN 'FALHOU'
    WHEN b.status_processamento = 'CANCELED' THEN 'CANCELADO'
    ELSE b.status_processamento
  END AS status_processamento,

  b.data_criacao,
  b.data_atualizacao,

  ROUND(
    EXTRACT(EPOCH FROM (b.data_atualizacao - b.data_criacao)) / 60,
    2
  ) AS duracao_processamento_minutos,

  CASE
    WHEN b.total_contatos > 0 THEN
      ROUND(
        (EXTRACT(EPOCH FROM (b.data_atualizacao - b.data_criacao)) / 60)
        / b.total_contatos,
        4
      )
    ELSE 0
  END AS tempo_por_contato_minutos,

  b.status_processamento = 'COMPLETED'
    AS processamento_sucesso,

  CASE
    WHEN b.total_contatos < 100 THEN 'PEQUENO'
    WHEN b.total_contatos BETWEEN 100 AND 500 THEN 'MEDIO'
    WHEN b.total_contatos BETWEEN 501 AND 1000 THEN 'GRANDE'
    ELSE 'MUITO_GRANDE'
  END AS categoria_tamanho_job,

  b.status_processamento IN ('FAILED', 'CANCELED')
    AS necessita_reprocessamento

FROM bronze_enriquecimentos b;

-- =========================================================
-- FUNÇÃO DE UPSERT GOLD
-- =========================================================
CREATE OR REPLACE FUNCTION fn_upsert_gold_enriquecimentos()
RETURNS INTEGER AS $$
DECLARE
  v_linhas INTEGER;
BEGIN
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
    necessita_reprocessamento,
    data_atualizacao_dw
  )
  SELECT
    v.*,
    CURRENT_TIMESTAMP
  FROM vw_bronze_para_gold v
  LEFT JOIN gold_enriquecimentos g
    ON v.id_enriquecimento = g.id_enriquecimento
  WHERE
    g.id_enriquecimento IS NULL
    OR v.data_atualizacao > g.data_atualizacao

  ON CONFLICT (id_enriquecimento)
  DO UPDATE SET
    id_workspace = EXCLUDED.id_workspace,
    nome_workspace = EXCLUDED.nome_workspace,
    total_contatos = EXCLUDED.total_contatos,
    tipo_contato = EXCLUDED.tipo_contato,
    status_processamento = EXCLUDED.status_processamento,
    data_criacao = EXCLUDED.data_criacao,
    data_atualizacao = EXCLUDED.data_atualizacao,
    duracao_processamento_minutos = EXCLUDED.duracao_processamento_minutos,
    tempo_por_contato_minutos = EXCLUDED.tempo_por_contato_minutos,
    processamento_sucesso = EXCLUDED.processamento_sucesso,
    categoria_tamanho_job = EXCLUDED.categoria_tamanho_job,
    necessita_reprocessamento = EXCLUDED.necessita_reprocessamento,
    data_atualizacao_dw = CURRENT_TIMESTAMP;

  GET DIAGNOSTICS v_linhas = ROW_COUNT;

  UPDATE bronze_enriquecimentos
  SET processado_gold = TRUE,
      dw_updated_at = CURRENT_TIMESTAMP
  WHERE id_enriquecimento IN (
    SELECT id_enriquecimento FROM vw_bronze_para_gold
  );

  RETURN v_linhas;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- TABELA DE LOGS DE WORKFLOW
-- =========================================================
CREATE TABLE IF NOT EXISTS workflow_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workflow_name VARCHAR(255) NOT NULL,
  status VARCHAR(50),
  timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  timestamp_fim TIMESTAMP,
  quantidade_processada INTEGER,
  quantidade_erros INTEGER,
  mensagem_erro TEXT,
  detalhes JSONB
);

-- =========================================================
-- VIEWS ANALÍTICAS
-- =========================================================
CREATE OR REPLACE VIEW vw_kpis_resumo AS
SELECT
  COUNT(*) AS total_jobs,
  COUNT(*) FILTER (WHERE processamento_sucesso) AS jobs_sucesso,
  ROUND(
    COUNT(*) FILTER (WHERE processamento_sucesso)::NUMERIC
    / NULLIF(COUNT(*),0) * 100, 2
  ) AS percentual_sucesso,
  ROUND(AVG(duracao_processamento_minutos),2) AS tempo_medio_minutos,
  MAX(duracao_processamento_minutos) AS tempo_maximo_minutos,
  MIN(duracao_processamento_minutos) AS tempo_minimo_minutos,
  SUM(total_contatos) AS total_contatos_processados
FROM gold_enriquecimentos;

CREATE OR REPLACE VIEW vw_stats_por_status AS
SELECT
  status_processamento,
  COUNT(*) AS quantidade,
  ROUND(
    COUNT(*)::NUMERIC
    / (SELECT COUNT(*) FROM gold_enriquecimentos) * 100, 2
  ) AS percentual,
  SUM(total_contatos) AS total_contatos,
  ROUND(AVG(duracao_processamento_minutos),2) AS tempo_medio_minutos
FROM gold_enriquecimentos
GROUP BY status_processamento;

CREATE OR REPLACE VIEW vw_stats_por_categoria AS
SELECT
  categoria_tamanho_job,
  COUNT(*) AS quantidade,
  ROUND(
    COUNT(*)::NUMERIC
    / (SELECT COUNT(*) FROM gold_enriquecimentos) * 100, 2
  ) AS percentual,
  SUM(total_contatos) AS total_contatos,
  ROUND(AVG(duracao_processamento_minutos),2) AS tempo_medio_minutos
FROM gold_enriquecimentos
GROUP BY categoria_tamanho_job
ORDER BY
  CASE categoria_tamanho_job
    WHEN 'PEQUENO' THEN 1
    WHEN 'MEDIO' THEN 2
    WHEN 'GRANDE' THEN 3
    ELSE 4
  END;
