import test from 'node:test';
import assert from 'node:assert/strict';
import { PILOT, CARD_BY_CODE } from '../../src/lib/card-generator/cardSchema.js';
import { artworkPrintResolution, cardReadiness, renderSignature } from '../../src/lib/card-generator/cardValidationService.js';
import { duplicateArtworkCodes } from '../../src/lib/card-generator/cardArtworkService.js';
import { checkExport } from '../../src/lib/card-generator/cardExportService.js';

const card = CARD_BY_CODE.get('COB-003');
const character = { url: '/fixture.png', sha256: 'a'.repeat(64), width: 1122, height: 793, scale: 1, fit: 'cover' };
const approved = () => {
  const art = { character: { ...character }, approval_status: 'approved', asset_status: 'verified' };
  art.render_receipt = renderSignature(card, art);
  return art;
};
const back = { asset_status: 'verified' };

test('current 1122 × 793 artwork meets 300 DPI without resizing or changing the design', () => {
  const before = structuredClone(character);
  const result = artworkPrintResolution(card, character);
  assert.equal(Math.floor(result.dpi), 460);
  assert.equal(result.sufficient, true);
  assert.deepEqual(character, before);
  assert.equal(cardReadiness(card, PILOT, approved(), back).ready, true);
  assert.doesNotThrow(() => checkExport(card, PILOT, approved(), back, false));
});

test('resolution follows chosen output DPI, physical size and zoom', () => {
  assert.equal(artworkPrintResolution(card, character, { dpi: 600 }).sufficient, false);
  assert.equal(artworkPrintResolution(card, character, { width: 126 }).sufficient, false);
  assert.equal(artworkPrintResolution(card, { ...character, scale: 2 }).sufficient, false);
  assert.equal(artworkPrintResolution(card, { ...character, x: 100, y: -20 }).dpi, artworkPrintResolution(card, character).dpi);
  assert.throws(() => checkExport(card, PILOT, approved(), back, false, { dpi: 600 }), /perlu 600 DPI/);
});

test('cover and contain use the rendered image scale, including extreme aspect ratios', () => {
  const wide = { ...character, width: 1800, height: 400 };
  assert.equal(artworkPrintResolution(card, wide).sufficient, false);
  assert.equal(artworkPrintResolution(card, { ...wide, fit: 'contain' }).sufficient, true);
  assert.equal(artworkPrintResolution(card, { ...wide, fit: 'contain', scale: 3 }).sufficient, false);
  for (const width of [0, -1, NaN, Infinity]) assert.equal(artworkPrintResolution(card, { ...character, width }).sufficient, false);
});

test('edition artwork resolution matches each native frame area', () => {
  const trial = artworkPrintResolution({ ...card, design_template: 'Trial Join' }, character);
  const winning = artworkPrintResolution({ ...card, design_template: 'Winning' }, character);
  assert.equal(trial.widthMm, 63);
  assert.ok(Math.abs(trial.heightMm - 94.5 * 1035 / 1536) < 1e-8);
  assert.ok(Math.abs(winning.widthMm - 63 * 952 / 1024) < 1e-8);
  assert.ok(Math.abs(winning.heightMm - 94.5 * 850 / 1536) < 1e-8);
  assert.ok(winning.dpi > trial.dpi);
});

test('adequate resolution still requires approval, verified assets and exact render receipt', () => {
  for (const patch of [{ approval_status: 'not_reviewed' }, { asset_status: 'unchecked' }, { render_receipt: null }]) {
    assert.equal(cardReadiness(card, PILOT, { ...approved(), ...patch }, back).ready, false);
  }
  const art = approved(); art.character.scale = 1.1;
  assert.equal(cardReadiness(card, PILOT, art, back).ready, false);
});

test('duplicate detection names affected cards and ignores unrelated duplicates', () => {
  const artworks = { A: { character }, B: { character: { ...character, url: '/another-path.png' } }, C: { character: { ...character, sha256: 'b'.repeat(64) } }, D: {} };
  assert.deepEqual(duplicateArtworkCodes(artworks, 'A'), ['B']);
  assert.deepEqual(duplicateArtworkCodes(artworks, 'B'), ['A']);
  assert.deepEqual(duplicateArtworkCodes(artworks, 'C'), []);
  assert.deepEqual(duplicateArtworkCodes(artworks, 'D'), []);
});
