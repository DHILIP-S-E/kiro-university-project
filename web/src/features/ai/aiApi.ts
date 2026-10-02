import apiClient from '../../lib/apiClient';
import type { ParseReminderResponse, ExtractEventResponse } from '../../types/index';

export async function parseReminder(
  text: string,
  timezone?: string,
): Promise<ParseReminderResponse> {
  const res = await apiClient.post<ParseReminderResponse>('/ai/parse-reminder', {
    text,
    timezone: timezone ?? 'UTC',
  });
  return res.data;
}

export async function extractEvent(text: string): Promise<ExtractEventResponse> {
  const res = await apiClient.post<ExtractEventResponse>('/ai/extract-event', { text });
  return res.data;
}
