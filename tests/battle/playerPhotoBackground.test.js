import {test} from 'node:test';import assert from 'node:assert/strict';
import {foregroundAlpha} from '../../src/lib/playerPhotoBackground.js';
test('background mask is transparent while high-confidence person pixels remain opaque',()=>{assert.equal(foregroundAlpha(0),0);assert.equal(foregroundAlpha(.1),0);assert.equal(foregroundAlpha(.9),255);assert.equal(foregroundAlpha(1),255);});
test('confidence edges soften smoothly, stay bounded and are monotone',()=>{let previous=0;for(let i=-10;i<=110;i++){const alpha=foregroundAlpha(i/100);assert.ok(Number.isInteger(alpha)&&alpha>=0&&alpha<=255);assert.ok(alpha>=previous);previous=alpha;}assert.ok(foregroundAlpha(.5)>0&&foregroundAlpha(.5)<255);});
