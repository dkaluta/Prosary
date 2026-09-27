// Local research OCR only. The output is an unverified draft, never Scripture input.
// Usage: PROSARY_HEBREW_OCR_RUNTIME=/path/to/runtime node ocr-1maccabees-page.cjs IMAGE OUTPUT.txt [VOCABULARY.txt]
// Runtime must already contain node_modules/tesseract.js and heb.traineddata.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const hash = data => crypto.createHash('sha256').update(data).digest('hex');

(async () => {
  const runtime = process.env.PROSARY_HEBREW_OCR_RUNTIME;
  if (!runtime || !process.argv[2] || !process.argv[3]) throw new Error('Specify the local OCR runtime, image, and output text.');
  const model = fs.readFileSync(path.join(runtime, 'heb.traineddata'));
  const packagePath = path.join(runtime, 'node_modules', 'tesseract.js');
  const {createWorker} = require(packagePath);
  const version = require(path.join(packagePath, 'package.json')).version;
  const worker = await createWorker('heb', 1, {cachePath: runtime, cacheMethod: 'readOnly'});
  try {
    let vocabulary = null;
    if (process.argv[4]) {
      vocabulary = fs.readFileSync(process.argv[4], 'utf8');
      await worker.writeText('/1ma-user-words', vocabulary);
      // The dictionary path is an initialization parameter. Setting it after
      // initialization would not establish that the vocabulary was loaded.
      await worker.reinitialize('heb', 1, {user_words_file: '/1ma-user-words'});
    }
    await worker.setParameters({tessedit_pageseg_mode: '6', preserve_interword_spaces: '1'});
    const result = await worker.recognize(process.argv[2], {}, {text: true, blocks: true});
    const words = (result.data.blocks || []).flatMap(block => block.paragraphs.flatMap(paragraph =>
      paragraph.lines.flatMap(line => line.words.map(word => ({text: word.text, bbox: word.bbox,
        confidence: word.confidence})))));
    fs.writeFileSync(process.argv[3], result.data.text);
    console.log(JSON.stringify({engine: 'tesseract.js', version, language: 'heb', oem: 1, psm: 6,
      imageSHA256: hash(fs.readFileSync(process.argv[2])),
      modelSHA256: hash(model), vocabularySHA256: vocabulary ? hash(vocabulary) : null,
      confidence: result.data.confidence, text: result.data.text, words}));
  } finally {
    await worker.terminate();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
