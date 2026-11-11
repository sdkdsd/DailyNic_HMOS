// SUST adaptation, 2026-11-12. Original implementation remains in Git history.
import { AdaptationNotice } from '../view/AdaptationNotice';
@Builder
export function GetBuilder(name: string, param?: Object) {
  AdaptationNotice({ heading: '在线课表与考试', detail: '课表和考试自动同步尚未适配。尚未取得陕科大当前教务页面结构和只读接口证据。' });
}
