import { useState, useEffect } from 'react';
import { BarChart, Bar, LineChart, Line, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { getOverview, getEnrichments, getTopWorkspaces } from './api';
import './App.css';

function App() {
  const [overview, setOverview] = useState(null);
  const [enrichments, setEnrichments] = useState([]);
  const [topWorkspaces, setTopWorkspaces] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);

  const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8'];

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        const [overviewData, enrichmentsData, workspacesData] = await Promise.all([
          getOverview(),
          getEnrichments(currentPage),
          getTopWorkspaces()
        ]);

        setOverview(overviewData);
        setEnrichments(enrichmentsData.data);
        setTotalPages(enrichmentsData.meta.total_pages);
        setTopWorkspaces(workspacesData.data);
        setError(null);
      } catch (err) {
        console.error('Erro ao carregar dados:', err);
        setError('Erro ao carregar dados. Verifique se a API está rodando.');
      } finally {
        setLoading(false);
      }
    };

    fetchData();
    const interval = setInterval(fetchData, 30000); // Atualiza a cada 30 segundos
    return () => clearInterval(interval);
  }, [currentPage]);

  if (loading && !overview) {
    return <div className="container"><div className="loader">Carregando...</div></div>;
  }

  return (
    <div className="container">
      <header className="header">
        <h1>🚀 Driva Pipeline - Dashboard</h1>
        <p>Monitoramento de Enriquecimentos de Dados</p>
      </header>

      {error && <div className="error-message">{error}</div>}

      {/* KPIs */}
      {overview && (
        <section className="kpis-section">
          <h2>KPIs Principais</h2>
          <div className="kpis-grid">
            <div className="kpi-card">
              <div className="kpi-value">{overview.kpis.total_jobs}</div>
              <div className="kpi-label">Total de Jobs</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-value">{overview.kpis.jobs_sucesso}</div>
              <div className="kpi-label">Jobs Sucesso</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-value">{overview.kpis.percentual_sucesso}%</div>
              <div className="kpi-label">Taxa de Sucesso</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-value">{overview.kpis.tempo_medio_minutos}</div>
              <div className="kpi-label">Tempo Médio (min)</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-value">{overview.kpis.total_contatos_processados}</div>
              <div className="kpi-label">Total Contatos</div>
            </div>
          </div>
        </section>
      )}

      {/* Gráficos */}
      {overview && (
        <section className="charts-section">
          <div className="chart-container">
            <h3>Distribuição por Status</h3>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={overview.distribuicao_status}
                  dataKey="quantidade"
                  nameKey="status"
                  cx="50%"
                  cy="50%"
                  outerRadius={100}
                  label
                >
                  {overview.distribuicao_status.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>

          <div className="chart-container">
            <h3>Distribuição por Categoria de Tamanho</h3>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={overview.distribuicao_categoria}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="categoria" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="quantidade" fill="#8884d8" name="Quantidade" />
              </BarChart>
            </ResponsiveContainer>
          </div>

          <div className="chart-container full-width">
            <h3>Tempo Médio por Status</h3>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={overview.distribuicao_status}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="status" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="tempo_medio_minutos" fill="#82ca9d" name="Tempo (min)" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </section>
      )}

      {/* Top Workspaces */}
      {topWorkspaces.length > 0 && (
        <section className="top-workspaces-section">
          <h2>Top 10 Workspaces</h2>
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>ID Workspace</th>
                  <th>Nome</th>
                  <th>Qty Jobs</th>
                  <th>Total Contatos</th>
                  <th>Taxa Sucesso</th>
                  <th>Tempo Médio (min)</th>
                </tr>
              </thead>
              <tbody>
                {topWorkspaces.map((ws) => (
                  <tr key={ws.id_workspace}>
                    <td><code>{ws.id_workspace}</code></td>
                    <td>{ws.nome_workspace}</td>
                    <td>{ws.quantidade_jobs}</td>
                    <td>{ws.total_contatos}</td>
                    <td><span className="badge">{ws.taxa_sucesso}%</span></td>
                    <td>{ws.tempo_medio_minutos}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      {/* Lista de Enriquecimentos */}
      <section className="enrichments-section">
        <h2>Enriquecimentos Recentes</h2>
        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Workspace</th>
                <th>Tipo</th>
                <th>Status</th>
                <th>Contatos</th>
                <th>Categoria</th>
                <th>Tempo (min)</th>
              </tr>
            </thead>
            <tbody>
              {enrichments.map((enr) => (
                <tr key={enr.id_enriquecimento}>
                  <td><code>{enr.id_enriquecimento.substring(0, 8)}...</code></td>
                  <td>{enr.nome_workspace}</td>
                  <td>{enr.tipo_contato}</td>
                  <td>
                    <span className={`status-badge status-${enr.status_processamento.toLowerCase()}`}>
                      {enr.status_processamento}
                    </span>
                  </td>
                  <td>{enr.total_contatos}</td>
                  <td>{enr.categoria_tamanho_job}</td>
                  <td>{enr.duracao_processamento_minutos}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Paginação */}
        <div className="pagination">
          <button
            onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
            disabled={currentPage === 1}
          >
            Anterior
          </button>
          <span>Página {currentPage} de {totalPages}</span>
          <button
            onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
            disabled={currentPage === totalPages}
          >
            Próxima
          </button>
        </div>
      </section>

      <footer className="footer">
        <p>Driva Pipeline © 2024 | Última atualização: {new Date().toLocaleString('pt-BR')}</p>
      </footer>
    </div>
  );
}

export default App;
