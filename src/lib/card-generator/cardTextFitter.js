// Use the same font as the SVG when running in the browser. The fallback keeps
// the Node catalog/proof tools usable; SVG text boxes also enforce their width.
let metricsContext;
export function textWidth(text, size, { weight = 400, family = 'Arial', spacing = 0 } = {}) {
  const value = String(text);
  if (typeof document !== 'undefined') {
    metricsContext ??= document.createElement('canvas').getContext('2d');
    if (metricsContext) {
      metricsContext.font = `${weight} ${size}px ${family}`;
      return metricsContext.measureText(value).width + Math.max(0, value.length - 1) * spacing;
    }
  }
  return [...value].reduce((sum, letter) => sum +
    (/[MW@%]/.test(letter) ? .86 : /[ilI1.,:;'!| ]/.test(letter) ? .29 : /[A-Z0-9]/.test(letter) ? .65 : .54) * size, 0) * (weight >= 700 ? 1.08 : 1) + Math.max(0, value.length - 1) * spacing;
}
export function wrapText(text, width, size, measure = textWidth) {
  const lines = []; let line = '';
  const tokens = String(text).split(/\s+/).filter(Boolean);
  const words = [];
  for (let index=0;index<tokens.length;index++) {
    const token=tokens[index], next=tokens[index+1];
    // Keep cooldowns and AP/HP amounts readable as one unit at a line break.
    if ((token==='CD' && /^\d+[.,;:]?$/.test(next ?? '')) || (/^[+−-]?\d+$/.test(token) && /^(HP|AP|DEF|ATK)[.,;:]?$/.test(next ?? ''))) words.push(`${token} ${tokens[++index]}`);
    else words.push(token);
  }
  for (const word of words) {
    const next = line ? `${line} ${word}` : word;
    if (line && measure(next, size) > width) { lines.push(line); line = word; } else line = next;
  }
  if (line) lines.push(line);
  return lines;
}
export function fitText(text, width, maxLines, sizes = [21, 20, 19, 18], font = {}) {
  const measure = (value, size) => textWidth(value, size, font);
  for (const size of sizes) {
    const lines = wrapText(text, width, size, measure);
    if (lines.length <= maxLines && lines.every(line => measure(line, size) <= width)) return { lines, size, overflow: false, width };
  }
  const size = sizes.at(-1);
  return { lines: wrapText(text, width, size, measure), size, overflow: true, width };
}
