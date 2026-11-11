/**
 * 启动其他应用，重启或退出自身
 */

import { common, Want } from "@kit.AbilityKit";
import { BusinessError } from '@kit.BasicServicesKit';
import { call } from "@kit.TelephonyKit";

export class WantAbility {
  static StartQQ(hostContext: common.UIAbilityContext) {
    WantAbility.openGitHub(hostContext);
  }

  static restart(hostContext: common.UIAbilityContext) {
    let want: Want = {
      bundleName: 'com.sdkdsd.dailynic.sust',
      abilityName: 'EntryAbility'
    };
    try {
      hostContext.getApplicationContext().restartApp(want);
    } catch (error) {
      console.error(`restartApp fail, error: ${JSON.stringify(error)}`);
      if (error.code === 16000064) {
        WantAbility.quit(hostContext);
      }
    }
  }

  static quit(hostContext: common.UIAbilityContext) {
    hostContext.terminateSelf((err) => {
      if (!err) {
        hostContext.getApplicationContext().killAllProcesses().catch((error: Error) => {
          console.error(`Quitting ERROR: [${error.name}] ${error.message}`);
        });
      }
    });
  }

  static openGitHub(hostContext: common.UIAbilityContext) {
    hostContext.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: 'https://github.com/sdkdsd/DailyNic_HMOS/issues'
    }).catch((err: BusinessError) => {
      console.error(`startAbility failed, code is ${err.code}, message is ${err.message}`);
    });
  }

  static StartBrowser(hostContext: common.UIAbilityContext, url: string) {
    hostContext.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    }).catch((err: BusinessError) => {
      console.error(`startAbility failed, code is ${err.code}, message is ${err.message}`);
    })
  }

  static SendEmail(hostContext: common.UIAbilityContext, uri: string) {
    hostContext.startAbility({
      action: 'ohos.want.action.sendToData',
      uri: uri
    }).catch((err: BusinessError) => {
      console.error(`startAbility failed, code is ${err.code}, message is ${err.message}`);
    })
  }

  static MakeCall(uri: string) {
    call.makeCall(uri, (err) => {
      if (!err) {
        console.info('make call succeeded.');
      } else {
        console.info('make call fail, err is:' + JSON.stringify(err));
      }
    });
  }
}