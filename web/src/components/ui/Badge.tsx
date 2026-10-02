interface BadgeProps {
  label: string;
  className?: string;
}

// Priority badge colors
const priorityColors: Record<string, string> = {
  low: 'bg-gray-700 text-gray-200',
  medium: 'bg-blue-900 text-blue-200',
  high: 'bg-orange-900 text-orange-200',
  critical: 'bg-red-900 text-red-200',
};

// Reminder status colors
const reminderStatusColors: Record<string, string> = {
  active: 'bg-green-900 text-green-200',
  completed: 'bg-gray-700 text-gray-200',
  snoozed: 'bg-yellow-900 text-yellow-200',
  cancelled: 'bg-red-900 text-red-200',
};

// Event status colors
const eventStatusColors: Record<string, string> = {
  draft: 'bg-gray-700 text-gray-200',
  registered: 'bg-blue-900 text-blue-200',
  upcoming: 'bg-indigo-900 text-indigo-200',
  active: 'bg-green-900 text-green-200',
  attended: 'bg-purple-900 text-purple-200',
  completed: 'bg-gray-700 text-gray-200',
};

// Capture processing status colors
const captureStatusColors: Record<string, string> = {
  uploaded: 'bg-gray-700 text-gray-200',
  queued: 'bg-gray-700 text-gray-200',
  processing: 'bg-yellow-900 text-yellow-200',
  processed: 'bg-green-900 text-green-200',
  failed: 'bg-red-900 text-red-200',
};

const allColorMaps = [
  priorityColors,
  reminderStatusColors,
  eventStatusColors,
  captureStatusColors,
];

function getColorClass(label: string): string {
  const key = label.toLowerCase();
  for (const map of allColorMaps) {
    if (key in map) return map[key];
  }
  return 'bg-gray-700 text-gray-200';
}

export default function Badge({ label, className = '' }: BadgeProps) {
  return (
    <span
      className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${getColorClass(label)} ${className}`}
    >
      {label}
    </span>
  );
}
