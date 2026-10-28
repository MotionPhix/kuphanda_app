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
      { text: 'Your school library, online', y: 694, size: 14 },
      { text: 'How to use this app', y: 640, size: 17, bold: true },
      { text: 'Browse the catalogue for Forms 1-4, subscribe for full access,', y: 606, size: 11 },
      { text: 'and download the documents you need for reading offline.', y: 590, size: 11 },
      { text: 'Your bookmarks, notes and reading progress stay on this phone.', y: 574, size: 11 },
      { text: '1. Find a document', y: 528, size: 14, bold: true },
      { text: 'Open Library and filter by form, subject or document type.', y: 506, size: 11 },
      { text: 'Past papers, marking schemes, notes and study guides share one', y: 490, size: 11 },
      { text: 'catalogue. Free and premium documents are labelled clearly.', y: 474, size: 11 },
      { text: '2. Unlock a document', y: 434, size: 14, bold: true },
      { text: 'Free papers open immediately. Premium papers need a weekly,', y: 412, size: 11 },
      { text: 'monthly or term pass, a school licence, or a single purchase.', y: 396, size: 11 },
      { text: 'Prices are shown in MWK and paid through PayChangu.', y: 380, size: 11 },
      { text: '3. Download for offline', y: 340, size: 14, bold: true },
      { text: 'On a document you can access, tap Download. The file is checked', y: 318, size: 11 },
      { text: 'and stored on the phone. When the library publishes a newer', y: 302, size: 11 },
      { text: 'version, the app offers an update and keeps the old copy until', y: 286, size: 11 },
      { text: 'the new download succeeds.', y: 270, size: 11 },
      { text: '4. Read anywhere', y: 230, size: 14, bold: true },
      { text: 'Turn pages, add bookmarks and write notes. Progress is saved', y: 208, size: 11 },
      { text: 'as you read and syncs when you are back online.', y: 192, size: 11 },
      { text: 'Kuphanda - built for Malawian secondary schools.', y: 110, size: 9 },
    ],
  },
  {
    lines: [
      { text: 'Managing access and downloads', y: 720, size: 20, bold: true },
      { text: 'Free and premium', y: 682, size: 14, bold: true },
      { text: 'Free papers stay open to everyone. Premium papers require an', y: 660, size: 11 },
      { text: 'active subscription, a single-document purchase or a school', y: 644, size: 11 },
      { text: 'licence. Your current access is shown under Subscription.', y: 628, size: 11 },
      { text: 'Paying with PayChangu', y: 590, size: 14, bold: true },
      { text: 'Choose a plan or buy one paper, then finish the payment in the', y: 568, size: 11 },
      { text: 'browser with mobile money or a card. Return to the app and tap', y: 552, size: 11 },
      { text: '"I have paid" or reopen Subscription to confirm it.', y: 536, size: 11 },
      { text: 'Receipts and references are listed under Payment history.', y: 520, size: 11 },
      { text: 'Downloads and updates', y: 480, size: 14, bold: true },
      { text: 'Downloaded files appear in My documents with their version.', y: 458, size: 11 },
      { text: 'When a newer version is published, download the update from', y: 442, size: 11 },
      { text: 'the document screen. Remove a download to free up space; your', y: 426, size: 11 },
      { text: 'notes and progress are kept.', y: 410, size: 11 },
      { text: 'If a pass expires or is revoked, the next sync removes files that', y: 394, size: 11 },
      { text: 'are no longer covered and asks you to subscribe again.', y: 378, size: 11 },
      { text: 'Personal files', y: 338, size: 14, bold: true },
      { text: 'Use My documents > Import for a PDF you own that is not in the', y: 316, size: 11 },
      { text: 'catalogue. Give it a title, subject, form and type.', y: 300, size: 11 },
      { text: 'Privacy and copyright', y: 260, size: 14, bold: true },
      { text: 'Only library-supplied papers are published to everyone. Imported', y: 238, size: 11 },
      { text: 'files stay on your phone. Past papers and textbooks remain the', y: 222, size: 11 },
      { text: 'property of their publishers and MANEB.', y: 206, size: 11 },
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
