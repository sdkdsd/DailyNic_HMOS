// SUST adaptation, 2026-11-12. Original implementation remains in Git history.
import { AdaptationNotice } from '../view/AdaptationNotice';
@Builder
export function GHWBuilder(name: string, param?: Object) {
  AdaptationNotice({ heading: '作业导入', detail: '原作业导入依赖中科大教学系统，陕科大接口尚未核实。可以在待办中手动记录作业。' });
}
