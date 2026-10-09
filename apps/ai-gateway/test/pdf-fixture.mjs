// Tiny deterministic text PDF for integration tests, with a unique term on the last page.
export function pdfFixture(pageCount = 101) {
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    `<< /Type /Pages /Count ${pageCount} /Kids [${Array.from({length:pageCount},(_,i)=>`${4+i*2} 0 R`).join(' ')}] >>`,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  for (let i = 0; i < pageCount; i++) {
    objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents ${5+i*2} 0 R >>`);
    const text = i === pageCount - 1 ? 'Notebook zebraPhoton101 light energy' : `Notebook introduction page ${i+1}`;
    const stream = `BT /F1 12 Tf 72 720 Td (${text}) Tj ET\n`;
    objects.push(`<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}endstream`);
  }
  let data = '%PDF-1.4\n'; const offsets = [0];
  objects.forEach((obj,i)=>{ offsets.push(Buffer.byteLength(data)); data += `${i+1} 0 obj\n${obj}\nendobj\n`; });
  const xref = Buffer.byteLength(data);
  data += `xref\n0 ${objects.length+1}\n0000000000 65535 f \n${offsets.slice(1).map(n=>`${String(n).padStart(10,'0')} 00000 n \n`).join('')}trailer\n<< /Size ${objects.length+1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(data);
}
