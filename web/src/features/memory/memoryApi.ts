import apiClient from '../../lib/apiClient';
import type { MemoryDocument, AskRequest, AskResponse } from '../../types/index';

export async function listMemory(): Promise<MemoryDocument[]> {
  const res = await apiClient.get<MemoryDocument[]>('/memory');
  return res.data;
}

export async function searchMemory(q: string): Promise<MemoryDocument[]> {
  const res = await apiClient.get<MemoryDocument[]>('/memory/search', { params: { q } });
  return res.data;
}

export async function askMemory(question: string): Promise<AskResponse> {
  const body: AskRequest = { question };
  const res = await apiClient.post<AskResponse>('/memory/ask', body);
  return res.data;
}

export async function getMemoryDocument(id: string): Promise<MemoryDocument> {
  const res = await apiClient.get<MemoryDocument>(`/memory/${id}`);
  return res.data;
}
