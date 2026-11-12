// SUST adaptation, 2026-11-12. Original implementation remains in Git history.
import { AdaptationNotice } from '../view/AdaptationNotice';
@Builder
export function GCBNBuilder(name: string, param?: Object) {
  AdaptationNotice({ heading: '选课目录与教室查询', detail: '原选课目录和教室查询依赖中科大服务，尚未适配。这里只提供官方门户入口，不会进行选课或预约。' });
}
