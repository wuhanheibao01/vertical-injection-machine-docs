(*
  FB_EK312 功能块
  功能：
  1. 提供 12 路温控的统一控制与状态输出接口。
  2. 自动模式下按设定温度升温；手动模式下按 R0~R3 分组直接加热。
  3. 对外输出温控完成、报警、热状态和每一路段状态。

  说明：
  1. 当前实现是控制/仿真一体化逻辑，便于在无真实温控器时联调主控。
  2. 若后续接入真实温控器，可保留本接口不变，仅替换内部驱动实现。
*)
FUNCTION_BLOCK FB_EK312
VAR_INPUT
    bStart: BOOL;                 // TRUE=启动温控
    bStop: BOOL;                  // TRUE=停止温控
    bReset: BOOL;                 // TRUE=复位温控状态
    bManualMode: BOOL;            // TRUE=按 R0~R3 手动分组加热
    bR0: BOOL;                    // 手动加热组 0
    bR1: BOOL;                    // 手动加热组 1
    bR2: BOOL;                    // 手动加热组 2
    bR3: BOOL;                    // 手动加热组 3
    stInPara: ST_EK312InPara;     // 温控输入参数
END_VAR
VAR_OUTPUT
    bBusy: BOOL;                  // TRUE=温控正在执行
    bDone: BOOL;                  // TRUE=全部有效段达到设定温度
    bAlarm: BOOL;                 // TRUE=出现温控报警
    dwAlarmID: DWORD;             // 温控报警码
    stOutPara: ST_EK312OutPara;   // 温控输出状态
    uiHeatState: UINT;            // 0=停止 1=升温 2=已就绪
    uiVersion: UINT;              // 模块版本号
    uiActTime: UINT;              // 当前升温持续时间，单位 s
END_VAR
VAR
    eState: ST_EK312State := eState_Idle;
    tPulse: TON;
    uiCycle: UINT := 0;
    udiElapsedMs: UDINT := 0;
    bAllReady: BOOL := FALSE;
    bZoneHeat: BOOL := FALSE;
END_VAR

(* 复位时清空温控状态、输出和计时器，恢复到安全初值。 *)
IF bReset THEN
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := FALSE;
    dwAlarmID := 0;
    uiHeatState := 0;
    uiVersion := 2;
    uiActTime := 0;
    udiElapsedMs := 0;
    FOR uiCycle := 1 TO 12 DO
        stOutPara.aSeg[uiCycle].uiActualTemp := 25;
        stOutPara.aSeg[uiCycle].uiState := 0;
    END_FOR;
    FOR uiCycle := 1 TO 100 DO
        stOutPara.aOutputAddr[uiCycle] := 0;
    END_FOR;
    tPulse(IN := FALSE, PT := T#100MS);
ELSIF bStop THEN
    (* 正常停止时保留当前反馈值，但退出执行态并撤销加热输出。 *)
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    uiHeatState := 0;
    uiActTime := 0;
    FOR uiCycle := 1 TO 12 DO
        stOutPara.aOutputAddr[uiCycle] := 0;
    END_FOR;
    tPulse(IN := FALSE, PT := T#100MS);
ELSE
    CASE eState OF
        eState_Idle:
            bBusy := FALSE;
            bDone := FALSE;
            bAlarm := FALSE;
            dwAlarmID := 0;
            uiHeatState := 0;
            uiActTime := 0;
            FOR uiCycle := 1 TO 12 DO
                stOutPara.aOutputAddr[uiCycle] := 0;
            END_FOR;
            tPulse(IN := FALSE, PT := T#100MS);
            IF bStart THEN
                eState := eState_Init;
            END_IF;

        eState_Init:
            (* 初始化各段温度与状态，为进入升温阶段准备默认值。 *)
            bBusy := TRUE;
            bDone := FALSE;
            uiHeatState := 1;
            udiElapsedMs := 0;
            uiVersion := 2;
            FOR uiCycle := 1 TO 12 DO
                IF stOutPara.aSeg[uiCycle].uiActualTemp = 0 THEN
                    stOutPara.aSeg[uiCycle].uiActualTemp := 25;
                END_IF;
                stOutPara.aSeg[uiCycle].uiState := 1;
            END_FOR;
            eState := eState_Heating;

        eState_Heating:
            (* 按 100ms 节拍刷新一轮温控计算。 *)
            bBusy := TRUE;
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiElapsedMs := udiElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);

                bAllReady := TRUE;
                bAlarm := FALSE;
                dwAlarmID := 0;

                FOR uiCycle := 1 TO 12 DO
                    bZoneHeat := FALSE;

                    IF stInPara.aSeg[uiCycle].uiFunc = 1 THEN
                        IF bManualMode THEN
                            CASE uiCycle OF
                                1, 2, 3: bZoneHeat := bR0;
                                4, 5, 6: bZoneHeat := bR1;
                                7, 8, 9: bZoneHeat := bR2;
                            ELSE
                                bZoneHeat := bR3;
                            END_CASE;
                        ELSE
                            bZoneHeat := (stOutPara.aSeg[uiCycle].uiActualTemp < stInPara.aSeg[uiCycle].uiSetTemp);
                        END_IF;

                        IF bZoneHeat THEN
                            stOutPara.aSeg[uiCycle].uiActualTemp := stOutPara.aSeg[uiCycle].uiActualTemp + 1;
                            stOutPara.aOutputAddr[uiCycle] := 1;
                        ELSE
                            IF stOutPara.aSeg[uiCycle].uiActualTemp > stInPara.aSeg[uiCycle].uiSetTemp THEN
                                stOutPara.aSeg[uiCycle].uiActualTemp := stOutPara.aSeg[uiCycle].uiActualTemp - 1;
                            END_IF;
                            stOutPara.aOutputAddr[uiCycle] := 0;
                        END_IF;

                        IF stOutPara.aSeg[uiCycle].uiActualTemp < stInPara.aSeg[uiCycle].uiMin THEN
                            stOutPara.aSeg[uiCycle].uiState := 1;
                            bAllReady := FALSE;
                            bAlarm := TRUE;
                            dwAlarmID := dwAlarmID OR DWORD#16#0002;
                        ELSIF stOutPara.aSeg[uiCycle].uiActualTemp > stInPara.aSeg[uiCycle].uiMax THEN
                            stOutPara.aSeg[uiCycle].uiState := 2;
                            bAlarm := TRUE;
                            dwAlarmID := dwAlarmID OR DWORD#16#0001;
                        ELSE
                            stOutPara.aSeg[uiCycle].uiState := 0;
                            IF stOutPara.aSeg[uiCycle].uiActualTemp < stInPara.aSeg[uiCycle].uiSetTemp THEN
                                bAllReady := FALSE;
                            END_IF;
                        END_IF;
                    ELSE
                        stOutPara.aSeg[uiCycle].uiState := 0;
                        stOutPara.aOutputAddr[uiCycle] := 0;
                    END_IF;
                END_FOR;
            END_IF;

            uiActTime := TO_UINT(udiElapsedMs / 1000);
            IF bAllReady THEN
                bDone := TRUE;
                uiHeatState := 2;
            ELSE
                bDone := FALSE;
                uiHeatState := 1;
            END_IF;

            IF dwAlarmID = DWORD#16#0001 THEN
                eState := eState_Error;
            END_IF;

        eState_Error:
            (* 故障态下切断全部加热输出，等待外部复位。 *)
            bBusy := FALSE;
            bAlarm := TRUE;
            uiHeatState := 0;
            FOR uiCycle := 1 TO 12 DO
                stOutPara.aOutputAddr[uiCycle] := 0;
            END_FOR;
            tPulse(IN := FALSE, PT := T#100MS);

    ELSE
        eState := eState_Error;
    END_CASE;
END_IF;
END_FUNCTION_BLOCK
