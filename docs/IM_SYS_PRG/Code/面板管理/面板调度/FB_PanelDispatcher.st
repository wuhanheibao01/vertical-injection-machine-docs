(* 
  FB_PanelDispatcher 功能块
  功能：
  1. 根据顶层选择的硬件面板型号，统一调度 `FB_MK110`、`FB_MK116`、`FB_MK150` 写入当前型号映射。
  2. 把面板原始输入字解码为 `ST_PanelButtons.aButton[*]`，再把关键按键回灌到独立的面板命令源边界。
  3. 把机器模式、模块状态和关键条件回写为面板灯请求，最终汇总到原始面板输出字。

  说明：
  1. 当前块只负责“面板 -> 命令源”和“状态 -> 面板灯”，不再直接写最终机器命令边界。
  2. 面板型号块现在只维护映射；读键与写灯统一由公用层完成，因此同一扫描周期不需要再双调用型号块。
  3. 当前综合按键已改为数组模型，因此“无面板清零”“统一读键”“统一写灯”都改为循环处理，避免新增按钮后继续扩散修改。
  4. 本块只消费 PLC 内部面板原始字边界 `ST_PanelIO`；实际 Modbus 输入输出通讯镜像应由统一 `FB_Modbus` 在本块前后转换。
*)
FUNCTION_BLOCK FB_PanelDispatcher
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;         // 综合面板按键边界；本块负责回写键值和灯值，供顶层与 HMI 统一消费。
    stPanelIO: ST_PanelIO;                   // PLC 内部面板原始字边界；本块负责读取 `uiIN0..uiIN3` 并回写 `uiOUT0..uiOUT3`。
    stCommandSource: ST_MachineCommand;      // 面板命令源边界；本块只回灌由面板直接产生的模式和手动命令。
END_VAR
VAR_INPUT
    ePanelModel: E_PanelModel;               // 当前顶层启用的硬件面板型号；决定本拍调用哪个具体型号块。
    stStatus: ST_MachineStatus;              // 机器状态边界；供本块生成模式灯、动作灯和完成灯。
    stSensor: ST_MachineSensor;              // 机器传感器边界；供本块生成马达/液压相关状态灯。
END_VAR
VAR
    fbMK110: FB_MK110;                       // MK110 面板实例；仅在选择 MK110 时参与本拍映射定义。
    fbMK116: FB_MK116;                       // MK116 面板实例；仅在选择 MK116 时参与本拍映射定义。
    fbMK150: FB_MK150;                       // MK150 面板实例；仅在选择 MK150 时参与本拍映射定义。
    fbPanelReader: FB_PanelReader;           // 通用面板读键器；负责按当前型号映射解码全部逻辑键。
    fbPanelLampEncoder: FB_PanelLampEncoder; // 通用面板灯编码器；负责按当前型号排序号汇总全部输出灯位。

    uiButtonIndex: UINT := 0;                // 通用按钮索引；用于统一清零综合按键数组中的全部按钮项。
    bManualKeyLast: BOOL := FALSE;           // 上一拍的手动模式键值缓存；用于只在按键上升沿切换机器模式。
    bSemiAutoKeyLast: BOOL := FALSE;         // 上一拍的半自动模式键值缓存；用于只在按键上升沿切换机器模式。
    bFullAutoKeyLast: BOOL := FALSE;         // 上一拍的全自动模式键值缓存；用于只在按键上升沿切换机器模式。
    bMoldAdjustKeyLast: BOOL := FALSE;       // 上一拍的调模模式键值缓存；用于只在按键上升沿切换机器模式。
    bMotorKeyLast: BOOL := FALSE;            // 上一拍的马达键值缓存；用于只在按键上升沿翻转马达总命令锁存位。
    bHeaterKeyLast: BOOL := FALSE;           // 上一拍的电热键值缓存；用于只在按键上升沿翻转温控启动命令。
END_VAR

(* 先按当前顶层选择的面板型号，写入对应型号的逻辑排序号。 *)
CASE ePanelModel OF
    ePanel_MK110:
        fbMK110(
            stPanelButtons := stPanelButtons      // 把综合按键结构交给 MK110，写入 MK110 的逻辑排序号定义。
        );
    ePanel_MK116:
        fbMK116(
            stPanelButtons := stPanelButtons      // 把综合按键结构交给 MK116，写入 MK116 的逻辑排序号定义。
        );
    ePanel_MK150:
        fbMK150(
            stPanelButtons := stPanelButtons      // 把综合按键结构交给 MK150，写入 MK150 的逻辑排序号定义。
        );
ELSE
    stPanelIO.uiOUT0 := UINT#0;                   // 未选择任何面板型号时，强制清零输出字 0。
    stPanelIO.uiOUT1 := UINT#0;                   // 未选择任何面板型号时，强制清零输出字 1。
    stPanelIO.uiOUT2 := UINT#0;                   // 未选择任何面板型号时，强制清零输出字 2。
    stPanelIO.uiOUT3 := UINT#0;                   // 未选择任何面板型号时，强制清零输出字 3。

    FOR uiButtonIndex := UINT#0 TO (TO_UINT(ePanelButton_Count) - UINT#1) DO
        stPanelButtons.aButton[uiButtonIndex].uiPanelOrder := UINT#0; // 未选择任何面板型号时，把当前按钮排序号清零，避免旧型号映射残留。
        stPanelButtons.aButton[uiButtonIndex].bValue := FALSE;        // 未选择任何面板型号时，把当前按钮键值清零，避免保留旧面板残值。
        stPanelButtons.aButton[uiButtonIndex].bLamp := FALSE;         // 未选择任何面板型号时，把当前按钮灯请求清零，避免 HMI 继续看到旧灯态。
    END_FOR;
END_CASE;

IF ePanelModel <> ePanel_None THEN
    fbPanelReader(
        stPanelButtons := stPanelButtons,             // 把综合按键结构交给读键器，按当前型号映射回写全部逻辑键值。
        uiIN0 := stPanelIO.uiIN0,                     // 把面板原始输入字 0 交给读键器读取排序号 `1..16` 对应的输入位。
        uiIN1 := stPanelIO.uiIN1,                     // 把面板原始输入字 1 交给读键器读取排序号 `17..32` 对应的输入位。
        uiIN2 := stPanelIO.uiIN2,                     // 把面板原始输入字 2 交给读键器读取排序号 `33..48` 对应的输入位。
        uiIN3 := stPanelIO.uiIN3                      // 把面板原始输入字 3 交给读键器读取排序号 `49..64` 对应的输入位。
    );
END_IF;

(* 再把面板直接驱动的手动命令先清零，避免上一拍的点动命令残留。 *)
stCommandSource.stManual.bClampStart := FALSE;          // 每拍默认清空合模手动启动位，只在当前按键有效时重新拉起。
stCommandSource.stManual.uiClampMode := UINT#0;         // 每拍默认清空合模手动模式号，只在当前按键有效时重新给定。
stCommandSource.stManual.bMoldAdjustStart := FALSE;     // 每拍默认清空调模手动启动位，只在当前按键有效时重新拉起。
stCommandSource.stManual.uiMoldAdjustMode := UINT#0;    // 每拍默认清空调模手动模式号，只在当前按键有效时重新给定。
stCommandSource.stManual.bNozzleStart := FALSE;         // 每拍默认清空座台手动启动位，只在当前按键有效时重新拉起。
stCommandSource.stManual.uiNozzleMode := UINT#0;        // 每拍默认清空座台手动模式号，只在当前按键有效时重新给定。
stCommandSource.stManual.bInjectStart := FALSE;         // 每拍默认清空射胶手动启动位，只在当前按键有效时重新拉起。
stCommandSource.stManual.uiInjectMode := UINT#0;        // 每拍默认清空射胶手动模式号，只在当前按键有效时重新给定。
stCommandSource.stManual.bMeterStart := FALSE;          // 每拍默认清空储料手动启动位，只在当前按键有效时重新拉起。
stCommandSource.stManual.bEjectStart := FALSE;          // 每拍默认清空基础托模手动启动位，只在当前按键有效时重新拉起。
stCommandSource.stManual.uiEjectMode := UINT#0;         // 每拍默认清空基础托模手动模式号，只在当前按键有效时重新给定。
stCommandSource.stManual.bEjectModeStart := FALSE;      // 每拍默认清空组合托模手动启动位；当前版本暂不直接用面板按钮驱动组合托模流程。
stCommandSource.stManual.uiEjectPatternMode := UINT#0;  // 每拍默认清空组合托模模式号；当前版本暂不直接用面板按钮驱动组合托模流程。
stCommandSource.stManual.uiEjectTimes := UINT#0;        // 每拍默认清空组合托模次数；当前版本暂不直接用面板按钮驱动组合托模流程。
stCommandSource.stManual.bCoreStart := FALSE;           // 每拍默认清空中子手动启动位，只在当前按键有效时重新拉起。
stCommandSource.stManual.uiCoreMode := UINT#0;          // 每拍默认清空中子手动模式号，只在当前按键有效时重新给定。
stCommandSource.stManual.bR0 := FALSE;                  // 每拍默认清空温控人工组 0 命令；当前面板未提供对应独立键位。
stCommandSource.stManual.bR1 := FALSE;                  // 每拍默认清空温控人工组 1 命令；当前面板未提供对应独立键位。
stCommandSource.stManual.bR2 := FALSE;                  // 每拍默认清空温控人工组 2 命令；当前面板未提供对应独立键位。
stCommandSource.stManual.bR3 := FALSE;                  // 每拍默认清空温控人工组 3 命令；当前面板未提供对应独立键位。

(* 机器模式键采用上升沿锁存，避免操作员必须持续按住模式键。 *)
IF stPanelButtons.aButton[TO_UINT(ePanelButton_Manual)].bValue AND (NOT bManualKeyLast) THEN
    stCommandSource.uiMachineMode := UINT#1;            // 手动模式键上升沿到来时，把整机模式切换到手动。
END_IF;
IF stPanelButtons.aButton[TO_UINT(ePanelButton_SemiAuto)].bValue AND (NOT bSemiAutoKeyLast) THEN
    stCommandSource.uiMachineMode := UINT#2;            // 半自动模式键上升沿到来时，把整机模式切换到半自动。
END_IF;
IF stPanelButtons.aButton[TO_UINT(ePanelButton_FullAuto)].bValue AND (NOT bFullAutoKeyLast) THEN
    stCommandSource.uiMachineMode := UINT#3;            // 全自动模式键上升沿到来时，把整机模式切换到全自动。
END_IF;
IF stPanelButtons.aButton[TO_UINT(ePanelButton_MoldAdjust)].bValue AND (NOT bMoldAdjustKeyLast) THEN
    stCommandSource.uiMachineMode := UINT#4;            // 调模模式键上升沿到来时，把整机模式切换到调模模式。
END_IF;

(* 马达键采用上升沿翻转主动力启动命令，保证按钮更符合“开关”语义而不是“点动”语义。 *)
IF stPanelButtons.aButton[TO_UINT(ePanelButton_Motor)].bValue AND (NOT bMotorKeyLast) THEN
    stCommandSource.stManual.bMotorStart := NOT stCommandSource.stManual.bMotorStart;             // 马达键每次按下都翻转一次主动力启动锁存值，避免操作员必须持续按住。
END_IF;

(* 电热键采用上升沿翻转温控启动命令，保证按钮更符合“开关”语义而不是“点动”语义。 *)
IF stPanelButtons.aButton[TO_UINT(ePanelButton_Heater)].bValue AND (NOT bHeaterKeyLast) THEN
    stCommandSource.stManual.bTempStart := NOT stCommandSource.stManual.bTempStart; // 电热键每次按下都翻转一次顶层温控启动命令。
END_IF;

(* 再把已有明确语义的面板点动键回灌到面板命令源。 *)
IF stPanelButtons.aButton[TO_UINT(ePanelButton_MoldOpen)].bValue THEN
    stCommandSource.stManual.bClampStart := TRUE;       // 当前按下开模键时，拉起合模块手动启动位。
    stCommandSource.stManual.uiClampMode := UINT#3;     // 当前按下开模键时，把合模块切到“开模调试”模式。
ELSIF stPanelButtons.aButton[TO_UINT(ePanelButton_MoldClose)].bValue THEN
    stCommandSource.stManual.bClampStart := TRUE;       // 当前按下合模键时，拉起合模块手动启动位。
    stCommandSource.stManual.uiClampMode := UINT#4;     // 当前按下合模键时，把合模块切到“合模调试”模式。
END_IF;

IF stPanelButtons.aButton[TO_UINT(ePanelButton_MoldAdjustIn)].bValue THEN
    stCommandSource.stManual.bMoldAdjustStart := TRUE;  // 当前按下调模进键时，拉起调模块手动启动位。
    stCommandSource.stManual.uiMoldAdjustMode := UINT#3;// 当前按下调模进键时，把调模块切到“手动调模进”模式。
ELSIF stPanelButtons.aButton[TO_UINT(ePanelButton_MoldAdjustOut)].bValue THEN
    stCommandSource.stManual.bMoldAdjustStart := TRUE;  // 当前按下调模退键时，拉起调模块手动启动位。
    stCommandSource.stManual.uiMoldAdjustMode := UINT#4;// 当前按下调模退键时，把调模块切到“手动调模退”模式。
END_IF;

IF stPanelButtons.aButton[TO_UINT(ePanelButton_NozzleIn)].bValue THEN
    stCommandSource.stManual.bNozzleStart := TRUE;      // 当前按下座进键时，拉起座台模块手动启动位。
    stCommandSource.stManual.uiNozzleMode := UINT#3;    // 当前按下座进键时，把座台模块切到“座进调试”模式。
ELSIF stPanelButtons.aButton[TO_UINT(ePanelButton_NozzleOut)].bValue THEN
    stCommandSource.stManual.bNozzleStart := TRUE;      // 当前按下座退键时，拉起座台模块手动启动位。
    stCommandSource.stManual.uiNozzleMode := UINT#4;    // 当前按下座退键时，把座台模块切到“座退调试”模式。
END_IF;

IF stPanelButtons.aButton[TO_UINT(ePanelButton_Injection)].bValue THEN
    stCommandSource.stManual.bInjectStart := TRUE;      // 当前按下射出键时，拉起射胶模块手动启动位。
    stCommandSource.stManual.uiInjectMode := UINT#3;    // 当前按下射出键时，把射胶模块切到“射出调试”模式。
ELSIF stPanelButtons.aButton[TO_UINT(ePanelButton_SuckBack)].bValue THEN
    stCommandSource.stManual.bInjectStart := TRUE;      // 当前按下射退键时，拉起射胶模块手动启动位。
    stCommandSource.stManual.uiInjectMode := UINT#4;    // 当前按下射退键时，把射胶模块切到“射退调试”模式。
END_IF;

stCommandSource.stManual.bMeterStart := stPanelButtons.aButton[TO_UINT(ePanelButton_Metering)].bValue; // 储料键直接驱动储料模块手动启动位，保持键值与点动行为一致。

IF stPanelButtons.aButton[TO_UINT(ePanelButton_EjectIn)].bValue THEN
    stCommandSource.stManual.bEjectStart := TRUE;       // 当前按下托模进键时，拉起基础托模块手动启动位。
    stCommandSource.stManual.uiEjectMode := UINT#6;     // 当前按下托模进键时，把基础托模块切到“托模进调试”模式。
ELSIF stPanelButtons.aButton[TO_UINT(ePanelButton_EjectOut)].bValue THEN
    stCommandSource.stManual.bEjectStart := TRUE;       // 当前按下托模退键时，拉起基础托模块手动启动位。
    stCommandSource.stManual.uiEjectMode := UINT#7;     // 当前按下托模退键时，把基础托模块切到“托模退调试”模式。
END_IF;

IF stPanelButtons.aButton[TO_UINT(ePanelButton_CoreAIn)].bValue THEN
    stCommandSource.stManual.bCoreStart := TRUE;        // 当前按下中子 A 进键时，拉起中子模块手动启动位。
    stCommandSource.stManual.uiCoreMode := UINT#3;      // 当前按下中子 A 进键时，把中子模块切到“中子进调试”模式。
ELSIF stPanelButtons.aButton[TO_UINT(ePanelButton_CoreAOut)].bValue THEN
    stCommandSource.stManual.bCoreStart := TRUE;        // 当前按下中子 A 退键时，拉起中子模块手动启动位。
    stCommandSource.stManual.uiCoreMode := UINT#4;      // 当前按下中子 A 退键时，把中子模块切到“中子退调试”模式。
END_IF;

(* 最后把机器关键状态回写为面板灯请求，形成“命令源 -> 状态 -> 灯”的闭环。 *)
stPanelButtons.aButton[TO_UINT(ePanelButton_Manual)].bLamp := stStatus.bManualModeActive;                                              // 手动灯直接跟随机器当前手动模式。
stPanelButtons.aButton[TO_UINT(ePanelButton_SemiAuto)].bLamp := stStatus.bSemiAutoModeActive;                                          // 半自动灯直接跟随机器当前半自动模式。
stPanelButtons.aButton[TO_UINT(ePanelButton_FullAuto)].bLamp := stStatus.bFullAutoModeActive;                                          // 全自动灯直接跟随机器当前全自动模式。
stPanelButtons.aButton[TO_UINT(ePanelButton_MoldAdjust)].bLamp := stStatus.bMoldAdjustModeActive;                                      // 调模灯直接跟随机器当前调模模式。
stPanelButtons.aButton[TO_UINT(ePanelButton_Heater)].bLamp := stCommandSource.stManual.bTempStart;                                     // 电热灯直接跟随当前面板温控启动锁存值。
stPanelButtons.aButton[TO_UINT(ePanelButton_Motor)].bLamp := stSensor.bHydReady;                                                       // 马达灯当前先用液压就绪状态代表主动力允许状态。
stPanelButtons.aButton[TO_UINT(ePanelButton_MoldOpen)].bLamp := stStatus.bMoldOpened;                                                  // 开模灯直接跟随合模块开模到位状态。
stPanelButtons.aButton[TO_UINT(ePanelButton_MoldClose)].bLamp := stStatus.bMoldClosed;                                                 // 合模灯直接跟随合模块合模到位状态。
stPanelButtons.aButton[TO_UINT(ePanelButton_Metering)].bLamp := stStatus.bMeterBusy OR stStatus.bMetered;                             // 储料灯在储料执行或已完成时点亮。
stPanelButtons.aButton[TO_UINT(ePanelButton_CleanMaterial)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_CleanMaterial)].bValue; // 清料灯当前先跟随按键值，等待后续独立清料流程接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_Injection)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_Injection)].bValue OR stStatus.bInjected; // 射出灯在按键保持或射出完成时点亮。
stPanelButtons.aButton[TO_UINT(ePanelButton_SuckBack)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_SuckBack)].bValue OR stStatus.bSuckBacked; // 射退灯在按键保持或射退完成时点亮。
stPanelButtons.aButton[TO_UINT(ePanelButton_EjectIn)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_EjectIn)].bValue OR stStatus.bEjectOuted; // 托模进灯在按键保持或托模外位到位时点亮。
stPanelButtons.aButton[TO_UINT(ePanelButton_EjectOut)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_EjectOut)].bValue OR stStatus.bEjectIned; // 托模退灯在按键保持或托模内位到位时点亮。
stPanelButtons.aButton[TO_UINT(ePanelButton_NozzleIn)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_NozzleIn)].bValue OR stStatus.bNozzleIned; // 座进灯在按键保持或座进到位时点亮。
stPanelButtons.aButton[TO_UINT(ePanelButton_NozzleOut)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_NozzleOut)].bValue OR stStatus.bNozzleOuted; // 座退灯在按键保持或座退到位时点亮。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreAIn)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_CoreAIn)].bValue OR stStatus.bCoreIned; // 中子 A 进灯在按键保持或中子进到位时点亮。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreAOut)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_CoreAOut)].bValue OR stStatus.bCoreOuted; // 中子 A 退灯在按键保持或中子退到位时点亮。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreBIn)].bLamp := FALSE;                                                                    // 当前工程尚未接入中子 B 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreBOut)].bLamp := FALSE;                                                                   // 当前工程尚未接入中子 B 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreCIn)].bLamp := FALSE;                                                                    // 当前工程尚未接入中子 C 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreCOut)].bLamp := FALSE;                                                                   // 当前工程尚未接入中子 C 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreDIn)].bLamp := FALSE;                                                                    // 当前工程尚未接入中子 D 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreDOut)].bLamp := FALSE;                                                                   // 当前工程尚未接入中子 D 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreEIn)].bLamp := FALSE;                                                                    // 当前工程尚未接入中子 E 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreEOut)].bLamp := FALSE;                                                                   // 当前工程尚未接入中子 E 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreFIn)].bLamp := FALSE;                                                                    // 当前工程尚未接入中子 F 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreFOut)].bLamp := FALSE;                                                                   // 当前工程尚未接入中子 F 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreGIn)].bLamp := FALSE;                                                                    // 当前工程尚未接入中子 G 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreGOut)].bLamp := FALSE;                                                                   // 当前工程尚未接入中子 G 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreHIn)].bLamp := FALSE;                                                                    // 当前工程尚未接入中子 H 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_CoreHOut)].bLamp := FALSE;                                                                   // 当前工程尚未接入中子 H 模块，因此灯请求固定为 FALSE。
stPanelButtons.aButton[TO_UINT(ePanelButton_MoldAdjustIn)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_MoldAdjustIn)].bValue OR stStatus.bMoldAdjustIned; // 调模进灯在按键保持或调模进到位时点亮。
stPanelButtons.aButton[TO_UINT(ePanelButton_MoldAdjustOut)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_MoldAdjustOut)].bValue OR stStatus.bMoldAdjustOuted; // 调模退灯在按键保持或调模退到位时点亮。
stPanelButtons.aButton[TO_UINT(ePanelButton_AirBlow)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_AirBlow)].bValue;            // 吹气灯当前先跟随按键值，等待后续吹气模块接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_AirBlowA)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_AirBlowA)].bValue;          // 吹气 A 灯当前先跟随按键值，等待后续吹气模块接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_AirBlowB)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_AirBlowB)].bValue;          // 吹气 B 灯当前先跟随按键值，等待后续吹气模块接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_JetLube)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_JetLube)].bValue;            // 润滑灯当前先跟随按键值，等待后续润滑系统接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_Ejector)].bLamp := stStatus.bEjectModeSelected;                                            // 多次托模灯当前先跟随“组合托模已被选中”状态。
stPanelButtons.aButton[TO_UINT(ePanelButton_LockIn)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_LockIn)].bValue;             // 定位进灯当前先跟随按键值，等待后续定位功能接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_LockOut)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_LockOut)].bValue;           // 定位退灯当前先跟随按键值，等待后续定位功能接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_PressRise)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_PressRise)].bValue;       // 压力加灯当前先跟随按键值，等待后续压力调节功能接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_PressFall)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_PressFall)].bValue;       // 压力减灯当前先跟随按键值，等待后续压力调节功能接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperBwd)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperBwd)].bValue;       // 倒带灯当前先跟随按键值，等待后续拉带系统接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperFwd)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperFwd)].bValue;       // 拉带灯当前先跟随按键值，等待后续拉带系统接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperClamp)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperClamp)].bValue;   // 夹带灯当前先跟随按键值，等待后续拉带系统接入。
stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperMotor)].bLamp := stPanelButtons.aButton[TO_UINT(ePanelButton_ZipperMotor)].bValue;   // 拉带马达灯当前先跟随按键值，等待后续拉带系统接入。

IF ePanelModel <> ePanel_None THEN
    fbPanelLampEncoder(
        stPanelButtons := stPanelButtons,             // 把本拍最新灯请求交给灯编码器，重算当前扫描周期的输出字。
        uiOUT0 => stPanelIO.uiOUT0,                   // 回收当前拍编码后的面板输出字 0。
        uiOUT1 => stPanelIO.uiOUT1,                   // 回收当前拍编码后的面板输出字 1。
        uiOUT2 => stPanelIO.uiOUT2,                   // 回收当前拍编码后的面板输出字 2。
        uiOUT3 => stPanelIO.uiOUT3                    // 回收当前拍编码后的面板输出字 3。
    );
END_IF;

(* 本拍最后再更新上升沿缓存，为下一拍的模式/电热按键边沿判定做准备。 *)
bManualKeyLast := stPanelButtons.aButton[TO_UINT(ePanelButton_Manual)].bValue;                 // 保存当前手动键值，供下一拍判断是否出现新上升沿。
bSemiAutoKeyLast := stPanelButtons.aButton[TO_UINT(ePanelButton_SemiAuto)].bValue;             // 保存当前半自动键值，供下一拍判断是否出现新上升沿。
bFullAutoKeyLast := stPanelButtons.aButton[TO_UINT(ePanelButton_FullAuto)].bValue;             // 保存当前全自动键值，供下一拍判断是否出现新上升沿。
bMoldAdjustKeyLast := stPanelButtons.aButton[TO_UINT(ePanelButton_MoldAdjust)].bValue;         // 保存当前调模键值，供下一拍判断是否出现新上升沿。
bMotorKeyLast := stPanelButtons.aButton[TO_UINT(ePanelButton_Motor)].bValue;                   // 保存当前马达键值，供下一拍判断是否出现新上升沿。
bHeaterKeyLast := stPanelButtons.aButton[TO_UINT(ePanelButton_Heater)].bValue;                 // 保存当前电热键值，供下一拍判断是否出现新上升沿。
END_FUNCTION_BLOCK

