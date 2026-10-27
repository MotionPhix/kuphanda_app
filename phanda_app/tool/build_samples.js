// Builds the two sample PDFs that ship with the app.
// They are Kuphanda's own onboarding/planner documents (not exam material),
// so they are safe to bundle and let a new learner try the reader immediately.
const fs = require('fs');
const path = require('path');

function escapePdf(text) {
  return text.replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');
}

function buildPdf(pages) {
  const objects = [];
  const add = (body) => {
    objects.push(body);
    return objects.length; // 1-based object number
  };

  // 1 catalog (placeholder), 2 pages (placeholder), 3.. fonts
  const catalogNum = add('');
  const pagesNum = add('');
  const fontRegular = add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>');
  const fontBold = add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>');

  const pageNums = [];
  for (const page of pages) {
    const content = page.lines
      .map((line, index) => {
        const size = line.size || 11;
        const font = line.bold ? '/F2' : '/F1';
        const gap = line.gap === undefined ? 6 : line.gap;
        const x = line.x === undefined ? 56 : line.x;
        return `BT ${font} ${size} Tf ${x} ${line.y} Td (${escapePdf(line.text)}) Tj ET\n` +
          (index < page.lines.length - 1 ? '' : '') +
          (gap ? '' : '');
      })
      .join('');

    const stream = `q 0.85 0.93 0.88 rg 0 782 612 10 re f Q\n` + content;
    const contentNum = add(`<< /Length ${Buffer.byteLength(stream, 'latin1')} >>\nstream\n${stream}\nendstream`);
    const pageNum = add(
      `<< /Type /Page /Parent ${pagesNum} 0 R /MediaBox [0 0 612 792] ` +
      `/Resources << /Font << /F1 ${fontRegular} 0 R /F2 ${fontBold} 0 R >> >> ` +
      `/Contents ${contentNum} 0 R >>`,
    );
    pageNums.push(pageNum);
  }

  objects[catalogNum - 1] = `<< /Type /Catalog /Pages ${pagesNum} 0 R >>`;
  objects[pagesNum - 1] =
    `<< /Type /Pages /Kids [${pageNums.map((n) => `${n} 0 R`).join(' ')}] /Count ${pageNums.length} >>`;

  let pdf = '%PDF-1.4\n%\xE2\xE3\xCF\xD3\n';
  const offsets = [0];
  objects.forEach((body, index) => {
    offsets.push(Buffer.byteLength(pdf, 'latin1'));
    pdf += `${index + 1} 0 obj\n${body}\nendobj\n`;
  });

  const xrefOffset = Buffer.byteLength(pdf, 'latin1');
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (let index = 1; index <= objects.length; index += 1) {
    pdf += `${String(offsets[index]).padStart(10, '0')} 00000 n \n`;
  }
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root ${catalogNum} 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`;
  return Buffer.from(pdf, 'latin1');
}

const quickStart = [
  {
    lines: [
      { text: 'KUPHANDA', y: 720, size: 26, bold: true },
      { text: 'Your offline school library', y: 694, size: 14 },
      { text: 'How to use this app', y: 640, size: 17, bold: true },
      { text: 'Kuphanda keeps the documents you need for Forms 1-4 on your', y: 606, size: 11 },
      { text: 'phone, so a weak signal or a flat battery never stops a study', y: 590, size: 11 },
      { text: 'session. Everything you highlight, bookmark or import stays on', y: 574, size: 11 },
      { text: 'this device.', y: 558, size: 11 },
      { text: '1. Find a document', y: 512, size: 14, bold: true },
      { text: 'Open Library and filter by form, subject or document type.', y: 490, size: 11 },
      { text: 'Past papers, marking schemes, notes and syllabi all live in the', y: 474, size: 11 },
      { text: 'same catalogue. Study guides are readable straight away.', y: 458, size: 11 },
      { text: '2. Add the file', y: 418, size: 14, bold: true },
      { text: 'Catalogue records describe a document; they do not contain the', y: 396, size: 11 },
      { text: 'file. Tap "Attach PDF" and choose the official paper from your', y: 380, size: 11 },
      { text: 'device. Kuphanda copies it into its own folder, so the original', y: 364, size: 11 },
      { text: 'can be deleted safely.', y: 348, size: 11 },
      { text: '3. Read and record progress', y: 308, size: 14, bold: true },
      { text: 'Turn pages, add bookmarks and write a note on any page. Your', y: 286, size: 11 },
      { text: 'place, pages read and study minutes are saved automatically.', y: 270, size: 11 },
      { text: 'Progress is what your teacher sees against a class assignment.', y: 254, size: 11 },
      { text: '4. Keep working offline', y: 214, size: 14, bold: true },
      { text: 'There is no login wall and no connection requirement. The app', y: 192, size: 11 },
      { text: 'never uploads your notes unless you connect a school account.', y: 176, size: 11 },
      { text: 'Kuphanda - built for Malawian secondary schools.', y: 110, size: 9 },
    ],
  },
  {
    lines: [
      { text: 'Managing your documents', y: 720, size: 20, bold: true },
      { text: 'Where files live', y: 682, size: 14, bold: true },
      { text: 'Imported PDFs are copied into the app private folder. Nothing is', y: 660, size: 11 },
      { text: 'moved or deleted from where you picked it. Removing a document', y: 644, size: 11 },
      { text: 'from Kuphanda deletes only the app copy.', y: 628, size: 11 },
      { text: 'Attaching a file to a catalogue record', y: 590, size: 14, bold: true },
      { text: '1. Open the record from Library.', y: 568, size: 11 },
      { text: '2. Tap Attach PDF and pick the file.', y: 552, size: 11 },
      { text: '3. Kuphanda verifies it is a PDF, stores the size and page count,', y: 536, size: 11 },
      { text: '   and marks the record as available offline.', y: 520, size: 11 },
      { text: 'Importing a document that is not in the catalogue', y: 482, size: 14, bold: true },
      { text: 'Use My documents > Import PDF. Give it a title, subject, form and', y: 460, size: 11 },
      { text: 'type so it can be found by search and used in assignments.', y: 444, size: 11 },
      { text: 'Bookmarks and notes', y: 406, size: 14, bold: true },
      { text: 'Bookmarks mark a page. Notes are text you attach to a page, for', y: 384, size: 11 },
      { text: 'example a worked correction or a question for your teacher.', y: 368, size: 11 },
      { text: 'Both appear in the document detail screen and in My documents.', y: 352, size: 11 },
      { text: 'Storage', y: 314, size: 14, bold: true },
      { text: 'The storage card shows how much space Kuphanda is using. If the', y: 292, size: 11 },
      { text: 'phone is full, remove papers you have finished; your progress and', y: 276, size: 11 },
      { text: 'notes are kept even when the file is removed.', y: 260, size: 11 },
      { text: 'A note on copyright', y: 222, size: 14, bold: true },
      { text: 'Only add documents you are allowed to use. Past papers and', y: 200, size: 11 },
      { text: 'textbooks remain the property of their publishers and MANEB.', y: 184, size: 11 },
    ],
  },
];

const planner = [
  {
    lines: [
      { text: 'WEEKLY STUDY PLANNER', y: 720, size: 22, bold: true },
      { text: 'Print this page or copy the blocks into your exercise book.', y: 694, size: 11 },
      { text: 'Week beginning: ____________________', y: 650, size: 12 },
      { text: 'Exam target:        JCE  /  MSCE        Year: ________', y: 628, size: 12 },
      { text: 'MONDAY', y: 586, size: 12, bold: true },
      { text: 'Focus subject: ______________________________', y: 566, size: 11 },
      { text: 'Pages / questions: ___________________________', y: 548, size: 11 },
      { text: 'TUESDAY', y: 512, size: 12, bold: true },
      { text: 'Focus subject: ______________________________', y: 492, size: 11 },
      { text: 'Pages / questions: ___________________________', y: 474, size: 11 },
      { text: 'WEDNESDAY', y: 438, size: 12, bold: true },
      { text: 'Focus subject: ______________________________', y: 418, size: 11 },
      { text: 'Pages / questions: ___________________________', y: 400, size: 11 },
      { text: 'THURSDAY', y: 364, size: 12, bold: true },
      { text: 'Focus subject: ______________________________', y: 344, size: 11 },
      { text: 'Pages / questions: ___________________________', y: 326, size: 11 },
      { text: 'FRIDAY', y: 290, size: 12, bold: true },
      { text: 'Focus subject: ______________________________', y: 270, size: 11 },
      { text: 'Pages / questions: ___________________________', y: 252, size: 11 },
      { text: 'SATURDAY', y: 216, size: 12, bold: true },
      { text: 'Past paper under timed conditions: ____________', y: 196, size: 11 },
      { text: 'SUNDAY', y: 160, size: 12, bold: true },
      { text: 'Review mistakes from this week: _______________', y: 140, size: 11 },
    ],
  },
  {
    lines: [
      { text: 'Before you start', y: 720, size: 18, bold: true },
      { text: 'Pick the paper before you sit down. Decide how many pages you', y: 694, size: 11 },
      { text: 'will read and what you will do with them. A short, finished block', y: 678, size: 11 },
      { text: 'beats a long, abandoned one.', y: 662, size: 11 },
      { text: 'A 40-minute block', y: 624, size: 14, bold: true },
      { text: '5 min   Recall what you already know about the topic.', y: 602, size: 11 },
      { text: '20 min  Read actively: one paragraph, then close the page and', y: 586, size: 11 },
      { text: '        say it back in your own words.', y: 570, size: 11 },
      { text: '10 min  Answer two past-paper questions without notes.', y: 554, size: 11 },
      { text: '5 min   Mark them and write the correction in your own words.', y: 538, size: 11 },
      { text: 'Marking your own work', y: 500, size: 14, bold: true },
      { text: 'Use the marking scheme, not the model answer, to award marks.', y: 478, size: 11 },
      { text: 'Write down every mark you lost and why: knowledge, method, or', y: 462, size: 11 },
      { text: 'careless slip. Method marks are the quickest to recover.', y: 446, size: 11 },
      { text: 'Weekly review', y: 408, size: 14, bold: true },
      { text: 'Which subject got the least time? ______________________', y: 386, size: 11 },
      { text: 'Which topic still feels unclear? ________________________', y: 368, size: 11 },
      { text: 'What will you do differently next week? ________________', y: 350, size: 11 },
      { text: 'Ask your teacher about one thing you could not resolve.', y: 312, size: 11 },
      { text: 'Kuphanda - study planner', y: 110, size: 9 },
    ],
  },
];

const dir = path.join(__dirname, '..', 'assets', 'samples');
fs.mkdirSync(dir, { recursive: true });
fs.writeFileSync(path.join(dir, 'kuphanda-quick-start.pdf'), buildPdf(quickStart));
fs.writeFileSync(path.join(dir, 'weekly-study-planner.pdf'), buildPdf(planner));
console.log('Wrote sample PDFs to', dir);
