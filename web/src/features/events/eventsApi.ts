import apiClient from '../../lib/apiClient';
import type {
  Event,
  EventCreate,
  EventUpdate,
  EventDeadline,
  DeadlineIn,
  MemoryDocument,
} from '../../types/index';

export interface ListEventsParams {
  event_status?: string;
  event_type?: string;
}

export async function listEvents(params?: ListEventsParams): Promise<Event[]> {
  const res = await apiClient.get<Event[]>('/events', { params });
  return res.data;
}

export async function getEvent(id: string): Promise<Event> {
  const res = await apiClient.get<Event>(`/events/${id}`);
  return res.data;
}

export async function createEvent(body: EventCreate): Promise<Event> {
  const res = await apiClient.post<Event>('/events', body);
  return res.data;
}

export async function updateEvent(id: string, body: EventUpdate): Promise<Event> {
  const res = await apiClient.patch<Event>(`/events/${id}`, body);
  return res.data;
}

export async function deleteEvent(id: string): Promise<{ deleted: string }> {
  const res = await apiClient.delete<{ deleted: string }>(`/events/${id}`);
  return res.data;
}

export async function addDeadline(eventId: string, body: DeadlineIn): Promise<EventDeadline> {
  const res = await apiClient.post<EventDeadline>(`/events/${eventId}/deadlines`, body);
  return res.data;
}

export async function previewReminderPolicy(eventId: string): Promise<object[]> {
  const res = await apiClient.get<object[]>(`/events/${eventId}/reminder-policy`);
  return res.data;
}

export async function applyReminderPolicy(eventId: string): Promise<object[]> {
  const res = await apiClient.post<object[]>(`/events/${eventId}/reminder-policy`);
  return res.data;
}

export async function generateSummary(eventId: string): Promise<MemoryDocument> {
  const res = await apiClient.post<MemoryDocument>(`/events/${eventId}/generate-summary`);
  return res.data;
}

export async function getEventSummary(eventId: string): Promise<MemoryDocument> {
  const res = await apiClient.get<MemoryDocument>(`/events/${eventId}/summary`);
  return res.data;
}
