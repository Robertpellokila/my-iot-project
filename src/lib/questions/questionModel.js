import { DEFAULT_BLOCK_CONFIG,DEFAULT_GRADING,EMPTY_WORKSPACE } from './scratchBlocks.js';
import { normalizeWorkspace,gradeWorkspace } from './blockGrading.js';
export const QUESTION_CATEGORIES = ['scratch','block_coding','programming_basics','programming','python','javascript','html','css','database','algorithm','general'];
export const QUIZ_MODES = [
  {id:'scratch_blocks',name:'Scratch workspace',description:'Susun blok yang tersambung, loop, kondisi, dan input.'},
  { id: 'choice', name: 'Pilihan ganda', description: 'Pertanyaan dengan empat pilihan jawaban.' },
  { id: 'image_choice', name: 'Baca gambar / Scratch', description: 'Upload potongan kode, lalu tanyakan hasilnya.' },
  { id: 'block_order', name: 'Susun blok', description: 'Pemain menyeret blok ke urutan yang benar.' },
  { id: 'find_bug', name: 'Cari kesalahan', description: 'Pemain memilih baris kode yang bermasalah.' },
];
export const codeLines = text => String(text ?? '').replace(/\\r\\n|\\n|\\r|\r\n?/g, '\n').split('\n').filter(line => line.trim());
export const blankQuestion = () => ({ question:'', mode:'choice', duration_seconds:null, block_config:structuredClone(DEFAULT_BLOCK_CONFIG), block_solutions:[structuredClone(EMPTY_WORKSPACE)], block_grading:{...DEFAULT_GRADING}, blocks:[], code_snippet:'', bug_line:0, option_a:'', option_b:'', option_c:'', option_d:'', correct_answer:'A', explanation:'', hint_1:'', hint_2:'', category:'scratch', difficulty:'easy', learning_topic:'', learning_url:'', is_active:true });

export function validateQuestion(draft, imageUrl = '') {
  const errors = [];
  if (!String(draft.question).trim()) errors.push('Tulis pertanyaannya terlebih dahulu.');
  if (!QUIZ_MODES.some(mode => mode.id === draft.mode)) errors.push('Pilih mode quiz yang tersedia.');
  if (draft.duration_seconds != null && (!Number.isInteger(Number(draft.duration_seconds)) || draft.duration_seconds < 10 || draft.duration_seconds > 600)) errors.push('Durasi harus 10–600 detik atau kosong untuk mengikuti Game Setup.');
  if (draft.mode === 'scratch_blocks') {
    try {
      normalizeWorkspace(draft.block_config.initial,draft.block_config);
      if(!draft.block_solutions?.length || draft.block_solutions.length>4) throw new Error('Isi 1–4 workspace jawaban.');
      for(const solution of draft.block_solutions) if(!normalizeWorkspace(solution,draft.block_config).length) throw new Error('Susun kunci jawaban terlebih dahulu.');
      if(draft.block_grading.numeric_tolerance<0 || draft.block_grading.numeric_tolerance>1000 || draft.block_grading.weight<1 || draft.block_grading.weight>100) throw new Error('Toleransi atau bobot nilai tidak valid.');
    } catch(error) { errors.push(error.message); }
  } else if (draft.mode === 'block_order') {
    if (draft.blocks.length < 2 || draft.blocks.length > 12) errors.push('Gunakan 2–12 blok.');
    if (draft.blocks.some(block => !String(block).trim() || String(block).length > 180)) errors.push('Setiap blok harus berisi 1–180 karakter.');
    if (new Set(draft.blocks.map(block => String(block).trim())).size !== draft.blocks.length) errors.push('Beri teks berbeda pada setiap blok agar urutannya tidak ambigu.');
  } else if (draft.mode === 'find_bug') {
    const lines = codeLines(draft.code_snippet);
    if (lines.length < 2 || lines.length > 4) errors.push('Gunakan 2–4 baris kode untuk mode cari kesalahan.');
    if (!Number.isInteger(Number(draft.bug_line)) || draft.bug_line < 0 || draft.bug_line >= lines.length) errors.push('Pilih baris yang bermasalah.');
  } else {
    const options = ['a','b','c','d'].map(letter => String(draft[`option_${letter}`] ?? '').trim());
    if (options.some(option => !option)) errors.push('Isi keempat pilihan jawaban.');
    if (new Set(options.map(option => option.toLowerCase())).size !== options.length) errors.push('Pilihan jawaban harus berbeda.');
    if (!['A','B','C','D'].includes(draft.correct_answer)) errors.push('Tentukan kunci jawaban A–D.');
    if (draft.mode === 'image_choice' && !imageUrl) errors.push('Upload gambar kode Scratch atau ilustrasi soal.');
  }
  if (draft.learning_url && !/^https?:\/\//i.test(draft.learning_url)) errors.push('Tautan materi harus diawali https:// atau http://.');
  return errors;
}

export function shuffleItems(items, random = Math.random) {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

export function questionPayload(draft, imageUrl = null) {
  const errors = validateQuestion(draft, imageUrl);
  if (errors.length) throw new Error(errors[0]);
  if(draft.mode==='scratch_blocks') return {question:draft.question.trim(),question_type:'scratch_blocks',image_url:imageUrl,block_config:draft.block_config,duration_seconds:draft.duration_seconds||null,category:draft.category,difficulty:draft.difficulty,is_active:draft.is_active,explanation:draft.explanation,hint_1:draft.hint_1,hint_2:draft.hint_2,learning_topic:draft.learning_topic,learning_url:draft.learning_url,correct_answer:'A',option_a:'Program benar',option_b:'Program belum sesuai',option_c:'',option_d:'',blocks:[],correct_sequence:[]};
  const blockMode = draft.mode === 'block_order';
  const bugMode = draft.mode === 'find_bug';
  // Persist a shuffled block pool; its visible order must not reveal the key.
  const pool = blockMode ? shuffleItems(draft.blocks.map((text, id) => ({ text:text.trimEnd(), id }))) : [];
  if (pool.length > 1 && pool.every((block, i) => block.id === i)) pool.push(pool.shift());
  const payload = {
    question:draft.question.trim(), question_type:blockMode ? 'block_order' : bugMode ? 'find_bug' : 'choice',
    blocks:pool.map(block => block.text), correct_sequence:pool.map((_, id) => pool.findIndex(block => block.id === id)),
    code_snippet:bugMode ? codeLines(draft.code_snippet).join('\n') : draft.code_snippet.trim() || null,
    bug_line:bugMode ? Number(draft.bug_line) : null, image_url:imageUrl || null,
    correct_answer:blockMode ? 'A' : bugMode ? String.fromCharCode(65 + Number(draft.bug_line)) : draft.correct_answer,
    explanation:draft.explanation.trim() || null, hint_1:draft.hint_1.trim() || null, hint_2:draft.hint_2.trim() || null,
    category:draft.category, difficulty:draft.difficulty, level:draft.difficulty, is_active:!!draft.is_active,
    learning_topic:draft.learning_topic.trim() || draft.category, learning_url:draft.learning_url.trim() || null,
  };
  ['a','b','c','d'].forEach((letter, index) => {
    payload[`option_${letter}`] = blockMode ? ['Urutan benar','Urutan belum benar','Coba lagi','Belum disusun'][index]
      : bugMode ? `Baris ${index + 1}` : draft[`option_${letter}`].trim();
  });
  payload.duration_seconds=draft.duration_seconds||null;
  return payload;
}

export function questionDraft(row) {
  const draft = { ...blankQuestion(), ...row, mode:row.question_type === 'choice' || !row.question_type ? row.image_url ? 'image_choice' : 'choice' : row.question_type };
  for (const key of ['code_snippet','explanation','hint_1','hint_2','learning_topic','learning_url']) draft[key] = row[key] ?? '';
  const blocks = Array.isArray(row.blocks) ? row.blocks : [];
  const sequence = Array.isArray(row.correct_sequence) ? row.correct_sequence : [];
  draft.blocks = sequence.length === blocks.length && sequence.every(index => Number.isInteger(index) && index >= 0 && index < blocks.length) && new Set(sequence).size === blocks.length
    ? sequence.map(index => blocks[index]) : blocks;
  return draft;
}

export function checkPreviewAnswer(question, answer) {
  if(question.question_type==='scratch_blocks') return gradeWorkspace(answer.workspace,question.block_solutions,question.block_config,question.block_grading).correct;
  if (question.question_type === 'block_order') return Array.isArray(answer.order) && answer.order.length === question.correct_sequence.length && answer.order.every((index, position) => index === question.correct_sequence[position]);
  const index = question.question_type === 'find_bug' ? answer.line_index : answer.answer_index;
  return Number.isInteger(index) && index >= 0 && index < 4 && String.fromCharCode(65 + index) === question.correct_answer;
}

export function blockTone(text) {
  if (/bendera|flag|ketika|when/i.test(text)) return 'event';
  if (/ulangi|repeat|jika|if|else|tunggu|wait|selesai|end/i.test(text)) return 'control';
  if (/katakan|say|kostum|costume|tampilkan|show/i.test(text)) return 'looks';
  if (/skor|score|ubah|set|variable/i.test(text)) return 'variable';
  return 'motion';
}
