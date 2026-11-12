
/**
 * --- 功能页链接表 ---
 */

export interface LinkAddress {
  url: string | Resource;
  subtitle?: string;
  notUrl?: boolean;
}

export interface MultiLink {
  title: ResourceStr;
  url: LinkAddress[];
  icon: ResourceStr;
  /** 拼音（供首页搜索匹配），可填全拼、首字母等多种形式，如 ['jiaowuxitong', 'jwxt']；暂不考虑补充 */
  pinyin?: string[];
  /** 别名（供首页搜索匹配），可填多个，如 ['选课'] */
  alias?: string[];
}

export interface SimpleLink {
  title: ResourceStr;
  url: string | Resource;
}

export interface LinkSet {
  title: ResourceStr;
  set: MultiLink[];
}

// Only verified public entry points; no inferred SSO service parameters.
export const LINK: LinkSet[] = [
  { title: '课程与考试', set: [
    { title: '本地课表', url: [{ url: 'Schedule', notUrl: true }], icon: $r('app.media.KeChengBiao') },
    { title: '本地考试', url: [{ url: 'ExamDetail', notUrl: true }], icon: $r('app.media.KaoShiXinXi') },
    { title: '课时与校历设置', url: [{ url: 'CampusSetup', notUrl: true }], icon: $r('app.media.calendar') },
    { title: '联网获取课表', url: [{ url: 'GetSchedule', notUrl: true }], icon: $r('app.media.cloud_download') },
    { title: '选课目录 / 教室 · 未适配', url: [{ url: 'GetClassByName', notUrl: true }], icon: $r('app.media.GongGongChaXun') }
  ] },
  { title: '校园服务（官方网页）', set: [
    { title: '陕科大综合门户', url: [{ url: 'https://my.sust.edu.cn/' }], icon: $r('app.media.JiaoWuXiTong'), alias: ['教务', '课表', '考试', '成绩', '校园卡', '图书馆'] },
    { title: '陕科大统一身份认证', url: [{ url: 'https://login.sust.edu.cn/cas/login' }], icon: $r('app.media.key_horizontal') }
  ] },
  { title: '本地工具', set: [
    { title: '待办', url: [{ url: 'Todo', notUrl: true }], icon: $r('app.media.calendar') },
    { title: '学习通作业与考试', url: [{ url: 'GetHomework', notUrl: true }], icon: $r('app.media.cloud_download') },
    { title: '本地答题', url: [{ url: 'MockPracticeList', notUrl: true }], icon: $r('app.media.JiKaoZiCe') },
    { title: '适配说明', url: [{ url: 'Help', notUrl: true }], icon: $r('app.media.lightbulb') }
  ] }
];
