import axios from 'axios';

const API_BASE_URL = 'http://localhost:3000';
const API_KEY = 'driva_test_key_abc123xyz789';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Authorization': `Bearer ${API_KEY}`,
    'Content-Type': 'application/json'
  }
});

export const getOverview = async () => {
  try {
    const response = await apiClient.get('/analytics/overview');
    return response.data;
  } catch (error) {
    console.error('Erro ao buscar overview:', error);
    throw error;
  }
};

export const getEnrichments = async (page = 1, limit = 20, filters = {}) => {
  try {
    const params = new URLSearchParams({
      page,
      limit,
      ...filters
    });
    const response = await apiClient.get(`/analytics/enrichments?${params}`);
    return response.data;
  } catch (error) {
    console.error('Erro ao buscar enriquecimentos:', error);
    throw error;
  }
};

export const getTopWorkspaces = async (limit = 10) => {
  try {
    const response = await apiClient.get(`/analytics/workspaces/top?limit=${limit}`);
    return response.data;
  } catch (error) {
    console.error('Erro ao buscar workspaces top:', error);
    throw error;
  }
};
