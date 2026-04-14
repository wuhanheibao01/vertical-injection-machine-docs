(* 
  AutoCycleTypes.st
  功能：定义自动循环调度器 `FB_AutoCycle` 使用的状态机和参数结构。

  说明：
  1. 自动循环块本身只负责“步骤编排”，不直接控制任何一根轴。
  2. 实际动作由主控层把本文件定义的状态与参数，分发给合模、座台、射胶、储料、托模等模块。
  3. 本文件需要保持声明清晰、注释完整，避免状态枚举和参数字段在后续扩展时失去可维护性。
*)

TYPE E_AutoCycleState :
(
    eState_Idle,         // 空闲，等待启动
    eState_Init,         // 自动启动前的条件确认
    eState_ClampClose,   // 合模
    eState_NozzleIn,     // 座进
    eState_Inject,       // 射出与保压
    eState_PreCool,      // 前冷却
    eState_PreSuckBack,  // 前射退
    eState_Meter,        // 储料
    eState_PostSuckBack, // 后射退
    eState_PostCool,     // 后冷却
    eState_NozzleOut,    // 座退
    eState_ClampOpen,    // 开模
    eState_EjectIn,      // 托模进
    eState_EjectOut,     // 托模退
    eState_CycleEnd,     // 单周期结束
    eState_Error         // 自动流程故障
);
END_TYPE

TYPE ST_AutoCyclePara :
STRUCT
    (* 工艺使能位。
       某个步骤不参与自动循环时，调度器会直接跳过该步骤。
    *)
    bUseNozzle: BOOL;
    bUseInject: BOOL;
    bUsePreSuckBack: BOOL;
    bUseMeter: BOOL;
    bUsePostSuckBack: BOOL;
    bUseEject: BOOL;

    (* 时间参数，单位 ms。0 表示跳过该等待步骤。 *)
    uiPreCoolTime: UINT;
    uiPostCoolTime: UINT;

    (* 全自动停机循环数。
       0 表示不限制；大于 0 时，达到次数后停在 `eState_CycleEnd` 等待人工确认。
    *)
    uiAutoStopCount: UINT;
END_STRUCT
END_TYPE
