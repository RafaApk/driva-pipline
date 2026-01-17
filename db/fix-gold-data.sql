-- Script para atualizar dados faltantes na tabela GOLD
-- Executa UPDATE para preencher campos vazios/NULL

-- 1. Atualizar GOLD com dados processados da BRONZE
UPDATE gold_enriquecimentos g
SET 
  duracao_processamento_minutos = ROUND(
    EXTRACT(EPOCH FROM (b.data_atualizacao - b.data_criacao))::NUMERIC / 60, 2
  ),
  tempo_por_contato_minutos = CASE 
    WHEN b.total_contatos > 0 THEN ROUND(
      (EXTRACT(EPOCH FROM (b.data_atualizacao - b.data_criacao))::NUMERIC / 60) / b.total_contatos, 4
    )
    ELSE 0
  END,
  processamento_sucesso = (b.status_processamento = 'COMPLETED'),
  categoria_tamanho_job = CASE 
    WHEN b.total_contatos < 100 THEN 'PEQUENO'
    WHEN b.total_contatos >= 100 AND b.total_contatos <= 500 THEN 'MEDIO'
    WHEN b.total_contatos > 500 AND b.total_contatos <= 1000 THEN 'GRANDE'
    WHEN b.total_contatos > 1000 THEN 'MUITO_GRANDE'
  END,
  necessita_reprocessamento = (b.status_processamento IN ('FAILED', 'CANCELED')),
  tipo_contato = CASE 
    WHEN b.tipo_contato = 'PERSON' THEN 'PESSOA'
    WHEN b.tipo_contato = 'COMPANY' THEN 'EMPRESA'
    ELSE b.tipo_contato
  END,
  status_processamento = CASE 
    WHEN b.status_processamento = 'PROCESSING' THEN 'EM_PROCESSAMENTO'
    WHEN b.status_processamento = 'COMPLETED' THEN 'CONCLUIDO'
    WHEN b.status_processamento = 'FAILED' THEN 'FALHOU'
    WHEN b.status_processamento = 'CANCELED' THEN 'CANCELADO'
    ELSE b.status_processamento
  END,
  data_atualizacao_dw = CURRENT_TIMESTAMP
FROM bronze_enriquecimentos b
WHERE g.id_enriquecimento = b.id_enriquecimento
  AND (
    g.duracao_processamento_minutos IS NULL
    OR g.tempo_por_contato_minutos IS NULL
    OR g.categoria_tamanho_job IS NULL
    OR g.tipo_contato IS NULL
    OR g.status_processamento NOT LIKE '%_%'
  );

-- 2. Inserir novos registros da BRONZE que ainda não existem em GOLD
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
  b.id_enriquecimento,
  b.id_workspace,
  b.nome_workspace,
  b.total_contatos,
  CASE 
    WHEN b.tipo_contato = 'PERSON' THEN 'PESSOA'
    WHEN b.tipo_contato = 'COMPANY' THEN 'EMPRESA'
    ELSE b.tipo_contato
  END as tipo_contato,
  CASE 
    WHEN b.status_processamento = 'PROCESSING' THEN 'EM_PROCESSAMENTO'
    WHEN b.status_processamento = 'COMPLETED' THEN 'CONCLUIDO'
    WHEN b.status_processamento = 'FAILED' THEN 'FALHOU'
    WHEN b.status_processamento = 'CANCELED' THEN 'CANCELADO'
    ELSE b.status_processamento
  END as status_processamento,
  b.data_criacao,
  b.data_atualizacao,
  ROUND(EXTRACT(EPOCH FROM (b.data_atualizacao - b.data_criacao))::NUMERIC / 60, 2) as duracao_processamento_minutos,
  CASE 
    WHEN b.total_contatos > 0 THEN ROUND((EXTRACT(EPOCH FROM (b.data_atualizacao - b.data_criacao))::NUMERIC / 60) / b.total_contatos, 4)
    ELSE 0
  END as tempo_por_contato_minutos,
  b.status_processamento = 'COMPLETED' as processamento_sucesso,
  CASE 
    WHEN b.total_contatos < 100 THEN 'PEQUENO'
    WHEN b.total_contatos >= 100 AND b.total_contatos <= 500 THEN 'MEDIO'
    WHEN b.total_contatos > 500 AND b.total_contatos <= 1000 THEN 'GRANDE'
    WHEN b.total_contatos > 1000 THEN 'MUITO_GRANDE'
  END as categoria_tamanho_job,
  b.status_processamento IN ('FAILED', 'CANCELED') as necessita_reprocessamento,
  CURRENT_TIMESTAMP as data_atualizacao_dw
FROM bronze_enriquecimentos b
WHERE NOT EXISTS (
  SELECT 1 FROM gold_enriquecimentos g 
  WHERE g.id_enriquecimento = b.id_enriquecimento
);

-- 3. Validar resultado
SELECT 
  COUNT(*) as total_registros,
  COUNT(CASE WHEN categoria_tamanho_job IS NOT NULL THEN 1 END) as com_categoria,
  COUNT(CASE WHEN tempo_por_contato_minutos IS NOT NULL THEN 1 END) as com_tempo,
  COUNT(CASE WHEN categoria_tamanho_job IS NULL THEN 1 END) as categoria_null,
  COUNT(CASE WHEN tempo_por_contato_minutos IS NULL THEN 1 END) as tempo_null
FROM gold_enriquecimentos;

-- 4. Mostrar amostra de dados
SELECT 
  id_enriquecimento,
  nome_workspace,
  total_contatos,
  tipo_contato,
  status_processamento,
  categoria_tamanho_job as "Categoria",
  tempo_por_contato_minutos as "Tempo (min)",
  data_atualizacao_dw
FROM gold_enriquecimentos
ORDER BY data_atualizacao_dw DESC
LIMIT 10;
