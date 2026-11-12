// Fixed, read-only DOM extraction. Only visible timetable cells and term/filter controls.
// Never extracts document HTML, scripts, links, storage, hidden inputs or login fields.
export const SUST_READ_TABLE_SCRIPT: string = `(() => {
  if (location.origin !== 'https://bkjw.sust.edu.cn' || location.pathname !== '/eams/courseTableForStd.action') throw Error('page');
  const visible = e => e && e.getClientRects().length > 0;
  const kind = document.getElementById('courseTableType');
  const week = document.getElementById('startWeek');
  const table = document.getElementById('manualArrangeCourseTable');
  const terms = Array.from(document.querySelectorAll('input[type="text"][id^="semesterBar"][id$="Semester"]')).filter(e => visible(e) && /^\\d{4}-\\d{4}学年[12]学期$/.test(e.value));
  if (!visible(kind) || !visible(week) || !visible(table) || terms.length !== 1) throw Error('table');
  const headings = ['序号','课程代码','课程名称','学分','课程序号','教师','备注','操作'];
  const catalogs = Array.from(document.querySelectorAll('table')).filter(t => visible(t) && t.rows.length &&
    JSON.stringify(Array.from(t.rows[0].cells).map(c=>c.innerText.trim())) === JSON.stringify(headings));
  if (catalogs.length !== 1) throw Error('catalog');
  const weeks = Array.from(week.options).map(o=>o.text.trim()).filter(s=>/^第\\d+周$/.test(s));
  if (!weeks.every((s,i)=>s==='第'+(i+1)+'周')) throw Error('weeks');
  return JSON.stringify({kind:kind.selectedOptions[0].text.trim(),week:week.selectedOptions[0].text.trim(),
    semester:terms[0].value,weekCount:weeks.length,
    rows:Array.from(table.rows).map(r=>Array.from(r.cells).map(c=>({text:c.innerText.trim(),rowspan:c.rowSpan,colspan:c.colSpan}))),
    catalog:Array.from(catalogs[0].rows).map(r=>Array.from(r.cells).map((c,i)=>i>=6?'':c.innerText.trim()))
      .map((r,i)=>i===0?headings:r)});
})()`;
