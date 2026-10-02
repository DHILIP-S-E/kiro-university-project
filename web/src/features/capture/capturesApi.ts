import apiClient from '../../lib/apiClient';
import type {
  Capture,
  UploadUrlRequest,
  RegisterCaptureRequest,
  TextNoteRequest,
  LinkRequest,
} from '../../types/index';

// The backend /captures/upload-url returns capture_id + s3_key alongside upload_url
export interface UploadUrlResponse {
  upload_url: string;
  capture_id: string;
  s3_key: string;
  expires_in: number;
}

export interface DownloadUrlResponse {
  download_url: string;
  expires_in: number;
}

export interface ListCapturesParams {
  event_id?: string;
  capture_type?: string;
}

export async function getUploadUrl(body: UploadUrlRequest): Promise<UploadUrlResponse> {
  const res = await apiClient.post<UploadUrlResponse>('/captures/upload-url', body);
  return res.data;
}

export async function registerCapture(body: RegisterCaptureRequest): Promise<Capture> {
  const res = await apiClient.post<Capture>('/captures', body);
  return res.data;
}

export async function createTextNote(body: TextNoteRequest): Promise<Capture> {
  const res = await apiClient.post<Capture>('/captures/note', body);
  return res.data;
}

export async function saveLink(body: LinkRequest): Promise<Capture> {
  const res = await apiClient.post<Capture>('/captures/link', body);
  return res.data;
}

export async function listCaptures(params?: ListCapturesParams): Promise<Capture[]> {
  const res = await apiClient.get<Capture[]>('/captures', { params });
  return res.data;
}

export async function getCapture(id: string): Promise<Capture> {
  const res = await apiClient.get<Capture>(`/captures/${id}`);
  return res.data;
}

export async function getDownloadUrl(id: string): Promise<DownloadUrlResponse> {
  const res = await apiClient.get<DownloadUrlResponse>(`/captures/${id}/download-url`);
  return res.data;
}

export async function deleteCapture(id: string): Promise<{ deleted: string }> {
  const res = await apiClient.delete<{ deleted: string }>(`/captures/${id}`);
  return res.data;
}

/**
 * Upload a file directly to S3 using the pre-signed PUT URL.
 * Must NOT include the Authorization header — S3 rejects signed requests with extra auth.
 */
export async function uploadFileToS3(
  uploadUrl: string,
  file: File,
  contentType: string,
): Promise<void> {
  const response = await fetch(uploadUrl, {
    method: 'PUT',
    headers: { 'Content-Type': contentType },
    body: file,
  });
  if (!response.ok) {
    throw new Error(`S3 upload failed: ${response.status} ${response.statusText}`);
  }
}
