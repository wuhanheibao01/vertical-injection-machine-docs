(* 
  FB_HydAxis 功能块
  功能：
  1. 对模块层写入的 `ST_AxisRefHyd` 进行最终轴实例化。
  2. 在统一位置补齐轴号、能力上限、命令限幅和轴层报警诊断。
  3. 输出标准化的轴状态结构，便于主控层把轴层结果并入机器总状态。

  设计原则：
  1. 本块不负责工艺状态机，也不替代 `FB_Clamp`、`FB_Inject` 等模块的动作逻辑。
  2. 本块只做最终一层轴抽象：接管共享轴结构，整理出可下发的最终命令。
  3. 当模块层误下发越界命令时，本块会做保护性限幅，并把报警叠加回轴故障码。
*)
FUNCTION_BLOCK FB_HydAxis
VAR_IN_OUT
    stAxisRef: ST_AxisRefHyd;      // 共享轴引用；模块层写目标值，轴层做最终整理
END_VAR
VAR_INPUT
    (* 控制命令。 *)
    bStart: BOOL;          // TRUE=当前模块要求轴层进入执行态并输出本拍目标命令。
    bStop: BOOL;           // TRUE=当前模块要求轴层按正常停止语义撤销命令。
    bEStop: BOOL;          // TRUE=当前模块要求轴层按急停语义立即切断命令并上报报警。
    bReset: BOOL;          // TRUE=当前模块要求轴层清空状态、命令与累计时间。
    bDir: BOOL;            // TRUE=当前模块定义的“正向/进向”方向；当前版本只保留在接口层，便于后续对接真实驱动。

    (* 模式选择。 *)
    uiMode: UINT;          // 0=无模式 1=位置模式 2=速度模式 3=扭矩/压力模式。

    (* 参数设定。 *)
    uiCmdPres: UINT;       // 当前扫描周期压力目标；轴层会做上限保护后写入最终压力命令。
    uiSpd: UINT;           // 当前扫描周期速度目标；轴层会做上限保护后写入最终速度命令。
    udiPos: UDINT;         // 当前扫描周期位置目标；轴层会做行程保护后写入最终位置命令。
    uiForce: UINT;         // 当前扫描周期力目标；若压力目标未给出，则轴层允许用该值回填压力命令。
    uiAcc: UINT;           // 当前扫描周期加速度目标；当前公共轴边界尚未单独收口，仅保留接口。
    uiDec: UINT;           // 当前扫描周期减速度目标；当前公共轴边界尚未单独收口，仅保留接口。
    uiJerk: UINT;          // 当前扫描周期加加速度目标；当前公共轴边界尚未单独收口，仅保留接口。
END_VAR
VAR_OUTPUT
    (* 状态输出。 *)
    bBusy: BOOL;           // TRUE=轴层当前仍保持有效执行命令。
    bDone: BOOL;           // TRUE=轴层当前未执行命令且状态健康，可视为本拍已完成。
    bAlarm: BOOL;          // TRUE=轴层当前存在报警。

    (* 报警信息。 *)
    dwAlarmID: DWORD;      // 当前轴层最终报警码；0=无报警。
END_VAR
VAR
    tPulse: TON;                           // 100ms 节拍定时器；用于把连续执行时间累加成秒。
    udiElapsedMs: UDINT := 0;             // 当前连续命令保持时间，单位 ms。
    dwAxisFault: DWORD := DWORD#0;        // 当前扫描周期轴层最终报警码缓存；先继承模块报警，再叠加轴层保护报警。
    rTargetPosition: LREAL := 0.0;        // 当前扫描周期由接口位置目标换算得到的位置命令缓存。
    rTargetVelocity: LREAL := 0.0;        // 当前扫描周期由接口速度目标换算得到的速度命令缓存。
    rTargetPressure: LREAL := 0.0;        // 当前扫描周期由接口压力/力目标换算得到的压力命令缓存。
    bAxisEnabledLocal: BOOL := FALSE;     // TRUE=当前轴层未被停止或急停压停，可接受健康状态计算。
    bCommandActiveLocal: BOOL := FALSE;   // TRUE=当前扫描周期轴层最终输出了有效执行命令。
END_VAR

(* 每个扫描周期先把模块预置的轴配置镜像回公共快捷字段，便于上层统一查看轴身份和保护边界。 *)
stAxisRef.nAxisID := stAxisRef.stConfig.nAxisID;
stAxisRef.rMaxCylinderStroke := stAxisRef.stConfig.rMaxCylinderStroke;
stAxisRef.rMaxVelocity := stAxisRef.stConfig.rMaxVelocity;
stAxisRef.rMaxPressure := stAxisRef.stConfig.rMaxPressure;

(* 每个扫描周期都先把接口输入换算成轴层内部统一使用的浮点目标值。 *)
rTargetPosition := TO_LREAL(udiPos);
rTargetVelocity := TO_LREAL(uiSpd);
rTargetPressure := TO_LREAL(uiCmdPres);

(* 若当前拍未显式给压力目标，但给出了力目标，则允许先用力目标回填压力命令。 *)
IF (rTargetPressure <= 0.0) AND (uiForce > UINT#0) THEN
    rTargetPressure := TO_LREAL(uiForce);
END_IF;

(* 先继承模块层已经写入的报警位，再叠加轴层自己的保护报警。 *)
dwAxisFault := TO_DWORD(TO_UINT(stAxisRef.nFaultCode));

(* 当前轴层是否允许工作只由停止与急停收口；是否真正输出命令再由 `bStart` 决定。 *)
bAxisEnabledLocal := (NOT bStop) AND (NOT bEStop);
bCommandActiveLocal := FALSE;

IF bReset THEN
    (* 复位时统一清空轴层命令、状态、报警与计时，但保留模块回写的现场实际反馈。 *)
    stAxisRef.bActive := FALSE;
    stAxisRef.rSetPosition := 0.0;
    stAxisRef.rSetVelocity := 0.0;
    stAxisRef.rSetPressure := 0.0;
    stAxisRef.stPumpRequest.bRequest := FALSE;
    stAxisRef.stPumpRequest.rFlowSet := 0.0;
    stAxisRef.stPumpRequest.rPressureSet := 0.0;
    stAxisRef.eAxisState := Idle;
    stAxisRef.nFaultCode := 0;

    stAxisRef.stStatus.bEnabled := FALSE;
    stAxisRef.stStatus.bReady := FALSE;
    stAxisRef.stStatus.bCommandActive := FALSE;
    stAxisRef.stStatus.bInPosition := FALSE;
    stAxisRef.stStatus.bInVelocity := FALSE;
    stAxisRef.stStatus.bInPressure := FALSE;
    stAxisRef.stStatus.bAlarm := FALSE;
    stAxisRef.stStatus.dwAlarmID := DWORD#0;
    stAxisRef.stStatus.uiActTime := UINT#0;
    stAxisRef.stStatus.rCmdPosition := 0.0;
    stAxisRef.stStatus.rCmdVelocity := 0.0;
    stAxisRef.stStatus.rCmdPressure := 0.0;

    udiElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
ELSE
    (* 当前架构只支持 1..3 三种标准模式；若收到无效模式则直接记轴层报警。 *)
    IF bStart AND ((uiMode = UINT#0) OR (uiMode > UINT#3)) THEN
        dwAxisFault := dwAxisFault OR DWORD#16#0020;
    END_IF;

    (* 先对位置目标做基础限幅，避免模块层把越界行程直接透传到最终轴命令。 *)
    IF rTargetPosition < 0.0 THEN
        rTargetPosition := 0.0;
        dwAxisFault := dwAxisFault OR DWORD#16#0002;
    ELSIF (stAxisRef.stConfig.rMaxCylinderStroke > 0.0) AND (rTargetPosition > stAxisRef.stConfig.rMaxCylinderStroke) THEN
        rTargetPosition := stAxisRef.stConfig.rMaxCylinderStroke;
        dwAxisFault := dwAxisFault OR DWORD#16#0002;
    END_IF;

    (* 再对速度目标做基础限幅，避免模块层透传超出轴能力的速度命令。 *)
    IF rTargetVelocity < 0.0 THEN
        rTargetVelocity := 0.0;
        dwAxisFault := dwAxisFault OR DWORD#16#0004;
    ELSIF (stAxisRef.stConfig.rMaxVelocity > 0.0) AND (rTargetVelocity > stAxisRef.stConfig.rMaxVelocity) THEN
        rTargetVelocity := stAxisRef.stConfig.rMaxVelocity;
        dwAxisFault := dwAxisFault OR DWORD#16#0004;
    END_IF;

    (* 最后对压力目标做基础限幅，避免模块层透传超压命令。 *)
    IF rTargetPressure < 0.0 THEN
        rTargetPressure := 0.0;
        dwAxisFault := dwAxisFault OR DWORD#16#0008;
    ELSIF (stAxisRef.stConfig.rMaxPressure > 0.0) AND (rTargetPressure > stAxisRef.stConfig.rMaxPressure) THEN
        rTargetPressure := stAxisRef.stConfig.rMaxPressure;
        dwAxisFault := dwAxisFault OR DWORD#16#0008;
    END_IF;

    IF bEStop THEN
        (* 急停优先级最高；一旦急停成立，立即切断全部命令并把状态打入停止态。 *)
        dwAxisFault := dwAxisFault OR DWORD#16#0010;
        stAxisRef.bActive := FALSE;
        stAxisRef.rSetPosition := 0.0;
        stAxisRef.rSetVelocity := 0.0;
        stAxisRef.rSetPressure := 0.0;
        stAxisRef.stPumpRequest.bRequest := FALSE;
        stAxisRef.stPumpRequest.rFlowSet := 0.0;
        stAxisRef.stPumpRequest.rPressureSet := 0.0;
        stAxisRef.eAxisState := Stop;
        udiElapsedMs := 0;
        tPulse(IN := FALSE, PT := T#100MS);
    ELSIF bStop THEN
        (* 正常停止时同样撤销命令，但不额外新增急停报警位。 *)
        stAxisRef.bActive := FALSE;
        stAxisRef.rSetPosition := 0.0;
        stAxisRef.rSetVelocity := 0.0;
        stAxisRef.rSetPressure := 0.0;
        stAxisRef.stPumpRequest.bRequest := FALSE;
        stAxisRef.stPumpRequest.rFlowSet := 0.0;
        stAxisRef.stPumpRequest.rPressureSet := 0.0;
        stAxisRef.eAxisState := Stop;
        udiElapsedMs := 0;
        tPulse(IN := FALSE, PT := T#100MS);
    ELSIF bStart AND (uiMode >= UINT#1) AND (uiMode <= UINT#3) THEN
        (* 当前模块要求轴层执行且模式有效时，把本拍接口命令整理为最终轴命令。 *)
        bCommandActiveLocal := TRUE;
        stAxisRef.bActive := TRUE;
        stAxisRef.rSetPosition := rTargetPosition;
        stAxisRef.rSetVelocity := rTargetVelocity;
        stAxisRef.rSetPressure := rTargetPressure;
        stAxisRef.stPumpRequest.bRequest := TRUE;
        stAxisRef.stPumpRequest.rFlowSet := rTargetVelocity;
        stAxisRef.stPumpRequest.rPressureSet := rTargetPressure;
        stAxisRef.eAxisState := Running;

        (* 连续执行时每累计 100ms 就把动作时间加 100ms，最终再换算成秒。 *)
        tPulse(IN := TRUE, PT := T#100MS);
        IF tPulse.Q THEN
            udiElapsedMs := udiElapsedMs + 100;
            tPulse(IN := FALSE, PT := T#100MS);
        END_IF;
    ELSE
        (* 未启动时统一回空闲态，避免旧命令在共享轴结构里残留。 *)
        stAxisRef.bActive := FALSE;
        stAxisRef.rSetPosition := 0.0;
        stAxisRef.rSetVelocity := 0.0;
        stAxisRef.rSetPressure := 0.0;
        stAxisRef.stPumpRequest.bRequest := FALSE;
        stAxisRef.stPumpRequest.rFlowSet := 0.0;
        stAxisRef.stPumpRequest.rPressureSet := 0.0;
        stAxisRef.eAxisState := Idle;
        udiElapsedMs := 0;
        tPulse(IN := FALSE, PT := T#100MS);
    END_IF;

    (* 最终把轴层执行结果统一写回状态结构，供模块层和主控层直接读取。 *)
    stAxisRef.stStatus.bEnabled := bAxisEnabledLocal;
    stAxisRef.stStatus.bReady := bAxisEnabledLocal AND (dwAxisFault = DWORD#0);
    stAxisRef.stStatus.bCommandActive := bCommandActiveLocal;
    stAxisRef.stStatus.bInPosition := ABS(stAxisRef.rActualPosition - stAxisRef.rSetPosition) <= stAxisRef.stConfig.rPosTolerance;
    stAxisRef.stStatus.bInVelocity := ABS(stAxisRef.rActualVelocity - stAxisRef.rSetVelocity) <= stAxisRef.stConfig.rVelTolerance;
    stAxisRef.stStatus.bInPressure := ABS(stAxisRef.rActualPressure - stAxisRef.rSetPressure) <= stAxisRef.stConfig.rPresTolerance;
    stAxisRef.stStatus.bAlarm := (dwAxisFault <> DWORD#0);
    stAxisRef.stStatus.dwAlarmID := dwAxisFault;
    stAxisRef.stStatus.uiActTime := TO_UINT(udiElapsedMs / 1000);
    stAxisRef.stStatus.rCmdPosition := stAxisRef.rSetPosition;
    stAxisRef.stStatus.rCmdVelocity := stAxisRef.rSetVelocity;
    stAxisRef.stStatus.rCmdPressure := stAxisRef.rSetPressure;

    (* 再把轴层最终报警码回写到共享轴故障码，便于模块层与主控层统一读取。 *)
    stAxisRef.nFaultCode := TO_INT(stAxisRef.stStatus.dwAlarmID);
END_IF;

(* 统一从共享轴状态结构导出简化状态输出，便于老接口或外层模块直接消费。 *)
bBusy := stAxisRef.stStatus.bCommandActive;
bDone := (NOT stAxisRef.stStatus.bCommandActive) AND stAxisRef.stStatus.bReady AND (NOT bStart);
bAlarm := stAxisRef.stStatus.bAlarm;
dwAlarmID := stAxisRef.stStatus.dwAlarmID;
END_FUNCTION_BLOCK
