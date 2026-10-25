const crc32 = bytes => {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
};

// Canvas otherwise writes 96 DPI. Preserve pixels and encode the requested print density.
export async function pngWithDensity(blob, dpi) {
  const source = new Uint8Array(await blob.arrayBuffer());
  const view = new DataView(source.buffer);
  const chunks = [source.subarray(0, 8)];
  const density = new Uint8Array(21), densityView = new DataView(density.buffer);
  densityView.setUint32(0, 9); density.set([112, 72, 89, 115], 4);
  densityView.setUint32(8, Math.round(dpi / .0254)); densityView.setUint32(12, Math.round(dpi / .0254));
  density[16] = 1; densityView.setUint32(17, crc32(density.subarray(4, 17)));
  for (let offset = 8; offset < source.length;) {
    const size = view.getUint32(offset), type = String.fromCharCode(...source.subarray(offset + 4, offset + 8));
    if (type !== 'pHYs') chunks.push(source.subarray(offset, offset + size + 12));
    if (type === 'IHDR') chunks.push(density);
    offset += size + 12;
  }
  return new Blob(chunks, { type: 'image/png' });
}
