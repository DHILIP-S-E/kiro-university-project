import apiClient from '../../lib/apiClient';
import type { Reminder, ReminderCreate, ReminderUpdate } from '../../types/index';

export interface ListRemindersParams {
  reminder_status?: string;
  reminder_type?: string;
}

export async function listReminders(params?: ListRemindersParams): Promise<Reminder[]> {
  const res = await apiClient.get<Reminder[]>('/reminders', { params });
  return res.data;
}

export async function getReminder(id: string): Promise<Reminder> {
  const res = await apiClient.get<Reminder>(`/reminders/${id}`);
  return res.data;
}

export async function createReminder(body: ReminderCreate): Promise<Reminder> {
  const res = await apiClient.post<Reminder>('/reminders', body);
  return res.data;
}

export async function updateReminder(id: string, body: ReminderUpdate): Promise<Reminder> {
  const res = await apiClient.patch<Reminder>(`/reminders/${id}`, body);
  return res.data;
}

export async function deleteReminder(id: string): Promise<{ deleted: string }> {
  const res = await apiClient.delete<{ deleted: string }>(`/reminders/${id}`);
  return res.data;
}
