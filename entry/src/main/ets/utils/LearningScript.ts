// Fixed DOM-only reader: no network requests, hidden inputs, credentials or full HTML.
export const LEARNING_READ_SCRIPT: string = String.raw`(() => {
  const fail = code => JSON.stringify({readError: code});
  try {
    if (location.origin !== 'https://mooc1-api.chaoxing.com') return fail('origin');
    const kind = location.pathname === '/work/stu-work' ? 'homework' :
      location.pathname === '/exam-ans/exam/phone/examcode' ? 'exam' : '';
    if (!kind) return fail('path');
    if (document.readyState !== 'complete') return fail('loading');
    const rows = [];
    const cards = Array.from(document.querySelectorAll('li[data]'));
    for (const card of cards) {
      let target;
      try { target = new URL(card.getAttribute('data') || '', location.origin); } catch (_) { continue; }
      if (target.origin !== location.origin) continue;
      const recognized = kind === 'homework' ? target.pathname === '/mooc-ans/android/mtaskmsgspecial' :
        target.pathname === '/exam-ans/exam/phone/task-exam';
      if (!recognized) continue;
      const labels = [card, ...card.querySelectorAll('[aria-label]')].map(e => e.getAttribute('aria-label') || '');
      const label = labels.find(s => s.includes(kind === 'homework' ? '作业名称' : '考试名称'));
      if (!label) return fail('structure');
      const text = label.replace(/\s+/g, ' ').trim();
      let match;
      if (kind === 'homework') {
        match = /^作业名称[：:]?(.*?)作业状态[：:]?(.*?)所属课程[：:]?(.*?)(?:剩余时间[：:]?(.*))?$/.exec(text);
        if (!match) return fail('structure');
        rows.push({id: target.searchParams.get('taskrefId') || '', title: match[1].trim(),
          status: match[2].trim(), course: match[3].trim().replace(/^《|》$/g, ''), remaining: (match[4] || '').trim()});
      } else {
        match = /^考试名称[：:](.*?)[;；]\s*考试状态[：:](.*?)[;；]\s*(?:剩余时间[：:](.*))?$/.exec(text);
        if (!match) return fail('structure');
        rows.push({id: target.searchParams.get('taskrefId') || '', title: match[1].trim(),
          status: match[2].trim(), course: '', remaining: (match[3] || '').trim().replace(/[;；]$/, '')});
      }
      if (rows.length > 2000) return fail('size');
    }
    if (!rows.length) return fail('empty');
    return JSON.stringify({kind, rows});
  } catch (_) { return fail('structure'); }
})()`;
