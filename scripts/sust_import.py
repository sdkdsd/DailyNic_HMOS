#!/usr/bin/env python3
"""Offline SUST visible-table converter. Never connects to a school or reads credentials.

Input: rendered/saved HTML, or a JSON snapshot containing only visible table cells.
Output: a preview and an append-only DailyNic schedule backup, in a NEW directory.
Unknown formats fail closed. Real student files belong in private-data/, never tests/.
"""
import argparse
import copy
from datetime import datetime, timezone, timedelta
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
HEADERS = ['节次/周次'] + ['星期' + day for day in '一二三四五六日']
PERIODS = ['第' + n + '节' for n in ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一']]
CATALOG = ['序号', '课程代码', '课程名称', '学分', '课程序号', '教师', '备注', '操作']


class ImportError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ImportError(message)


class VisibleTables(HTMLParser):
    """Extract only table cells; scripts, inputs and hidden fields are never executed."""
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.tables = []
        self.stack = []
        self.suppressed = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ('script', 'style'):
            self.suppressed += 1
        if self.suppressed:
            return
        if tag == 'table':
            table = {'id': attrs.get('id', ''), 'rows': [], 'cell': None}
            self.tables.append(table)
            self.stack.append(table)
        elif self.stack:
            table = self.stack[-1]
            if tag == 'tr':
                table['rows'].append([])
                table['cell'] = None
            elif tag in ('td', 'th'):
                require(bool(table['rows']), '表格缺少行')
                try:
                    cell = {'text': '', 'rowspan': int(attrs.get('rowspan', '1')),
                            'colspan': int(attrs.get('colspan', '1'))}
                except ValueError:
                    raise ImportError('表格合并范围无效') from None
                table['rows'][-1].append(cell)
                table['cell'] = cell
            elif tag in ('br', 'p', 'div') and table['cell'] is not None:
                table['cell']['text'] += '\n'

    def handle_endtag(self, tag):
        if tag in ('script', 'style'):
            self.suppressed = max(0, self.suppressed - 1)
            return
        if self.suppressed or not self.stack:
            return
        if tag == 'table':
            self.stack.pop()
        elif tag in ('td', 'th', 'tr'):
            self.stack[-1]['cell'] = None
        elif tag in ('p', 'div') and self.stack[-1]['cell'] is not None:
            self.stack[-1]['cell']['text'] += '\n'

    def handle_data(self, data):
        if not self.suppressed and self.stack and self.stack[-1]['cell'] is not None:
            self.stack[-1]['cell']['text'] += data


def load_table(path, kind, semester):
    require(path.stat().st_size <= 5 * 1024 * 1024, '文件不得超过 5 MiB')
    text = path.read_text(encoding='utf-8-sig')
    if path.suffix.lower() == '.json':
        data = json.loads(text)
        require(isinstance(data, dict), '课表文件结构无效')
        require(data.get('kind') == kind, '课表类型与文件不一致')
        require(data.get('week') == '全部', '必须选择全部教学周后保存')
        require(data.get('semester') == semester, '学年学期不一致')
        return data
    require(path.suffix.lower() in ('.html', '.htm'), '只支持 UTF-8 HTML 或可见表格 JSON；不支持 PDF/Excel')
    parser = VisibleTables()
    parser.feed(text)
    grids = [t for t in parser.tables if t['id'] == 'manualArrangeCourseTable']
    catalogs = [t for t in parser.tables if t['rows'] and
                [c['text'].strip() for c in t['rows'][0]] == CATALOG]
    require(len(grids) == 1 and len(catalogs) == 1, '缺少唯一课表网格或课程列表；不执行网页脚本')
    # HTML/print views may omit term/filter controls. CLI requires explicit confirmation.
    return {'kind': kind, 'week': '全部', 'semester': semester, 'rows': grids[0]['rows'],
            'catalog': [[c['text'].strip() for c in r] for r in catalogs[0]['rows']]}


def weeks(expression, maximum):
    expression = expression.strip().replace('（', '(').replace('）', ')')
    expression = expression.replace('–', '-').replace('～', '-').replace('~', '-')
    expression = re.sub(r'\s*([-()])\s*', r'\1', expression)
    result = set()
    for token in re.split(r'[,，、\s]+', expression):
        match = re.fullmatch(r'(\d+)(?:-(\d+))?(?:周)?(?:\(([单双])(?:周)?\))?', token)
        require(match is not None, '无法识别周次表达式')
        start = int(match[1])
        end = int(match[2] or match[1])
        require(1 <= start <= end <= maximum, '周次超出校历范围或倒序')
        result.update(w for w in range(start, end + 1)
                      if not match[3] or w % 2 == (1 if match[3] == '单' else 0))
    require(bool(result), '周次不能为空')
    return sorted(result)


def location(text):
    # The real multi-course cell omits one outer closing parenthesis. A classroom
    # code is presentation metadata; only strip the observed, strictly bounded suffix.
    match = re.fullmatch(r'(.+?)\([A-Za-z0-9-]+\)\)?', text)
    if match:
        return match[1].strip()
    require(text.endswith(')') and '(' not in text, '教室格式未知，请人工核对')
    return text[:-1].strip()


def parse_table(data, max_weeks=20, max_period=8):
    require(data.get('kind') in ('学生课表', '班级课表') and data.get('week') == '全部', '需要全部周的学生或班级课表')
    catalog = data.get('catalog')
    require(isinstance(catalog, list) and catalog and catalog[0] == CATALOG, '课程列表表头不匹配')
    lookup = {}
    for row in catalog[1:]:
        require(isinstance(row, list) and len(row) == 8 and all(isinstance(s, str) for s in row), '课程列表行无效')
        code = row[4].strip()
        require(re.fullmatch(r'[A-Za-z0-9]+\.[A-Za-z0-9]+', code) and code not in lookup, '课程序号无效或重复')
        require(bool(row[2].strip()) and re.fullmatch(r'\d+(?:\.\d+)?', row[3]), '课程名或学分无效')
        lookup[code] = row
    rows = data.get('rows')
    require(isinstance(rows, list) and len(rows) == 12, '课表须包含完整的星期表头及第1–11节')
    require([c.get('text', '').strip() for c in rows[0]] == HEADERS and
            all(c.get('colspan') == c.get('rowspan') == 1 for c in rows[0]), '星期表头不匹配')
    occupied = set()
    courses, cancelled = [], []
    seen_catalog = set()
    for period, row in enumerate(rows[1:], 1):
        require(isinstance(row, list) and row and row[0].get('text', '').strip() == PERIODS[period - 1]
                and row[0].get('colspan') == row[0].get('rowspan') == 1, '节次标签或顺序错误')
        column = 1
        for cell in row[1:]:
            while (period, column) in occupied:
                column += 1
            span = cell.get('rowspan')
            require(type(span) is int and 1 <= span <= 11 and period + span <= 12
                    and cell.get('colspan') == 1 and column <= 7, '课表网格或合并单元格无效')
            for p in range(period, period + span):
                require((p, column) not in occupied, '课表合并单元格重叠')
                occupied.add((p, column))
            require(isinstance(cell.get('text'), str), '课表单元格须为文本')
            lines = [line.strip() for line in cell['text'].splitlines() if line.strip()]
            current = None
            has_session = False
            for line in lines:
                header = re.fullmatch(r'(.+)\(([A-Za-z0-9]+\.[A-Za-z0-9]+)\)(?:\s*\(([^()]*)\))?', line)
                if header:
                    require(current is None or has_session, '课程缺少周次教室行')
                    code = header[2]
                    require(code in lookup and header[1] == lookup[code][2], '课表与课程列表不一致')
                    teacher = header[3] or ''
                    require(teacher == lookup[code][5], '教师与课程列表不一致')
                    current = {'name': header[1], 'teacher': teacher, 'id': code,
                               'credits': lookup[code][3], 'dayOfWeek': column % 7,
                               'timeSpan': list(range(period, period + span)),
                               'color': '#FF6487B5', 'priority': 5}
                    seen_catalog.add(code)
                    has_session = False
                else:
                    match = re.fullmatch(r'\(([\d\s,，、()（）单双周\-–～~]+),(.+)', line)
                    require(current is not None and match is not None, '课表内容未知；拒绝部分导入')
                    record = dict(current, weekOfTerm=weeks(match[1], max_weeks), location=location(match[2]))
                    has_session = True
                    if record['location'] == '停课':
                        cancelled.append(record)
                    else:
                        require(period + span - 1 <= max_period, '课程超出已确认作息节次；请核对，不推算晚课')
                        require(bool(record['location']), '上课地点为空')
                        courses.append(record)
            require(current is None or has_session, '课程缺少周次教室行')
            column += 1
        require(all((period, c) in occupied for c in range(1, 8)), '课表行不完整，不能推测星期')
    require(courses and seen_catalog == set(lookup), '课程列表存在网格未安排课程，需人工核对')
    # Explicit cancellations remove only matching course/day/period weeks.
    for stopped in cancelled:
        for course in courses:
            if slot_key(course) == slot_key(stopped):
                course['weekOfTerm'] = sorted(set(course['weekOfTerm']) - set(stopped['weekOfTerm']))
    return [c for c in courses if c['weekOfTerm']], cancelled


def slot_key(course):
    return course['id'], course['dayOfWeek'], tuple(course['timeSpan'])


def exact_key(course):
    return slot_key(course) + (tuple(course['weekOfTerm']), course['location'], course['teacher'])


def merge_tables(student, classroom, cancelled, excluded):
    result = copy.deepcopy(student)
    additions, duplicates, conflicts, omissions = [], [], [], []
    for extra in classroom:
        if extra['id'] in excluded:
            omissions.append(extra)
        elif any(exact_key(c) == exact_key(extra) for c in result):
            duplicates.append(extra)
        else:
            # A different classroom/title/teacher for overlapping time is not a duplicate.
            clash = any(c['dayOfWeek'] == extra['dayOfWeek'] and
                        set(c['timeSpan']) & set(extra['timeSpan']) and
                        set(c['weekOfTerm']) & set(extra['weekOfTerm']) for c in result)
            if clash:
                conflicts.append(extra)
            else:
                result.append(copy.deepcopy(extra))
                additions.append(extra)
    for stopped in cancelled:
        for course in result:
            if slot_key(course) == slot_key(stopped):
                course['weekOfTerm'] = sorted(set(course['weekOfTerm']) - set(stopped['weekOfTerm']))
    return [c for c in result if c['weekOfTerm']], {'class_additions': additions,
            'duplicates': duplicates, 'conflicts_not_imported': conflicts,
            'excluded_not_imported': omissions, 'cancelled_not_imported': cancelled}


def preset():
    text = (ROOT / 'entry/src/main/ets/utils/SustCalendar.ts').read_text(encoding='utf-8')
    def read(name):
        match = re.search(r'export const ' + name + r": string = '([^']+)';", text)
        require(match is not None, '缺少已确认的作息常量')
        return [line.split('-') for line in match[1].split('\\n')]
    return read('SUST_EARLY_PERIODS'), read('SUST_LATE_PERIODS')


def backup(courses, semester, first_monday, maximum, periods, summer):
    date = datetime.strptime(first_monday, '%Y-%m-%d').replace(tzinfo=timezone(timedelta(hours=8)))
    require(date.weekday() == 0, '学期首日必须为周一')
    now = int(datetime.now(timezone.utc).timestamp() * 1000)
    return {'exportTime': now // 1000, 'scheduleVersion': 'sust-xian-2-seasonal',
            'periods': periods, 'summerPeriods': summer, 'defaultSemester': 0,
            'semesters': [{'attribute': {'name': semester + '（本地核对导入）', 'createTime': now,
               'beginTime': int(date.timestamp() * 1000), 'calendarWeekCount': maximum,
               'totalWeekNum': maximum, 'source': '学生课表＋班级补充；本地文件解析，导入前须核对预览'},
               'courses': courses}]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--student', type=Path, required=True)
    parser.add_argument('--class-table', type=Path, required=True)
    parser.add_argument('--semester', required=True)
    parser.add_argument('--first-monday', required=True)
    parser.add_argument('--weeks', type=int, required=True)
    parser.add_argument('--confirm-all-weeks', action='store_true', help='确认输入为全部教学周')
    parser.add_argument('--include-class', action='store_true', help='将无冲突的班级补充列入待确认文件')
    parser.add_argument('--exclude-code', action='append', default=[], help='明确暂不导入的班级课程序号')
    parser.add_argument('--output', type=Path, required=True, help='必须为不存在的新目录')
    args = parser.parse_args()
    try:
        require(args.confirm_all_weeks, '先确认两份文件均为全部教学周，再传 --confirm-all-weeks')
        require(1 <= args.weeks <= 30, '校历周数须为1–30')
        require(not args.output.exists(), '输出目录已存在；保留旧文件，请使用新目录')
        winter, summer = preset()
        student_data = load_table(args.student, '学生课表', args.semester)
        class_data = load_table(args.class_table, '班级课表', args.semester)
        student, student_cancelled = parse_table(student_data, args.weeks, len(winter))
        classroom, class_cancelled = parse_table(class_data, args.weeks, len(winter))
        excluded = set(args.exclude_code)
        require(excluded <= {c['id'] for c in classroom}, '排除的课程序号未出现在班级课表')
        combined, report = merge_tables(student, classroom, student_cancelled + class_cancelled, excluded)
        selected = combined if args.include_class else student
        report['selected_courses'] = selected
        report['class_supplements_included'] = args.include_class
        report['input_sha256'] = {kind: hashlib.sha256(path.read_bytes()).hexdigest() for kind, path in
                                  [('student', args.student), ('class', args.class_table)]}
        result = backup(selected, args.semester, args.first_monday, args.weeks, winter, summer)
        preview = ['# 本地课表导入预览', '', '仅解析本地文件；未写入手机或学校账号。',
                   '班级补充须本人核对，冲突/停课/明确排除项不导入。', '',
                   '|课程|星期|节次|周次|教室|', '|---|---|---|---|---|']
        for c in selected:
            fields = [c['name'], '日一二三四五六'[c['dayOfWeek']], ','.join(map(str,c['timeSpan'])),
                      ','.join(map(str,c['weekOfTerm'])), c['location']]
            preview.append('|' + '|'.join(s.replace('|', '\\|') for s in fields) + '|')
        preview += ['', '## 未导入及去重明细', '', '见 review.json；它包含私人课程信息，不要提交到 Git。',
                    '', '导入后为新增学期，须本人选择为默认学期才用于首页和提醒。']
        # Parse and validate everything before creating any outputs. Existing outputs never overwritten.
        args.output.mkdir(parents=True, exist_ok=False)
        for name, value in [('schedule-import.json', result), ('review.json', report)]:
            (args.output / name).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')
        (args.output / 'PREVIEW.md').write_text('\n'.join(preview) + '\n', encoding='utf-8')
        print(json.dumps({'courses': len({c['id'] for c in selected}), 'arrangements': len(selected),
                          'duplicates': len(report['duplicates']), 'conflicts': len(report['conflicts_not_imported']),
                          'cancelled': len(report['cancelled_not_imported']), 'excluded': len(report['excluded_not_imported'])}))
    except (ValueError, OSError, TypeError, KeyError, AttributeError, IndexError, OverflowError) as error:
        # Never dump source HTML, personal course text, or complete exception objects into logs.
        print('转换未完成：' + (str(error) if isinstance(error, ImportError) else '文件结构、编码或读写无效'))
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
