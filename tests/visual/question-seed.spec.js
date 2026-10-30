import { test, expect } from '@playwright/test';
import { compileQuestions, imageUrl } from '../../scripts/questions/build-question-seed.mjs';
import { gradeWorkspace } from '../../src/lib/questions/blockGrading.js';
import { mockGameSetup } from '../fixtures/mockGameSetup.js';
import { battleEndpoint } from '../fixtures/mockPlayerBattle.js';

const questions = compileQuestions();
async function mockBank(page) {
  await mockGameSetup(page);
  await page.route(`${battleEndpoint}/rest/v1/coding_questions*`, route => {
    const id = new URL(route.request().url()).searchParams.get('id')?.replace('eq.', '');
    return route.fulfill({ json: id ? questions.find(q => q.payload.id === id)?.payload : questions.map(q => q.payload) });
  });
  await page.route(`${battleEndpoint}/rest/v1/coding_question_block_keys*`, route => {
    const id = new URL(route.request().url()).searchParams.get('question_id')?.replace('eq.', '');
    const q = questions.find(q => q.payload.id === id);
    return route.fulfill({ json: { solutions: q.solutions, grading: q.grading } });
  });
}
async function preview(page, q) {
  await page.goto(`/admin/questions/${q.payload.id}/edit`);
  await expect(page.getByPlaceholder('Apa yang terjadi setelah bendera hijau diklik?')).toHaveValue(q.question);
  await page.getByRole('button', { name: 'Buka preview interaktif' }).click();
  await expect(page.locator('.quiz-preview')).toBeVisible();
}

test('all seeded illustrations load and show readable code and Scratch blocks', async ({ page }) => {
  await mockBank(page);
  await page.goto('/admin/questions/add');
  const diagrams = questions.filter(q => q.diagram);
  await page.setContent(`<style>body{margin:24px;background:#eaf0f5;font-family:Arial}main{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}figure{margin:0;background:white;border:1px solid #c7d8e6;border-radius:12px;padding:16px}img{width:100%;height:265px;object-fit:contain}figcaption{font-size:14px;font-weight:bold;margin-bottom:15px;color:#163855}</style><main>${diagrams.map(q => `<figure><figcaption>${q.level} · ${q.topic}</figcaption><img src="${imageUrl(q)}" alt="${q.topic}"></figure>`).join('')}</main>`);
  await expect.poll(() => page.locator('img').evaluateAll(images => images.filter(img => img.complete && img.naturalWidth > 0).length)).toBe(12);
  await page.screenshot({ path: 'test-results/question-seed-images.png', fullPage: true });
});

test('HTML, CSS, and DOM answers match actual browser behavior', async ({ page }) => {
  for (const q of questions.filter(q => q.htmlCheck)) {
    const check = q.htmlCheck;
    await page.setContent(check.html);
    if (check.script) await page.addScriptTag({ content: check.script });
    if (check.click) {
      await expect(page.locator(check.selector), q.key).toBeEmpty();
      await page.locator(check.click).click();
    }
    const node = page.locator(check.selector);
    if (check.text) await expect(node, q.key).toHaveText(check.text);
    if (check.attribute) await expect(node, q.key).toHaveAttribute(check.attribute, check.value);
    if (check.property) await expect(node, q.key).toHaveCSS(check.property, check.value);
    if (check.width) expect((await node.boundingBox()).width, q.key).toBe(check.width);
  }
});

test('all 12 Scratch solutions survive Blockly serialization and pass the interactive preview', async ({ page }) => {
  test.setTimeout(120000);
  await mockBank(page);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  for (const q of questions.filter(q => q.mode === 'scratch_blocks')) {
    await preview(page, q);
    await expect(page.locator('.quiz-preview .blocklySvg')).toBeVisible();
    await page.getByRole('button', { name: 'Periksa program', exact: true }).click();
    await expect(page.locator('.quiz-preview .notice'), q.key).toContainText('Belum benar');
    const actual = await page.evaluate(async solution => {
      const module = await import('/node_modules/.vite/deps/blockly_core.js');
      const Blockly = module.default ?? module;
      const w = document.querySelector('.quiz-preview .block-workspace').__vueParentComponent.exposed.getWorkspace();
      Blockly.serialization.workspaces.load(solution, w);
      w.zoomToFit();
      return Blockly.serialization.workspaces.save(w);
    }, q.solutions[0]);
    expect(gradeWorkspace(actual, q.solutions, q.config, q.grading).correct, q.key).toBe(true);
    // Blockly queues change events; retry submission until the Vue model receives them.
    await expect(async () => {
      await page.getByRole('button', { name: 'Periksa program', exact: true }).click();
      await expect(page.locator('.quiz-preview .notice')).toContainText('Benar!');
    }).toPass({ timeout: 3000 });
  }
  await page.locator('.quiz-preview').screenshot({ path: 'test-results/question-seed-workspace.png' });
  expect(errors).toEqual([]);
});

test('seeded choice, image, bug, and ordering previews preserve answers and indentation', async ({ page }) => {
  await mockBank(page);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  for (const mode of ['choice', 'image_choice', 'find_bug']) {
    const q = questions.find(q => q.mode === mode && q.level === 'hard');
    await preview(page, q);
    const index = mode === 'find_bug' ? q.bugLine : 'ABCD'.indexOf(q.payload.correct_answer);
    const buttons = page.locator('.quiz-preview .preview-answers button');
    await buttons.nth((index + 1) % await buttons.count()).click();
    await expect(page.locator('.quiz-preview .notice')).toContainText('Belum benar');
    await buttons.nth(index).click();
    await expect(page.locator('.quiz-preview .notice')).toContainText('Benar!');
    if (mode === 'image_choice') await expect.poll(() => page.locator('.quiz-preview > img').evaluate(img => img.naturalWidth)).toBeGreaterThan(0);
  }
  const q = questions.find(q => q.level === 'hard' && q.mode === 'block_order' && q.category === 'python');
  await preview(page, q);
  for (let target = 0; target < q.blocks.length; target++) {
    const texts = await page.locator('.quiz-preview .block-text').allTextContents();
    let index = texts.indexOf(q.blocks[target]);
    expect(index).toBeGreaterThanOrEqual(target);
    while (index > target) {
      await page.locator('.quiz-preview').getByRole('button', { name: `Naikkan blok ${index + 1}`, exact: true }).click();
      index--;
    }
  }
  expect(await page.locator('.quiz-preview .block-text').allTextContents()).toEqual(q.blocks);
  await expect(page.locator('.quiz-preview .block-text').nth(3)).toHaveCSS('white-space', 'pre-wrap');
  await page.getByRole('button', { name: 'Periksa urutan', exact: true }).click();
  await expect(page.locator('.quiz-preview .notice')).toContainText('Benar!');
  await page.locator('.quiz-preview').screenshot({ path: 'test-results/question-seed-python.png' });
  const html = questions.find(q => q.mode === 'block_order' && q.category === 'html');
  await preview(page, html);
  await expect(page.locator('.quiz-preview .block-text').filter({ hasText: '<h1>' })).toHaveCount(1);
  await expect(page.locator('.quiz-preview .block-text h1')).toHaveCount(0);
  expect(errors).toEqual([]);
});
