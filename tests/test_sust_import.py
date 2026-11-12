"""Synthetic fixtures only. No real names, student IDs or course schedules."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('sust_import', ROOT / 'scripts/sust_import.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def fixture(text='课程甲(900000001.A1) (教师甲)\n(1-14,教学楼A101(900A101))', day=1, start=1, span=2):
    rows = [[dict(text=h, rowspan=1, colspan=1) for h in m.HEADERS]]
    for p in range(1, 12):
        cells = [dict(text=m.PERIODS[p-1], rowspan=1, colspan=1)]
        for d in range(1, 8):
            if d == day and start < p < start + span:
                continue
            cells.append(dict(text=text if d == day and p == start else '',
                              rowspan=span if d == day and p == start else 1, colspan=1))
        rows.append(cells)
    return dict(kind='学生课表', semester='测试学期', week='全部', rows=rows,
                catalog=[m.CATALOG, ['1','900000001','课程甲','3','900000001.A1','教师甲','','']])


class ConverterTests(unittest.TestCase):
    def test_rowspans_map_sunday_and_contiguous_periods(self):
        courses, cancelled = m.parse_table(fixture(day=7, start=5, span=4))
        self.assertEqual(courses[0]['dayOfWeek'], 0)
        self.assertEqual(courses[0]['timeSpan'], [5,6,7,8])
        self.assertEqual(courses[0]['location'], '教学楼A101')
        self.assertEqual(cancelled, [])

    def test_split_weeks_and_odd_even(self):
        self.assertEqual(m.weeks('1 3-10',20), [1,3,4,5,6,7,8,9,10])
        self.assertEqual(m.weeks('1-6(单),8,10-12(双)',20), [1,3,5,8,10,12])
        for value in ['0','21','5-2','1,','1-2(星期)','第3周','2(单)']:
            with self.subTest(value=value), self.assertRaises(m.ImportError):
                m.weeks(value,20)

    def test_multi_course_cell_and_cancelled_week(self):
        data=fixture('课程甲(900000001.A1) (教师甲)\n(1-10,教学楼A101(900A101)\n'
                     '课程甲(900000001.A1) (教师甲)\n(2,停课(-2)\n'
                     '课程乙(900000002.B1)\n(11-12,教学楼A101(900A101)')
        data['catalog'].append(['2','900000002','课程乙','1','900000002.B1','','',''])
        courses, cancelled=m.parse_table(data)
        self.assertEqual(len(courses),2)
        self.assertNotIn(2,courses[0]['weekOfTerm'])
        self.assertEqual(courses[1]['teacher'],'')
        self.assertEqual(cancelled[0]['weekOfTerm'],[2])

    def test_parentheses_in_course_name(self):
        data=fixture('课程甲(3)(900000001.A1) (教师甲)\n(1-14,教学楼A101)')
        data['catalog'][1][2]='课程甲(3)'
        self.assertEqual(m.parse_table(data)[0][0]['name'],'课程甲(3)')

    def test_unknown_and_incomplete_inputs_reject_whole_batch(self):
        mutations=[lambda x:x['rows'][1].pop(), lambda x:x['rows'][1][1].update(rowspan=12),
                   lambda x:x['rows'][1][1].update(colspan=2), lambda x:x['rows'][1][1].update(text='未知格式'),
                   lambda x:x['rows'][1][1].update(text='课程甲(900000001.A1) (教师甲)'),
                   lambda x:x['catalog'][1].__setitem__(2,'不一致名称'),
                   lambda x:x.__setitem__('week','第1周'),
                   lambda x:x['rows'][0][1].update(text='星期日')]
        for mutate in mutations:
            data=fixture(); mutate(data)
            with self.assertRaises(m.ImportError): m.parse_table(data)

    def test_unconfirmed_evening_is_rejected_without_guessing(self):
        with self.assertRaises(m.ImportError): m.parse_table(fixture(start=9))

    def test_dedup_keeps_student_and_flags_real_conflicts(self):
        student=m.parse_table(fixture())[0]
        conflict=copy.deepcopy(student[0]); conflict['location']='其他教室'
        extra=copy.deepcopy(student[0]); extra['dayOfWeek']=0
        merged,report=m.merge_tables(student,[student[0],conflict,extra],[],set())
        self.assertEqual(len(merged),2)
        self.assertEqual(len(report['duplicates']),1)
        self.assertEqual(len(report['conflicts_not_imported']),1)
        self.assertEqual(student[0]['dayOfWeek'],1)

    def test_explicit_exclusion_and_class_cancellation(self):
        student=m.parse_table(fixture())[0]
        extra=copy.deepcopy(student[0]); extra['id']='900000002.B1'
        stop=copy.deepcopy(student[0]); stop['weekOfTerm']=[2]
        merged,report=m.merge_tables(student,[extra],[stop],{'900000002.B1'})
        self.assertEqual(len(merged),1)
        self.assertNotIn(2,merged[0]['weekOfTerm'])
        self.assertEqual(len(report['excluded_not_imported']),1)

    def test_saved_html_no_scripts_executed(self):
        data=fixture()
        from html import escape
        html='<script>throw new Error("never execute");</script><input type="hidden" value="private">'
        html+='<table id="manualArrangeCourseTable">'+''.join('<tr>'+''.join(
            f'<td rowspan="{c["rowspan"]}">{escape(c["text"]).replace(chr(10),"<br>")}</td>'
            for c in row)+'</tr>' for row in data['rows'])+'</table>'
        html+='<table>'+''.join('<tr>'+''.join('<td>'+escape(c)+'</td>' for c in row)+'</tr>'
                               for row in data['catalog'])+'</table>'
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'table.html';p.write_text(html,encoding='utf-8')
            actual=m.load_table(p,'学生课表','测试学期')
            self.assertEqual(m.parse_table(actual),m.parse_table(data))
            self.assertNotIn('private',json.dumps(actual))

    def test_unknown_html_not_accepted_as_schedule(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'table.html';p.write_text('<html>登录</html>',encoding='utf-8')
            with self.assertRaises(m.ImportError):m.load_table(p,'学生课表','测试学期')

    def test_json_metadata_and_term_mismatch(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'table.json';p.write_text(json.dumps(fixture()),encoding='utf-8')
            with self.assertRaises(m.ImportError):m.load_table(p,'班级课表','测试学期')
            with self.assertRaises(m.ImportError):m.load_table(p,'学生课表','另一学期')

    def test_cli_outputs_and_failure_preserve_existing_files(self):
        with tempfile.TemporaryDirectory() as d:
            folder=Path(d); student=folder/'student.json'; classroom=folder/'class.json'
            student.write_text(json.dumps(fixture()),encoding='utf-8')
            data=fixture();data['kind']='班级课表'
            classroom.write_text(json.dumps(data),encoding='utf-8')
            output=folder/'out'
            cmd=[sys.executable,str(ROOT/'scripts/sust_import.py'),'--student',str(student),'--class-table',str(classroom),
                 '--semester','测试学期','--first-monday','2026-08-31','--weeks','20',
                 '--confirm-all-weeks','--include-class','--output',str(output)]
            run=subprocess.run(cmd,capture_output=True)
            self.assertEqual(run.returncode,0,run.stdout)
            saved=(output/'schedule-import.json').read_bytes()
            backup=json.loads(saved)
            self.assertEqual(backup['semesters'][0]['attribute']['calendarWeekCount'],20)
            self.assertEqual(backup['scheduleVersion'],'sust-xian-2-seasonal')
            self.assertEqual(subprocess.run(cmd,capture_output=True).returncode,1)
            self.assertEqual((output/'schedule-import.json').read_bytes(),saved)
            bad=fixture();bad['rows'][1][1]['text']='unknown'
            student.write_text(json.dumps(bad),encoding='utf-8')
            cmd[-1]=str(folder/'bad')
            self.assertEqual(subprocess.run(cmd,capture_output=True).returncode,1)
            self.assertFalse((folder/'bad').exists())


if __name__ == '__main__': unittest.main()
