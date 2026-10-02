export const colors = {
  background: '#0F0F0F',
  surface: '#1A1A1A',
  card: '#242424',
  accent: '#6366F1',
  accentHover: '#4F46E5',
  textPrimary: '#F9FAFB',
  textSecondary: '#9CA3AF',
  textMuted: '#6B7280',
  success: '#22C55E',
  warning: '#EAB308',
  error: '#EF4444',
  border: '#2D2D2D',
} as const;

export type ColorKey = keyof typeof colors;
