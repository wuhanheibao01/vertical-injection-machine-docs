(* 
  FB_MoldAdjust 功能块
  功能：
  1. 负责调模进、调模退及其调试动作的执行状态机。
  2. 根据调模参数生成压力、速度与位置命令，并输出调模进退完成状态。

  说明：
  1. 自动/工艺模式使用 1=调模进、2=调模退；手动点动使用 3/4。
  2. 状态机部分只生成工艺命令，块尾由内部 `FB_HydAxis` 完成轴保护与最终限幅。
*)
FUNCTION_BLOCK FB_MoldAdjust
VAR_IN_OUT
    stMoldAdjustAxis: ST_AxisRefHyd;  // 调模共享轴结构
END_VAR
VAR_INPUT
    bStart: BOOL;                     // TRUE=启动调模动作
    bStop: BOOL;                      // TRUE=正常停止
    bEStop: BOOL;                     // TRUE=急停
    bReset: BOOL;                     // TRUE=复位状态机与输出
    bManualMode: BOOL;                // TRUE=手动点动调模
    uiMoldAdjustMode: UINT;           // 1=调模进 2=调模退 3=手动调模进 4=手动调模退
    stMoldAdjustPara: ST_MoldAdjustPara; // 调模工艺参数
    bMoldAdjustInStop: BOOL;          // 调模进停止信号
    bMoldAdjustOutStop: BOOL;         // 调模退停止信号
    uiClampPresElecRulerVal: UINT;    // 压力反馈
    rMoldAdjustActualPosition: LREAL; // 调模轴实际位置反馈
    rMoldAdjustActualVelocity: LREAL; // 调模轴实际速度反馈
    rMoldAdjustActualPressure: LREAL; // 调模轴实际压力反馈
END_VAR
VAR_OUTPUT
    bBusy: BOOL;                      // TRUE=当前动作尚未结束
    bDone: BOOL;                      // TRUE=当前动作完成
    bAlarm: BOOL;                     // TRUE=当前动作报警
    dwAlarmID: DWORD;                 // 模块报警码
    uiActHint: UINT;                  // 当前动作提示码
    uiActTime: UINT;                  // 当前动作持续时间，单位 s
    bMoldAdjustIned: BOOL;            // TRUE=调模进完成
    bMoldAdjustOuted: BOOL;           // TRUE=调模退完成
    uiPresCmd: UINT;                  // 压力命令输出
    uiSpdCmd: UINT;                   // 速度命令输出
    udiPosCmd: UDINT;                 // 位置命令输出
END_VAR
VAR
    eState: E_MoldAdjustState := eState_Idle; // 当前调模状态机状态
    fbAxisInst: FB_HydAxis;                  // 调模轴层实例
    stAxisStatusLocal: ST_HydAxisStatus;    // 调模轴层状态缓存
    stAxisConfigLocal: ST_HydAxisConfig := (
        nAxisID := 2,
        rMaxCylinderStroke := 10000.0,
        rMaxVelocity := 1000.0,
        rMaxPressure := 1000.0,
        rPosTolerance := 0.5,
        rVelTolerance := 0.5,
        rPresTolerance := 0.5
    );
    tPulse: TON;                              // 100ms 节拍定时器，用于累计动作时间
    udiElapsedMs: UDINT := 0;                 // 当前调模动作已运行时间，单位 ms
    bManualActive: BOOL := FALSE;             // TRUE=当前按手动/调试逻辑执行
    bInRequest: BOOL := FALSE;                // TRUE=当前请求调模进
    bOutRequest: BOOL := FALSE;               // TRUE=当前请求调模退
END_VAR

(* 把模式号预先映射成方向请求位，避免状态机内重复判断数值模式。 *)
bManualActive := bManualMode OR (uiMoldAdjustMode = 3) OR (uiMoldAdjustMode = 4);
bInRequest := (uiMoldAdjustMode = 1) OR (uiMoldAdjustMode = 3);
bOutRequest := (uiMoldAdjustMode = 2) OR (uiMoldAdjustMode = 4);

(* 复位时强制回空闲，清空调模完成态、输出命令和计时缓存。 *)
IF bReset THEN
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := FALSE;
    dwAlarmID := 0;
    uiActHint := 0;
    uiActTime := 0;
    bMoldAdjustIned := FALSE;
    bMoldAdjustOuted := FALSE;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    udiElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
(* 急停直接进故障态，避免调模轴继续输出命令。 *)
ELSIF bEStop THEN
    eState := eState_Error;
    bAlarm := TRUE;
    dwAlarmID := dwAlarmID OR DWORD#16#0010;
    uiActHint := 1;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    tPulse(IN := FALSE, PT := T#100MS);
(* 正常停止按空闲态收口，不保留当前动作上下文。 *)
ELSIF bStop THEN
    eState := eState_Idle;
    bBusy := FALSE;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    uiActHint := 0;
    udiElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
ELSE
    CASE eState OF
        (* 空闲态：等待启动，并根据请求方向进入调模进或调模退。 *)
        eState_Idle:
            bBusy := FALSE;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            uiActHint := 0;
            uiActTime := 0;
            udiElapsedMs := 0;
            tPulse(IN := FALSE, PT := T#100MS);
            IF bStart THEN
                bDone := FALSE;
                bAlarm := FALSE;
                dwAlarmID := 0;
                bMoldAdjustIned := FALSE;
                bMoldAdjustOuted := FALSE;
                IF bInRequest THEN
                    eState := eState_MoldAdjustIning;
                ELSIF bOutRequest THEN
                    eState := eState_MoldAdjustOuting;
                ELSE
                    bAlarm := TRUE;
                    dwAlarmID := DWORD#16#0001;
                    eState := eState_Error;
                END_IF;
            END_IF;

        (* 调模进执行态：输出调模进段命令，并按时间或停止信号判定结束。 *)
        eState_MoldAdjustIning:
            bBusy := TRUE;
            uiActHint := 55;
            uiPresCmd := stMoldAdjustPara.stMoldAdjustInSeg.uiPres;
            uiSpdCmd := stMoldAdjustPara.stMoldAdjustInSeg.uiSpd;
            udiPosCmd := 0;

            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiElapsedMs := udiElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiElapsedMs / 1000);

            (* 手动调模进只要保持启动信号就持续输出命令。 *)
            IF bManualActive THEN
                IF NOT bStart THEN
                    eState := eState_Idle;
                END_IF;
            (* 自动调模进由结束模式决定：0=按时间，非 0=按停止信号。 *)
            ELSE
                IF (stMoldAdjustPara.uiMoldAdjustInMode = 0) AND (stMoldAdjustPara.stMoldAdjustInSeg.uiTime > 0) AND (udiElapsedMs >= TO_UDINT(stMoldAdjustPara.stMoldAdjustInSeg.uiTime)) THEN
                    eState := eState_MoldAdjustIned;
                ELSIF (stMoldAdjustPara.uiMoldAdjustInMode <> 0) AND bMoldAdjustInStop THEN
                    eState := eState_MoldAdjustIned;
                END_IF;

                (* 调模进超时说明动作未按预期结束，直接报警。 *)
                IF (stMoldAdjustPara.uiMoldAdjustInLimitTime > 0) AND (udiElapsedMs >= TO_UDINT(stMoldAdjustPara.uiMoldAdjustInLimitTime)) THEN
                    dwAlarmID := dwAlarmID OR DWORD#16#0001;
                    eState := eState_Error;
                END_IF;
            END_IF;

        (* 调模进完成态：置位完成标志并撤销输出命令。 *)
        eState_MoldAdjustIned:
            bBusy := FALSE;
            bDone := TRUE;
            bMoldAdjustIned := TRUE;
            uiActHint := 56;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;

        (* 调模退执行态：输出调模退段命令，并按时间或停止信号判定结束。 *)
        eState_MoldAdjustOuting:
            bBusy := TRUE;
            uiActHint := 57;
            uiPresCmd := stMoldAdjustPara.stMoldAdjustOutSeg.uiPres;
            uiSpdCmd := stMoldAdjustPara.stMoldAdjustOutSeg.uiSpd;
            udiPosCmd := 0;

            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiElapsedMs := udiElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiElapsedMs / 1000);

            (* 手动调模退在保持启动期间持续输出。 *)
            IF bManualActive THEN
                IF NOT bStart THEN
                    eState := eState_Idle;
                END_IF;
            (* 自动调模退由结束模式决定：0=按时间，非 0=按停止信号。 *)
            ELSE
                IF (stMoldAdjustPara.uiMoldAdjustOutMode = 0) AND (stMoldAdjustPara.stMoldAdjustOutSeg.uiTime > 0) AND (udiElapsedMs >= TO_UDINT(stMoldAdjustPara.stMoldAdjustOutSeg.uiTime)) THEN
                    eState := eState_MoldAdjustOuted;
                ELSIF (stMoldAdjustPara.uiMoldAdjustOutMode <> 0) AND bMoldAdjustOutStop THEN
                    eState := eState_MoldAdjustOuted;
                END_IF;

                (* 调模退超时说明机构未在限定时间内收口。 *)
                IF (stMoldAdjustPara.uiMoldAdjustOutLimitTime > 0) AND (udiElapsedMs >= TO_UDINT(stMoldAdjustPara.uiMoldAdjustOutLimitTime)) THEN
                    dwAlarmID := dwAlarmID OR DWORD#16#0002;
                    eState := eState_Error;
                END_IF;
            END_IF;

        (* 调模退完成态：置位调模退完成标志。 *)
        eState_MoldAdjustOuted:
            bBusy := FALSE;
            bDone := TRUE;
            bMoldAdjustOuted := TRUE;
            uiActHint := 58;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;

        (* 故障态：统一撤销命令，仅保留报警输出。 *)
        eState_Error:
            bBusy := FALSE;
            bAlarm := TRUE;
            uiActHint := 1;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            tPulse(IN := FALSE, PT := T#100MS);

    ELSE
        eState := eState_Error;
    END_CASE;
END_IF;

(* 先把现场反馈、固定轴配置和模块报警写回共享轴结构，再通过统一轴层接口下发本拍命令。 *)
stMoldAdjustAxis.rActualPosition := rMoldAdjustActualPosition;
stMoldAdjustAxis.rActualVelocity := rMoldAdjustActualVelocity;
stMoldAdjustAxis.rActualPressure := rMoldAdjustActualPressure;
stMoldAdjustAxis.stConfig := stAxisConfigLocal;
stMoldAdjustAxis.nFaultCode := TO_INT(dwAlarmID);

fbAxisInst(
    stAxisRef := stMoldAdjustAxis,   // 把调模共享轴结构交给轴层实例统一整理最终命令与状态。
    bStart := bBusy,                 // 调模块当前忙碌时，通知轴层继续执行本拍目标命令。
    bStop := bStop,                  // 把调模块收到的正常停止命令直接送给轴层。
    bEStop := bEStop,                // 把调模块收到的急停命令直接送给轴层。
    bReset := bReset,                // 把调模块收到的复位命令直接送给轴层。
    bDir := bInRequest,              // 当前把“TRUE=调模进方向”定义为调模轴正向方向。
    uiMode := UINT#1,                // 当前液压执行链统一按位置模式接口收口。
    uiCmdPres := uiPresCmd,          // 把调模块当前压力命令送给轴层做最终压力限幅。
    uiSpd := uiSpdCmd,               // 把调模块当前速度命令送给轴层做最终速度限幅。
    udiPos := udiPosCmd,             // 把调模块当前位置目标送给轴层做最终行程限幅。
    uiForce := UINT#0,               // 当前调模块未定义独立力命令，因此该接口位先固定传 0。
    uiAcc := UINT#0,                 // 当前调模块未定义独立加速度命令，因此该接口位先固定传 0。
    uiDec := UINT#0,                 // 当前调模块未定义独立减速度命令，因此该接口位先固定传 0。
    uiJerk := UINT#0                 // 当前调模块未定义独立加加速度命令，因此该接口位先固定传 0。
);

stAxisStatusLocal := stMoldAdjustAxis.stStatus; // 把共享轴结构里的轴层状态镜像到模块本地缓存，继续复用现有汇总代码。

bBusy := bBusy OR stAxisStatusLocal.bCommandActive;
bAlarm := bAlarm OR stAxisStatusLocal.bAlarm;
dwAlarmID := dwAlarmID OR stAxisStatusLocal.dwAlarmID;
IF stAxisStatusLocal.uiActTime > uiActTime THEN
    uiActTime := stAxisStatusLocal.uiActTime;
END_IF;
END_FUNCTION_BLOCK
