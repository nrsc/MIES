#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3 // Use modern global access method and strict wave access.
#pragma rtFunctionErrors=1
#pragma ModuleName=PatchSeqPipetteInBath

/// @brief Acquire data with the given DAQSettings
static Function AcquireData(STRUCT DAQSettings& s, string device, [FUNCREF CALLABLE_PROTO postInitializeFunc, FUNCREF CALLABLE_PROTO preAcquireFunc])
	string stimset

	if(!ParamIsDefault(postInitializeFunc))
		postInitializeFunc(device)
	endif

	EnsureMCCIsOpen()

	string unlockedDevice = DAP_CreateDAEphysPanel()

	PGC_SetAndActivateControl(unlockedDevice, "popup_MoreSettings_Devices", str=device)
	PGC_SetAndActivateControl(unlockedDevice, "button_SettingsPlus_LockDevice")

	REQUIRE(WindowExists(device))

	PGC_SetAndActivateControl(device, "ADC", val=0)
	DoUpdate/W=$device

	PGC_SetAndActivateControl(device, "Popup_Settings_HEADSTAGE", val = 0)
	PGC_SetAndActivateControl(device, "button_Hardware_ClearChanConn")

	PGC_SetAndActivateControl(device, "Popup_Settings_HEADSTAGE", val = 1)
	PGC_SetAndActivateControl(device, "button_Hardware_ClearChanConn")

	PGC_SetAndActivateControl(device, "Popup_Settings_HeadStage", val = PSQ_TEST_HEADSTAGE)
	PGC_SetAndActivateControl(device, "popup_Settings_Amplifier", val = 1)

	PGC_SetAndActivateControl(device, DAP_GetClampModeControl(V_CLAMP_MODE, PSQ_TEST_HEADSTAGE), val=1)

	DoUpdate/W=$device

	PGC_SetAndActivateControl(device, "SetVar_DataAcq_TPBaselinePerc", val = 25)

	PGC_SetAndActivateControl(device, "Popup_Settings_VC_DA", str = "0")
	PGC_SetAndActivateControl(device, "Popup_Settings_IC_DA", str = "0")
	PGC_SetAndActivateControl(device, "Popup_Settings_VC_AD", str = "1")
	PGC_SetAndActivateControl(device, "Popup_Settings_IC_AD", str = "1")

	PGC_SetAndActivateControl(device, "button_Hardware_AutoGainAndUnit")

	PGC_SetAndActivateControl(device, GetPanelControl(PSQ_TEST_HEADSTAGE, CHANNEL_TYPE_HEADSTAGE, CHANNEL_CONTROL_CHECK), val=1)

	stimset = "PSQ_QC_stimsets_DA_0"
	AdjustAnalysisParamsForPSQ(device, stimset)
	PGC_SetAndActivateControl(device, GetPanelControl(0, CHANNEL_TYPE_DAC, CHANNEL_CONTROL_WAVE), str = stimset)

	PGC_SetAndActivateControl(device, "check_Settings_MD", val = s.MD)
	PGC_SetAndActivateControl(device, "Check_DataAcq1_RepeatAcq", val = s.RA)
	PGC_SetAndActivateControl(device, "Check_DataAcq_Indexing", val = s.IDX)
	PGC_SetAndActivateControl(device, "Check_DataAcq1_IndexingLocked", val = s.LIDX)
	PGC_SetAndActivateControl(device, "SetVar_DataAcq_SetRepeats", val = s.RES)
	PGC_SetAndActivateControl(device, "Check_Settings_SkipAnalysFuncs", val = 0)

	if(!s.MD)
		PGC_SetAndActivateControl(device, "Check_Settings_BackgrndDataAcq", val = s.BKG_DAQ)
	else
		CHECK_EQUAL_VAR(s.BKG_DAQ, 1)
	endif

	DoUpdate/W=$device

	if(!ParamIsDefault(preAcquireFunc))
		preAcquireFunc(device)
	endif

	OpenDatabrowser()

	StartZeroMQSockets(forceRestart = 1)

	zeromq_sub_add_filter("")
	zeromq_sub_connect("tcp://127.0.0.1:" + num2str(ZEROMQ_BIND_PUB_PORT))

	WaitForPubSubHeartbeat()

	PGC_SetAndActivateControl(device, "DataAcquireButton")
End

static Function TuneBrowser_IGNORE()

	string databrowser, settingsHistoryPanel
	variable i, numEntries

	databrowser = DB_FindDataBrowser("ITC18USB_DEV_0")
	settingsHistoryPanel = LBV_GetSettingsHistoryPanel(databrowser)

	PGC_SetAndActivateControl(settingsHistoryPanel, "button_clearlabnotebookgraph")

	STRUCT WMPopupAction pa
	pa.win = settingsHistoryPanel
	pa.eventCode = 2

	Make/FREE/T keys = {                                 \
	                     PSQ_FMT_LBN_RMS_SHORT_PASS,     \
	                     PSQ_FMT_LBN_RMS_LONG_PASS,      \
	                     PSQ_FMT_LBN_LEAKCUR_PASS,       \
	                     PSQ_FMT_LBN_LEAKCUR,            \
	                     PSQ_FMT_LBN_LEAKCUR_PASS,       \
	                     PSQ_FMT_LBN_CHUNK_PASS,         \
	                     PSQ_FMT_LBN_BL_QC_PASS,         \
	                     PSQ_FMT_LBN_SWEEP_PASS,         \
	                     PSQ_FMT_LBN_SET_PASS,           \
	                     PSQ_FMT_LBN_PB_RESISTANCE,      \
	                     PSQ_FMT_LBN_PB_RESISTANCE_PASS  \
	                   }

	numEntries = DimSize(keys, ROWS)
	for(i = 0; i < numEntries; i += 1)

		if(!cmpstr(keys[i], PSQ_FMT_LBN_RMS_SHORT_PASS) || !cmpstr(keys[i], PSQ_FMT_LBN_RMS_LONG_PASS) || !cmpstr(keys[i], PSQ_FMT_LBN_CHUNK_PASS) || !cmpstr(keys[i], PSQ_FMT_LBN_LEAKCUR) || !cmpstr(keys[i], PSQ_FMT_LBN_LEAKCUR_PASS))
			pa.popStr = CreateAnaFuncLBNKey(PSQ_PIPETTE_BATH, keys[i], chunk = 0, query = 1)
		else
			pa.popStr = CreateAnaFuncLBNKey(PSQ_PIPETTE_BATH, keys[i], query = 1)
		endif

		LBV_PopMenuProc_LabNotebookAndResults(pa)
	endfor
End

static Function/WAVE GetResultsSingleEntry_IGNORE(string name)
	WAVE/T textualResultsValues = GetTextualResultsValues()

	WAVE/Z indizesName = GetNonEmptyLBNRows(textualResultsValues, name)
	WAVE/Z indizesType = GetNonEmptyLBNRows(textualResultsValues, "EntrySourceType")

	if(!WaveExists(indizesName) || !WaveExists(indizesType))
		return $""
	endif

	indizesType[] = (str2numSafe(textualResultsValues[indizesType[p]][%$"EntrySourceType"][INDEP_HEADSTAGE]) == SWEEP_FORMULA_RESULT) ? indizesType[p] : NaN

	WAVE/Z indizesTypeClean = ZapNaNs(indizesType)

	if(!WaveExists(indizesTypeClean))
		return $""
	endif

	WAVE/Z indizes = GetSetIntersection(indizesName, indizesTypeClean)

	if(!WaveExists(indizes))
		return $""
	endif

	Make/FREE/T/N=(DimSize(indizes, ROWS)) entries = textualResultsValues[indizes[p]][%$name][INDEP_HEADSTAGE]

	return entries
End

static Function/WAVE GetLBNSingleEntry_IGNORE(device, sweepNo, name)
	string device
	variable sweepNo
	string name

	variable val, type
	string key

	CHECK(IsValidSweepNumber(sweepNo))
	CHECK_LE_VAR(sweepNo, AFH_GetLastSweepAcquired(device))

	WAVE numericalValues = GetLBNumericalValues(device)
	WAVE textualValues = GetLBTextualValues(device)

	type = PSQ_PIPETTE_BATH

	strswitch(name)
		case PSQ_FMT_LBN_SWEEP_PASS:
		case PSQ_FMT_LBN_PB_RESISTANCE:
		case PSQ_FMT_LBN_PB_RESISTANCE_PASS:
			key = CreateAnaFuncLBNKey(type, name, query = 1)
			return GetLastSettingIndepEachSCI(numericalValues, sweepNo, key, PSQ_TEST_HEADSTAGE, UNKNOWN_MODE)
		case PSQ_FMT_LBN_BL_QC_PASS:
			key = CreateAnaFuncLBNKey(type, name, query = 1)
			return GetLastSettingEachSCI(numericalValues, sweepNo, key, PSQ_TEST_HEADSTAGE, UNKNOWN_MODE)
		case PSQ_FMT_LBN_SET_PASS:
			key = CreateAnaFuncLBNKey(type, name, query = 1)
			val = GetLastSettingIndepSCI(numericalValues, sweepNo, key, PSQ_TEST_HEADSTAGE, UNKNOWN_MODE)
			Make/D/FREE wv = {val}
			return wv
		case PSQ_FMT_LBN_RMS_SHORT_PASS:
		case PSQ_FMT_LBN_RMS_LONG_PASS:
		case PSQ_FMT_LBN_LEAKCUR_PASS:
		case PSQ_FMT_LBN_LEAKCUR:
			key = CreateAnaFuncLBNKey(type, name, chunk = 0, query = 1)
			return GetLastSettingEachSCI(numericalValues, sweepNo, key, PSQ_TEST_HEADSTAGE, UNKNOWN_MODE)
		default:
			FAIL()
	endswitch
End

static Function/WAVE GetWave_IGNORE()

	string list = "sweepPass;setPass;rmsShortPass;rmsLongPass;leakCur;leakCurPass;baselinePass;resistance;resistancePass;resultsSweep;resultsResistance"

	Make/FREE/WAVE/N=(ItemsInList(list)) wv
	SetDimensionLabels(wv, list, ROWS)

	return wv
End

static Function/WAVE GetEntries_IGNORE(string device, variable sweepNo)

	WAVE numericalValues = GetLBNumericalValues(device)

	WAVE/WAVE wv = GetWave_IGNORE()

	wv[%sweepPass] = GetLBNSingleEntry_IGNORE(device, sweepNo, PSQ_FMT_LBN_SWEEP_PASS)
	wv[%setPass] = GetLBNSingleEntry_IGNORE(device, sweepNo, PSQ_FMT_LBN_SET_PASS)

	wv[%rmsShortPass] = GetLBNSingleEntry_IGNORE(device, sweepNo, PSQ_FMT_LBN_RMS_SHORT_PASS)
	wv[%rmsLongPass] = GetLBNSingleEntry_IGNORE(device, sweepNo, PSQ_FMT_LBN_RMS_LONG_PASS)
	wv[%leakCur] = GetLBNSingleEntry_IGNORE(device, sweepNo, PSQ_FMT_LBN_LEAKCUR)
	wv[%leakCurPass] = GetLBNSingleEntry_IGNORE(device, sweepNo, PSQ_FMT_LBN_LEAKCUR_PASS)
	wv[%baselinePass] = GetLBNSingleEntry_IGNORE(device, sweepNo, PSQ_FMT_LBN_BL_QC_PASS)

	wv[%resistance] = GetLBNSingleEntry_IGNORE(device, sweepNo, PSQ_FMT_LBN_PB_RESISTANCE)
	wv[%resistancePass] = GetLBNSingleEntry_IGNORE(device, sweepNo, PSQ_FMT_LBN_PB_RESISTANCE_PASS)

	wv[%resultsSweep] = GetResultsSingleEntry_IGNORE("Sweep Formula displayed Sweeps")
	wv[%resultsResistance] = GetResultsSingleEntry_IGNORE("Sweep Formula store [Steady state resistance]")

	return wv
End

static Function/S GetStimset_IGNORE(string device)
	variable DAC

	DAC = AFH_GetDACFromHeadstage(device, PSQ_TEST_HEADSTAGE)
	return AFH_GetStimSetName(device, DAC, CHANNEL_TYPE_DAC)
End

static Function CheckTestPulseLikeEpochs(string device,[variable incomplete])

	if(ParamIsDefault(incomplete))
		incomplete = 0
	else
		incomplete = !!incomplete
	endif

	// user epochs are the same for all sweeps, so we only check the first sweep

	if(!incomplete)
		CheckUserEpochs(device, {520, 1030, 1030, 1540, 1540, 2050}, EPOCH_SHORTNAME_USER_PREFIX + "TP%d", sweep = 0)
		CheckUserEpochs(device, {520, 770, 1030, 1280, 1540, 1790}, EPOCH_SHORTNAME_USER_PREFIX + "TP%d_B0", sweep = 0)
		CheckUserEpochs(device, {770, 780, 1280, 1290, 1790, 1800}, EPOCH_SHORTNAME_USER_PREFIX + "TP%d_P", sweep = 0)
		CheckUserEpochs(device, {780, 1030, 1290, 1540, 1800, 2050}, EPOCH_SHORTNAME_USER_PREFIX + "TP%d_B1", sweep = 0)
	else
		// due to timing issues on failed sets/sweeps we don't know how many and what epochs we have
		Make/FREE/N=0 times
		CheckUserEpochs(device, times, "TP%d", ignoreIncomplete = 1, sweep = 0)
		CheckUserEpochs(device, times, "TP%d_B0", ignoreIncomplete = 1, sweep = 0)
		CheckUserEpochs(device, times, "TP%d_P", ignoreIncomplete = 1, sweep = 0)
		CheckUserEpochs(device, times, "TP%d_B1", ignoreIncomplete = 1, sweep = 0)
	endif
End

static Function PS_PB1_IGNORE(device)
	string device

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSLongThreshold", var=0.5)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSShortThreshold", var=0.07)

	// SamplingMultiplier, SamplingFrequency use defaults

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxLeakCurrent", var=2)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MinPipetteResistance", var=10)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxPipetteResistance", var=15)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfFailedSweeps", var=3)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NextStimSetName", str="StimulusSetA_DA_0")
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfTestpulses", var=3)
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_PB1([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")

	AcquireData(s, str, preAcquireFunc=PS_PB1_IGNORE)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_PIPETTE_BATH)

	// all tests fail
	wv[][][0] = 0
	wv[][][1] = 5
End

static Function PS_PB1_REENTRY([str])
	string str

	variable sweepNo, autobiasV
	string lbl, failedPulses, spikeCounts, stimset, expected

	sweepNo = 2

	WAVE/WAVE entries = GetEntries_IGNORE(str, sweepNo)

	CHECK_EQUAL_WAVES(entries[%setPass], {0}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%sweepPass], {0, 0, 0}, mode = WAVE_DATA)

	CHECK_EQUAL_WAVES(entries[%baselinePass], {0, 0, 0}, mode = WAVE_DATA)
	CHECK_WAVE(entries[%leakCurPass], NULL_WAVE)
	CHECK_WAVE(entries[%leakCur], NULL_WAVE)

	Make/D resistanceRef = {5e6, 5e6, 5e6}
	CHECK_EQUAL_WAVES(entries[%resistance], resistanceRef, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%resistancePass], {0, 0, 0}, mode = WAVE_DATA)

	stimset  = GetStimset_IGNORE(str)
	expected = "PSQ_QC_stimsets_DA_0"
	CHECK_EQUAL_STR(stimset, expected)

	CHECK_WAVE(entries[%resultsSweep], NULL_WAVE)
	CHECK_WAVE(entries[%resultsResistance], NULL_WAVE)

	CommonAnalysisFunctionChecks(str, sweepNo, entries[%setPass])
	CheckPSQChunkTimes(str, {20, 520})
	CheckTestPulseLikeEpochs(str, incomplete = 1)
End

static Function PS_PB2_IGNORE(device)
	string device

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSLongThreshold", var=0.5)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSShortThreshold", var=0.07)

	// SamplingMultiplier, SamplingFrequency use defaults

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxLeakCurrent", var=2)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MinPipetteResistance", var=10)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxPipetteResistance", var=15)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfFailedSweeps", var=3)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NextStimSetName", str="StimulusSetA_DA_0")
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfTestpulses", var=3)
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_PB2([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")

	AcquireData(s, str, preAcquireFunc=PS_PB2_IGNORE)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_PIPETTE_BATH)

	// all tests pass
	wv[][][0] = 1
	wv[][][1] = 12.5
End

static Function PS_PB2_REENTRY([str])
	string str

	variable sweepNo, autobiasV
	string lbl, failedPulses, spikeCounts, stimset, expected

	sweepNo = 0

	WAVE/WAVE entries = GetEntries_IGNORE(str, sweepNo)

	CHECK_EQUAL_WAVES(entries[%setPass], {1}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%sweepPass], {1}, mode = WAVE_DATA)

	CHECK_EQUAL_WAVES(entries[%baselinePass], {1}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%leakCurPass], {1}, mode = WAVE_DATA)
	CHECK_WAVE(entries[%leakCur], NUMERIC_WAVE)

	Make/FREE/D resistanceRef = {12.5e6}
	CHECK_EQUAL_WAVES(entries[%resistance], resistanceRef, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%resistancePass], {1}, mode = WAVE_DATA)

	stimset  = GetStimset_IGNORE(str)
	expected = "StimulusSetA_DA_0"
	CHECK_EQUAL_STR(stimset, expected)

	CHECK_EQUAL_TEXTWAVES(entries[%resultsSweep], {"0;"}, mode = WAVE_DATA)
	CHECK_WAVE(entries[%resultsResistance], TEXT_WAVE)
	CHECK_EQUAL_VAR(DimSize(entries[%resultsResistance], Rows), 1)

	CommonAnalysisFunctionChecks(str, sweepNo, entries[%setPass])
	CheckPSQChunkTimes(str, {20, 520})
	CheckTestPulseLikeEpochs(str, incomplete = 0)
End

static Function PS_PB3_IGNORE(device)
	string device

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSLongThreshold", var=0.5)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSShortThreshold", var=0.07)

	// SamplingMultiplier, SamplingFrequency use defaults

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxLeakCurrent", var=2)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MinPipetteResistance", var=10)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxPipetteResistance", var=15)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfFailedSweeps", var=3)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NextStimSetName", str="StimulusSetA_DA_0")
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfTestpulses", var=3)
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_PB3([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")

	AcquireData(s, str, preAcquireFunc=PS_PB3_IGNORE)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_PIPETTE_BATH)

	// Sweep 1:
	// baseline QC passes, resistance QC fails
	wv[][0][0] = 1
	wv[][0][1] = 5

	// Sweep 2:
	// baseline QC fails, resistance QC passes
	wv[][1][0] = 0
	wv[][1][1] = 12.5

	// Sweep 3:
	// baseline QC passes, resistance QC fails
	wv[][2][0] = 1
	wv[][2][1] = 5
End

static Function PS_PB3_REENTRY([str])
	string str

	variable sweepNo, autobiasV
	string lbl, failedPulses, spikeCounts, stimset, expected

	sweepNo = 2

	WAVE/WAVE entries = GetEntries_IGNORE(str, sweepNo)

	CHECK_EQUAL_WAVES(entries[%setPass], {0}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%sweepPass], {0, 0, 0}, mode = WAVE_DATA)

	CHECK_EQUAL_WAVES(entries[%baselinePass], {1, 0, 1}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%leakCurPass], {1, NaN, 1}, mode = WAVE_DATA)
	CHECK_WAVE(entries[%leakCur], NUMERIC_WAVE)

	Make/FREE/D resistanceRef = {5e6, 12.5e6, 5e6}
	CHECK_EQUAL_WAVES(entries[%resistance], resistanceRef, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%resistancePass], {0, 1, 0}, mode = WAVE_DATA)

	stimset  = GetStimset_IGNORE(str)
	expected = "PSQ_QC_stimsets_DA_0"
	CHECK_EQUAL_STR(stimset, expected)

	CHECK_EQUAL_TEXTWAVES(entries[%resultsSweep], {"0;", "1;", "2;"}, mode = WAVE_DATA)
	CHECK_WAVE(entries[%resultsResistance], TEXT_WAVE)
	CHECK_EQUAL_VAR(DimSize(entries[%resultsResistance], Rows), 3)

	CommonAnalysisFunctionChecks(str, sweepNo, entries[%setPass])
	CheckPSQChunkTimes(str, {20, 520})
	CheckTestPulseLikeEpochs(str, incomplete = 0)
End

static Function PS_PB4_IGNORE(device)
	string device

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSLongThreshold", var=0.5)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSShortThreshold", var=0.07)

	// SamplingMultiplier, SamplingFrequency use defaults

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxLeakCurrent", var=2)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MinPipetteResistance", var=10)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxPipetteResistance", var=15)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfFailedSweeps", var=2)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NextStimSetName", str="StimulusSetA_DA_0")
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfTestpulses", var=3)
End

// Same as PS_PB1 but has NumberOfFailedSweeps set to 2
// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_PB4([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")

	AcquireData(s, str, preAcquireFunc=PS_PB4_IGNORE)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_PIPETTE_BATH)

	// all tests fail
	wv[][][0] = 0
	wv[][][1] = 5
End

static Function PS_PB4_REENTRY([str])
	string str

	variable sweepNo, autobiasV
	string lbl, failedPulses, spikeCounts, stimset, expected

	sweepNo = 1

	WAVE/WAVE entries = GetEntries_IGNORE(str, sweepNo)

	CHECK_EQUAL_WAVES(entries[%setPass], {0}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%sweepPass], {0, 0}, mode = WAVE_DATA)

	CHECK_EQUAL_WAVES(entries[%baselinePass], {0, 0}, mode = WAVE_DATA)
	CHECK_WAVE(entries[%leakCurPass], NULL_WAVE)
	CHECK_WAVE(entries[%leakCur], NULL_WAVE)

	Make/FREE/D resistanceRef = {5e6, 5e6}
	CHECK_EQUAL_WAVES(entries[%resistance], resistanceRef, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%resistancePass], {0, 0}, mode = WAVE_DATA)

	stimset  = GetStimset_IGNORE(str)
	expected = "PSQ_QC_stimsets_DA_0"
	CHECK_EQUAL_STR(stimset, expected)

	CHECK_WAVE(entries[%resultsSweep], NULL_WAVE)
	CHECK_WAVE(entries[%resultsResistance], NULL_WAVE)

	CommonAnalysisFunctionChecks(str, sweepNo, entries[%setPass])
	CheckPSQChunkTimes(str, {20, 520})
	CheckTestPulseLikeEpochs(str, incomplete = 1)
End

static Function PS_PB5_IGNORE(device)
	string device

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSLongThreshold", var=0.5)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSShortThreshold", var=0.07)

	// SamplingMultiplier, SamplingFrequency use defaults

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxLeakCurrent", var=2)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MinPipetteResistance", var=10)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxPipetteResistance", var=15)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfFailedSweeps", var=3)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NextStimSetName", str="StimulusSetA_DA_0")
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfTestpulses", var=3)
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_PB5([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")

	AcquireData(s, str, preAcquireFunc=PS_PB5_IGNORE)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_PIPETTE_BATH)

	// baseline RMS Short/Long passes, but leakCur fails
	wv[][][0][]  = 1
	wv[][][0][3] = 0

	wv[][][1] = 12.5
End

static Function PS_PB5_REENTRY([str])
	string str

	variable sweepNo, autobiasV
	string lbl, failedPulses, spikeCounts, stimset, expected

	sweepNo = 2

	WAVE/WAVE entries = GetEntries_IGNORE(str, sweepNo)

	CHECK_EQUAL_WAVES(entries[%setPass], {0}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%sweepPass], {0, 0, 0}, mode = WAVE_DATA)

	CHECK_EQUAL_WAVES(entries[%baselinePass], {0, 0, 0}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%rmsShortPass], {1, 1, 1}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%rmsLongPass], {1, 1, 1}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%leakCurPass], {0, 0, 0}, mode = WAVE_DATA)
	CHECK_WAVE(entries[%leakCur], NUMERIC_WAVE)

	Make/FREE/D resistanceRef = {12.5e6, 12.5e6, 12.5e6}
	CHECK_EQUAL_WAVES(entries[%resistance], resistanceRef, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%resistancePass], {1, 1, 1}, mode = WAVE_DATA)

	stimset  = GetStimset_IGNORE(str)
	expected = "PSQ_QC_stimsets_DA_0"
	CHECK_EQUAL_STR(stimset, expected)

	CHECK_WAVE(entries[%resultsSweep], NULL_WAVE)
	CHECK_WAVE(entries[%resultsResistance], NULL_WAVE)

	CommonAnalysisFunctionChecks(str, sweepNo, entries[%setPass])
	CheckPSQChunkTimes(str, {20, 520})
	CheckTestPulseLikeEpochs(str, incomplete = 1)
End

static Function PS_PB6_IGNORE(device)
	string device

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSLongThreshold", var=0.5)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSShortThreshold", var=0.07)

	// SamplingMultiplier, SamplingFrequency use defaults

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxLeakCurrent", var=2)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MinPipetteResistance", var=10)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxPipetteResistance", var=15)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfFailedSweeps", var=3)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NextStimSetName", str="StimulusSetA_DA_0")
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfTestpulses", var=3)
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_PB6([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")

	AcquireData(s, str, preAcquireFunc=PS_PB6_IGNORE)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_PIPETTE_BATH)

	// baseline RMS Short/leakCur passes, but RMS long fails
	wv[][][0][]  = 1
	wv[][][0][1] = 0

	wv[][][1] = 12.5
End

static Function PS_PB6_REENTRY([str])
	string str

	variable sweepNo, autobiasV
	string lbl, failedPulses, spikeCounts, stimset, expected

	sweepNo = 2

	WAVE/WAVE entries = GetEntries_IGNORE(str, sweepNo)

	CHECK_EQUAL_WAVES(entries[%setPass], {0}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%sweepPass], {0, 0, 0}, mode = WAVE_DATA)

	CHECK_EQUAL_WAVES(entries[%baselinePass], {0, 0, 0}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%rmsShortPass], {1, 1, 1}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%rmsLongPass], {0, 0, 0}, mode = WAVE_DATA)
	CHECK_WAVE(entries[%leakCur], NULL_WAVE)
	CHECK_WAVE(entries[%leakCur], NULL_WAVE)

	Make/FREE/D resistanceRef = {12.5e6, 12.5e6, 12.5e6}
	CHECK_EQUAL_WAVES(entries[%resistance], resistanceRef, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%resistancePass], {1, 1, 1}, mode = WAVE_DATA)

	stimset  = GetStimset_IGNORE(str)
	expected = "PSQ_QC_stimsets_DA_0"
	CHECK_EQUAL_STR(stimset, expected)

	CHECK_WAVE(entries[%resultsSweep], NULL_WAVE)
	CHECK_WAVE(entries[%resultsResistance], NULL_WAVE)

	CommonAnalysisFunctionChecks(str, sweepNo, entries[%setPass])
	CheckPSQChunkTimes(str, {20, 520})
	CheckTestPulseLikeEpochs(str, incomplete = 1)
End

static Function PS_PB7_IGNORE(device)
	string device

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSLongThreshold", var=0.5)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "BaselineRMSShortThreshold", var=0.07)

	// SamplingMultiplier, SamplingFrequency use defaults

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxLeakCurrent", var=2)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MinPipetteResistance", var=10)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "MaxPipetteResistance", var=15)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfFailedSweeps", var=3)
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NextStimSetName", str="StimulusSetA_DA_0")
	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "NumberOfTestpulses", var=3)

	AFH_AddAnalysisParameter("PSQ_QC_Stimsets_DA_0", "SamplingFrequency", var=10)
End

// Same as PS_PB2 but with failing sampling interval check
//
// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_PB7([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")

	AcquireData(s, str, preAcquireFunc=PS_PB7_IGNORE)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_PIPETTE_BATH)

	// baseline and resistance QC pass, but sampling interval QC fails
	wv[][][0] = 1
	wv[][][1] = 12.5
End

static Function PS_PB7_REENTRY([str])
	string str

	variable sweepNo, autobiasV
	string lbl, failedPulses, spikeCounts, stimset, expected

	sweepNo = 0

	WAVE/WAVE entries = GetEntries_IGNORE(str, sweepNo)

	CHECK_EQUAL_WAVES(entries[%setPass], {0}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%sweepPass], {0}, mode = WAVE_DATA)

	CHECK_EQUAL_WAVES(entries[%baselinePass], {1}, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%leakCurPass], {1}, mode = WAVE_DATA)
	CHECK_WAVE(entries[%leakCur], NUMERIC_WAVE)

	Make/FREE/D resistanceRef = {12.5e6}
	CHECK_EQUAL_WAVES(entries[%resistance], resistanceRef, mode = WAVE_DATA)
	CHECK_EQUAL_WAVES(entries[%resistancePass], {1}, mode = WAVE_DATA)

	stimset  = GetStimset_IGNORE(str)
	expected = "PSQ_QC_stimsets_DA_0"
	CHECK_EQUAL_STR(stimset, expected)

	CHECK_EQUAL_TEXTWAVES(entries[%resultsSweep], {"0;"}, mode = WAVE_DATA)
	CHECK_WAVE(entries[%resultsResistance], TEXT_WAVE)
	CHECK_EQUAL_VAR(DimSize(entries[%resultsResistance], Rows), 1)

	CommonAnalysisFunctionChecks(str, sweepNo, entries[%setPass])
	CheckPSQChunkTimes(str, {20, 520})
	CheckTestPulseLikeEpochs(str, incomplete = 0)
End
