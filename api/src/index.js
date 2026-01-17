const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');
const db = require('./db');

const app = express();
const API_KEY = process.env.API_KEY || 'driva_test_key_abc123xyz789';

// Middlewares
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Middleware de autenticação
const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'API Key inválida ou ausente' });
  }
  
  const providedKey = authHeader.substring(7);
  if (providedKey !== API_KEY) {
    return res.status(401).json({ error: 'API Key inválida' });
  }
  
  next();
};

// Gerador de dados simulados
function generateEnrichmentData(page, limit) {
  const data = [];
  const startId = (page - 1) * limit;
  
  const workspaceIds = [
    'WS001', 'WS002', 'WS003', 'WS004', 'WS005', 
    'WS006', 'WS007', 'WS008', 'WS009', 'WS010'
  ];
  
  const workspaceNames = [
    'Workspace Alpha', 'Workspace Beta', 'Workspace Gamma', 'Workspace Delta', 'Workspace Epsilon',
    'Workspace Zeta', 'Workspace Eta', 'Workspace Theta', 'Workspace Iota', 'Workspace Kappa'
  ];
  
  const contactTypes = ['PERSON', 'COMPANY'];
  const statuses = ['PROCESSING', 'COMPLETED', 'FAILED', 'CANCELED'];
  
  for (let i = 0; i < limit; i++) {
    const index = startId + i;
    const workspaceIndex = index % workspaceIds.length;
    const statusIndex = Math.floor(index / 10) % statuses.length;
    
    const createdAt = new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000);
    const updatedAt = new Date(createdAt.getTime() + Math.random() * 6 * 60 * 60 * 1000);
    
    data.push({
      id_enriquecimento: uuidv4(),
      id_workspace: workspaceIds[workspaceIndex],
      nome_workspace: workspaceNames[workspaceIndex],
      total_contatos: Math.floor(Math.random() * 1500) + 10,
      tipo_contato: contactTypes[Math.floor(Math.random() * contactTypes.length)],
      status_processamento: statuses[statusIndex],
      data_criacao: createdAt.toISOString(),
      data_atualizacao: updatedAt.toISOString(),
    });
  }
  
  return data;
}

// ===========================
// ENDPOINTS DE SIMULAÇÃO (FONTE)
// ===========================

app.get('/people/v1/enrichments', authMiddleware, (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);
    
    // Simular erro 429 aleatoriamente (5% de chance)
    if (Math.random() < 0.05) {
      return res.status(429).json({
        error: 'Too Many Requests',
        message: 'Limite de requisições excedido. Tente novamente em alguns segundos.',
        retry_after: 5
      });
    }
    
    const totalItems = 5000;
    const totalPages = Math.ceil(totalItems / limit);
    
    // Validação
    if (page < 1 || page > totalPages) {
      return res.status(400).json({
        error: 'Página inválida',
        message: `Página deve estar entre 1 e ${totalPages}`
      });
    }
    
    const data = generateEnrichmentData(page, limit);
    
    res.json({
      meta: {
        page,
        limit,
        total_items: totalItems,
        total_pages: totalPages,
        has_next: page < totalPages,
        has_previous: page > 1
      },
      data
    });
  } catch (error) {
    console.error('Erro ao retornar enriquecimentos:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ===========================
// ENDPOINTS DE ANALYTICS
// ===========================

app.get('/analytics/overview', authMiddleware, async (req, res) => {
  try {
    const { result: kpisResult } = await db.query('SELECT * FROM vw_kpis_resumo');
    const { result: statusResult } = await db.query('SELECT * FROM vw_stats_por_status');
    const { result: categoriaResult } = await db.query('SELECT * FROM vw_stats_por_categoria');
    
    const kpis = kpisResult.rows[0] || {};
    
    res.json({
      kpis: {
        total_jobs: parseInt(kpis.total_jobs) || 0,
        jobs_sucesso: parseInt(kpis.jobs_sucesso) || 0,
        percentual_sucesso: parseFloat(kpis.percentual_sucesso) || 0,
        tempo_medio_minutos: parseFloat(kpis.tempo_medio_minutos) || 0,
        tempo_maximo_minutos: parseFloat(kpis.tempo_maximo_minutos) || 0,
        tempo_minimo_minutos: parseFloat(kpis.tempo_minimo_minutos) || 0,
        total_contatos_processados: parseInt(kpis.total_contatos_processados) || 0,
      },
      distribuicao_status: statusResult.rows.map(row => ({
        status: row.status_processamento,
        quantidade: parseInt(row.quantidade),
        percentual: parseFloat(row.percentual),
        total_contatos: parseInt(row.total_contatos),
        tempo_medio_minutos: parseFloat(row.tempo_medio_minutos)
      })),
      distribuicao_categoria: categoriaResult.rows.map(row => ({
        categoria: row.categoria_tamanho_job,
        quantidade: parseInt(row.quantidade),
        percentual: parseFloat(row.percentual),
        total_contatos: parseInt(row.total_contatos),
        tempo_medio_minutos: parseFloat(row.tempo_medio_minutos)
      }))
    });
  } catch (error) {
    console.error('Erro ao retornar overview:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

app.get('/analytics/enrichments', authMiddleware, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = (page - 1) * limit;
    
    let whereClause = 'WHERE 1=1';
    const params = [];
    let paramCount = 1;
    
    // Filtro por workspace
    if (req.query.id_workspace) {
      whereClause += ` AND id_workspace = $${paramCount}`;
      params.push(req.query.id_workspace);
      paramCount++;
    }
    
    // Filtro por status
    if (req.query.status_processamento) {
      whereClause += ` AND status_processamento = $${paramCount}`;
      params.push(req.query.status_processamento);
      paramCount++;
    }
    
    // Filtro por período (data_atualizacao_dw)
    if (req.query.data_inicio) {
      whereClause += ` AND data_atualizacao_dw >= $${paramCount}`;
      params.push(req.query.data_inicio);
      paramCount++;
    }
    
    if (req.query.data_fim) {
      whereClause += ` AND data_atualizacao_dw <= $${paramCount}`;
      params.push(req.query.data_fim);
      paramCount++;
    }
    
    // Query para total de registros
    const countQuery = `SELECT COUNT(*) as total FROM gold_enriquecimentos ${whereClause}`;
    const countResult = await db.query(countQuery, params);
    const totalItems = parseInt(countResult.result.rows[0].total);
    const totalPages = Math.ceil(totalItems / limit);
    
    // Query para dados paginados
    const dataQuery = `
      SELECT 
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
      FROM gold_enriquecimentos
      ${whereClause}
      ORDER BY data_atualizacao_dw DESC
      LIMIT $${paramCount} OFFSET $${paramCount + 1}
    `;
    
    const dataResult = await db.query(dataQuery, [...params, limit, offset]);
    
    res.json({
      meta: {
        page,
        limit,
        total_items: totalItems,
        total_pages: totalPages,
        has_next: page < totalPages,
        has_previous: page > 1
      },
      data: dataResult.result.rows
    });
  } catch (error) {
    console.error('Erro ao retornar enriquecimentos:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

app.get('/analytics/workspaces/top', authMiddleware, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    
    const { result } = await db.query(`
      SELECT 
        id_workspace,
        nome_workspace,
        quantidade_jobs,
        total_contatos,
        taxa_sucesso,
        tempo_medio_minutos
      FROM vw_ranking_workspaces
      LIMIT $1
    `, [limit]);
    
    res.json({
      data: result.rows
    });
  } catch (error) {
    console.error('Erro ao retornar ranking de workspaces:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Rota raiz
app.get('/', (req, res) => {
  res.json({
    name: 'Driva Pipeline API',
    version: '1.0.0',
    endpoints: {
      enriquecimentos: 'GET /people/v1/enrichments',
      analytics_overview: 'GET /analytics/overview',
      analytics_enrichments: 'GET /analytics/enrichments',
      analytics_workspaces: 'GET /analytics/workspaces/top',
      health: 'GET /health'
    },
    auth: 'Header: Authorization: Bearer driva_test_key_abc123xyz789'
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Erro não capturado:', err);
  res.status(500).json({
    error: 'Erro interno do servidor',
    message: err.message
  });
});

// Inicia o servidor
const PORT = process.env.API_PORT || 3000;
app.listen(PORT, () => {
  console.log(`API rodando na porta ${PORT}`);
});
