import { readFileSync } from 'fs';
import { join } from 'path';

export function loadTechnologies(): string[] {
  const csvPath = join(process.cwd(), 'data/supported_technologies.csv');
  const csv = readFileSync(csvPath, 'utf-8');
  const lines = csv.split('\n').slice(1); // skip header
  return lines
    .map((line) => line.split(',')[1]?.trim())
    .filter((tech): tech is string => !!tech);
}
