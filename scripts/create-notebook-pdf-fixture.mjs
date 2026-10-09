import fs from 'node:fs';
import { pdfFixture } from '../apps/ai-gateway/test/pdf-fixture.mjs';
fs.mkdirSync('.tools', { recursive: true });
fs.writeFileSync('.tools/studio-101pages.pdf', pdfFixture(101));
console.log('Created .tools/studio-101pages.pdf (101 pages, unique marker on last page)');
