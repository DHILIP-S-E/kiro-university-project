import React from 'react';

interface CardProps {
  variant?: 'surface' | 'card';
  className?: string;
  children: React.ReactNode;
}

export default function Card({ variant = 'surface', className = '', children }: CardProps) {
  const bg = variant === 'card' ? 'bg-card' : 'bg-surface';
  return (
    <div className={`rounded-xl p-4 ${bg} ${className}`}>
      {children}
    </div>
  );
}
