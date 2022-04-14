#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3 // Use modern global access method and strict wave access.
#pragma rtFunctionErrors=1
#pragma ModuleName=PatchSeqTestRheobase

static Constant PSQ_RHEOBASE_TEST_DURATION = 2

/// @brief Acquire data with the given DAQSettings
static Function AcquireData(STRUCT DAQSettings& s, variable finalDAScaleFake, string device, [FUNCREF CALLABLE_PROTO preAcquireFunc])
	string stimset, unlockedDevice

	EnsureMCCIsOpen()

	Make/O/N=(0) root:overrideResults/Wave=overrideResults
	Note/K overrideResults
	SetNumberInWaveNote(overrideResults, PSQ_RB_FINALSCALE_FAKE_KEY, finalDaScaleFake)
	unlockedDevice = DAP_CreateDAEphysPanel()

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

	PGC_SetAndActivateControl(device, DAP_GetClampModeControl(I_CLAMP_MODE, PSQ_TEST_HEADSTAGE), val=1)
	DoUpdate/W=$device

	PGC_SetAndActivateControl(device, "SetVar_DataAcq_TPBaselinePerc", val = 25)

	PGC_SetAndActivateControl(device, "Popup_Settings_VC_DA", str = "0")
	PGC_SetAndActivateControl(device, "Popup_Settings_IC_DA", str = "0")
	PGC_SetAndActivateControl(device, "Popup_Settings_VC_AD", str = "1")
	PGC_SetAndActivateControl(device, "Popup_Settings_IC_AD", str = "1")

	PGC_SetAndActivateControl(device, "button_Hardware_AutoGainAndUnit")

	PGC_SetAndActivateControl(device, "check_DataAcq_AutoBias", val = 1)
	PGC_SetAndActivateControl(device, "setvar_DataAcq_AutoBiasV", val = 70)
	PGC_SetAndActivateControl(device, GetPanelControl(PSQ_TEST_HEADSTAGE, CHANNEL_TYPE_HEADSTAGE, CHANNEL_CONTROL_CHECK), val=1)

	stimset = "Rheobase_DA_0"
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

	PGC_SetAndActivateControl(device, "DataAcquireButton")
	OpenDatabrowser()
End

static Function/WAVE GetSpikeResults_IGNORE(sweepNo, device)
	variable sweepNo
	string device

	string key

	WAVE numericalValues = GetLBNumericalValues(device)
	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SPIKE_DETECT, query = 1)
	return GetLastSettingEachRAC(numericalValues, sweepNo, key, PSQ_TEST_HEADSTAGE, UNKNOWN_MODE)
End

static Function/WAVE GetBaselineQCResults_IGNORE(sweepNo, device)
	variable sweepNo
	string device

	string key

	WAVE numericalValues = GetLBNumericalValues(device)
	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_BL_QC_PASS, query = 1)
	return GetLastSettingEachRAC(numericalValues, sweepNo, key, PSQ_TEST_HEADSTAGE, UNKNOWN_MODE)
End

static Function/WAVE GetPulseDurations_IGNORE(sweepNo, device)
	variable sweepNo
	string device

	string key

	WAVE numericalValues = GetLBNumericalValues(device)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_PULSE_DUR, query = 1)
	return GetLastSettingEachRAC(numericalValues, sweepNo, key, PSQ_TEST_HEADSTAGE, UNKNOWN_MODE)
End

static Function/WAVE GetLimitedResolution_IGNORE(sweepNo, device)
	variable sweepNo
	string device

	string key

	WAVE numericalValues = GetLBNumericalValues(device)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_RB_LIMITED_RES, query = 1)
	Make/D val = {GetLastSettingRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)[PSQ_TEST_HEADSTAGE]}
	return val
End

static Function/WAVE GetSamplingIntervalQCResults_IGNORE(sweepNo, device)
	variable sweepNo
	string device

	string key

	WAVE numericalValues = GetLBNumericalValues(device)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SAMPLING_PASS, query = 1)
	return GetLastSettingIndepEachRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_RB1([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")
	AcquireData(s, PSQ_RB_FINALSCALE_FAKE_HIGH, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// all tests fail, baseline QC and alternating spike finding
	wv = 0
End

static Function PS_RB1_REENTRY([str])
	string str

	variable sweepNo, setPassed, i, numEntries, onsetDelay, initialDAScale
	variable stepSize
	string key

	sweepNo = 14

	WAVE numericalValues = GetLBNumericalValues(str)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SET_PASS, query = 1)
	setPassed = GetLastSettingIndep(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(setPassed, 0)

	WAVE/Z samplingIntervalQCWave = GetSamplingIntervalQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(samplingIntervalQCWave, {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 15)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndep(numericalValues, sweeps[0], key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	Make/D/FREE/N=(numEntries) stimScale = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]

	Make/FREE/D/N=(numEntries) stimScaleRef = PSQ_GetFinalDAScaleFake() * ONE_TO_PICO
	CHECK_EQUAL_WAVES(stimScale, stimScaleRef, mode = WAVE_DATA)

	// no early abort on BL QC failure
	onsetDelay = GetLastSettingIndep(numericalValues, sweepNo, "Delay onset auto", DATA_ACQUISITION_MODE) + \
				 GetLastSettingIndep(numericalValues, sweepNo, "Delay onset user", DATA_ACQUISITION_MODE)

	Make/FREE/N=(numEntries) stimSetLengths = GetLastSetting(numericalValues, sweeps[p], "Stim set length", DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/N=(numEntries) sweepLengths   = DimSize(GetSweepWave(str, sweeps[p]), ROWS)

	sweepLengths[] -= onsetDelay / DimDelta(GetSweepWave(str, sweeps[p]), ROWS)

	CHECK_EQUAL_WAVES(stimSetLengths, sweepLengths, mode = WAVE_DATA)

	WAVE/Z durations = GetPulseDurations_IGNORE(sweepNo, str)
	Make/N=(numEntries) durationsRef = 3
	CHECK_EQUAL_WAVES(durations, durationsRef, mode = WAVE_DATA, tol = 0.01)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_STEPSIZE_FUTURE, query = 1)
	stepSize = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(stepSize, PSQ_RB_DASCALE_STEP_LARGE)

	WAVE/Z limitedResolution = GetLimitedResolution_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(limitedResolution, {0}, mode = WAVE_DATA, tol = 0.01)

	CHECK_EQUAL_VAR(MIES_PSQ#PSQ_GetLastPassingLongRHSweep(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE_TEST_DURATION), -1)

	CommonAnalysisFunctionChecks(str, sweepNo, {setPassed})
	CheckPSQChunkTimes(str, {20, 520})
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_RB2([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")
	AcquireData(s, PSQ_RB_FINALSCALE_FAKE_HIGH, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes and no spikes at all
	wv = 0
	wv[0,1][][0] = 1
End

static Function PS_RB2_REENTRY([str])
	string str

	variable sweepNo, setPassed, i, numEntries, onsetDelay
	variable initialDAScale, stepsize
	string key

	WAVE numericalValues = GetLBNumericalValues(str)

	sweepNo = 5

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SET_PASS, query = 1)
	setPassed = GetLastSettingIndep(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(setPassed, 0)

	WAVE/Z samplingIntervalQCWave = GetSamplingIntervalQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(samplingIntervalQCWave, {1, 1, 1, 1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {1, 1, 1, 1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z spikeDetectionWave = GetSpikeResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(spikeDetectionWave, {0, 0, 0, 0, 0, 0}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 6)

	Make/FREE/D/N=(numEntries) stimScale    = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/D/N=(numEntries) stimScaleRef = (p * PSQ_RB_DASCALE_STEP_LARGE + PSQ_GetFinalDAScaleFake()) * ONE_TO_PICO

	CHECK_EQUAL_WAVES(stimScale, stimScaleRef, mode = WAVE_DATA, tol = 1e-14)

	WAVE/Z durations = GetPulseDurations_IGNORE(sweepNo, str)
	Make/N=(numEntries) durationsRef = 3
	CHECK_EQUAL_WAVES(durations, durationsRef, mode = WAVE_DATA, tol = 0.01)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_STEPSIZE_FUTURE, query = 1)
	stepSize = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(stepSize, PSQ_RB_DASCALE_STEP_LARGE)

	WAVE/Z limitedResolution = GetLimitedResolution_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(limitedResolution, {0}, mode = WAVE_DATA, tol = 0.01)

	CHECK_EQUAL_VAR(MIES_PSQ#PSQ_GetLastPassingLongRHSweep(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE_TEST_DURATION), -1)

	CommonAnalysisFunctionChecks(str, sweepNo, {setPassed})
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523})
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_RB3([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")
	AcquireData(s, PSQ_RB_FINALSCALE_FAKE_HIGH, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes and always spikes
	wv = 0
	wv[0,1][][0] = 1
	wv[][][1]    = 1
End

static Function PS_RB3_REENTRY([str])
	string str

	variable sweepNo, setPassed, i, numEntries, onsetDelay
	variable initialDAScale, stepsize
	string key

	WAVE numericalValues = GetLBNumericalValues(str)

	sweepNo = 5

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SET_PASS, query = 1)
	setPassed = GetLastSettingIndep(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(setPassed, 0)

	WAVE/Z samplingIntervalQCWave = GetSamplingIntervalQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(samplingIntervalQCWave, {1, 1, 1, 1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {1, 1, 1, 1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z spikeDetectionWave = GetSpikeResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(spikeDetectionWave, {1, 1, 1, 1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 6)

	Make/FREE/D/N=(numEntries) stimScale    = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/D/N=(numEntries) stimScaleRef = (PSQ_GetFinalDAScaleFake() - p * PSQ_RB_DASCALE_STEP_LARGE) * ONE_TO_PICO

	CHECK_EQUAL_WAVES(stimScale, stimScaleRef, mode = WAVE_DATA, tol = 1e-14)

	WAVE/Z durations = GetPulseDurations_IGNORE(sweepNo, str)
	Make/N=(numEntries) durationsRef = 3
	CHECK_EQUAL_WAVES(durations, durationsRef, mode = WAVE_DATA, tol = 0.01)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_STEPSIZE_FUTURE, query = 1)
	stepSize = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(stepSize, PSQ_RB_DASCALE_STEP_LARGE)

	WAVE/Z limitedResolution = GetLimitedResolution_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(limitedResolution, {0}, mode = WAVE_DATA, tol = 0.01)

	CHECK_EQUAL_VAR(MIES_PSQ#PSQ_GetLastPassingLongRHSweep(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE_TEST_DURATION), -1)

	CommonAnalysisFunctionChecks(str, sweepNo, {setPassed})
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523})
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_RB4([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")
	AcquireData(s, PSQ_RB_FINALSCALE_FAKE_HIGH, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes and first spikes, second not
	wv = 0
	wv[0,1][][0] = 1
	wv[][0][1]   = 1
End

static Function PS_RB4_REENTRY([str])
	string str

	variable sweepNo, setPassed, i, numEntries, onsetDelay
	variable initialDAScale, stepsize
	string key

	WAVE numericalValues = GetLBNumericalValues(str)

	sweepNo = 1

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SET_PASS, query = 1)
	setPassed = GetLastSettingIndep(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(setPassed, 1)

	WAVE/Z samplingIntervalQCWave = GetSamplingIntervalQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(samplingIntervalQCWave, {1, 1}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {1, 1}, mode = WAVE_DATA)

	WAVE/Z spikeDetectionWave = GetSpikeResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(spikeDetectionWave, {1, 0}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 2)

	Make/FREE/D/N=(numEntries) stimScale    = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/D/N=(numEntries) stimScaleRef = (PSQ_GetFinalDAScaleFake() - p * PSQ_RB_DASCALE_STEP_LARGE) * ONE_TO_PICO

	CHECK_EQUAL_WAVES(stimScale, stimScaleRef, mode = WAVE_DATA, tol = 1e-14)

	WAVE/Z durations = GetPulseDurations_IGNORE(sweepNo, str)
	Make/N=(numEntries) durationsRef = 3
	CHECK_EQUAL_WAVES(durations, durationsRef, mode = WAVE_DATA, tol = 0.01)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_STEPSIZE_FUTURE, query = 1)
	stepSize = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(stepSize, PSQ_RB_DASCALE_STEP_LARGE)

	WAVE/Z limitedResolution = GetLimitedResolution_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(limitedResolution, {0}, mode = WAVE_DATA, tol = 0.01)

	CHECK_EQUAL_VAR(MIES_PSQ#PSQ_GetLastPassingLongRHSweep(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE_TEST_DURATION), 0)

	CommonAnalysisFunctionChecks(str, sweepNo, {setPassed})
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523})
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_RB5([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")
	AcquireData(s, PSQ_RB_FINALSCALE_FAKE_HIGH, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes and first spikes not, second does
	wv = 0
	wv[0,1][][0] = 1
	wv[][1][1]   = 1
End

static Function PS_RB5_REENTRY([str])
	string str

	variable sweepNo, setPassed, i, numEntries, onsetDelay
	variable initialDAScale, stepsize
	string key

	WAVE numericalValues = GetLBNumericalValues(str)

	sweepNo = 1

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SET_PASS, query = 1)
	setPassed = GetLastSettingIndep(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(setPassed, 1)

	WAVE/Z samplingIntervalQCWave = GetSamplingIntervalQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(samplingIntervalQCWave, {1, 1}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {1, 1}, mode = WAVE_DATA)

	WAVE/Z spikeDetectionWave = GetSpikeResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(spikeDetectionWave, {0, 1}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 2)

	Make/FREE/D/N=(numEntries) stimScale    = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/D/N=(numEntries) stimScaleRef = (PSQ_GetFinalDAScaleFake() + p * PSQ_RB_DASCALE_STEP_LARGE) * ONE_TO_PICO

	CHECK_EQUAL_WAVES(stimScale, stimScaleRef, mode = WAVE_DATA, tol = 1e-14)

	WAVE/Z durations = GetPulseDurations_IGNORE(sweepNo, str)
	Make/N=(numEntries) durationsRef = 3
	CHECK_EQUAL_WAVES(durations, durationsRef, mode = WAVE_DATA, tol = 0.01)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_STEPSIZE_FUTURE, query = 1)
	stepSize = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(stepSize, PSQ_RB_DASCALE_STEP_LARGE)

	WAVE/Z limitedResolution = GetLimitedResolution_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(limitedResolution, {0}, mode = WAVE_DATA, tol = 0.01)

	CHECK_EQUAL_VAR(MIES_PSQ#PSQ_GetLastPassingLongRHSweep(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE_TEST_DURATION), 1)

	CommonAnalysisFunctionChecks(str, sweepNo, {setPassed})
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523})
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_RB6([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")
	AcquireData(s, PSQ_RB_FINALSCALE_FAKE_HIGH, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes and first two spike not, third does
	wv = 0
	wv[0,1][][0] = 1
	wv[][2][1]   = 1
End

static Function PS_RB6_REENTRY([str])
	string str

	variable sweepNo, setPassed, i, numEntries, onsetDelay
	variable initialDAScale, stepsize
	string key

	WAVE numericalValues = GetLBNumericalValues(str)

	sweepNo = 2

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SET_PASS, query = 1)
	setPassed = GetLastSettingIndep(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(setPassed, 1)

	WAVE/Z samplingIntervalQCWave = GetSamplingIntervalQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(samplingIntervalQCWave, {1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z spikeDetectionWave = GetSpikeResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(spikeDetectionWave, {0, 0, 1}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 3)

	Make/FREE/D/N=(numEntries) stimScale    = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/D/N=(numEntries) stimScaleRef = (PSQ_GetFinalDAScaleFake() + p * PSQ_RB_DASCALE_STEP_LARGE) * ONE_TO_PICO

	CHECK_EQUAL_WAVES(stimScale, stimScaleRef, mode = WAVE_DATA, tol = 1e-14)

	WAVE/Z durations = GetPulseDurations_IGNORE(sweepNo, str)
	Make/N=(numEntries) durationsRef = 3
	CHECK_EQUAL_WAVES(durations, durationsRef, mode = WAVE_DATA, tol = 0.01)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_STEPSIZE_FUTURE, query = 1)
	stepSize = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(stepSize, PSQ_RB_DASCALE_STEP_LARGE)

	WAVE/Z limitedResolution = GetLimitedResolution_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(limitedResolution, {0}, mode = WAVE_DATA, tol = 0.01)

	CHECK_EQUAL_VAR(MIES_PSQ#PSQ_GetLastPassingLongRHSweep(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE_TEST_DURATION), 2)

	CommonAnalysisFunctionChecks(str, sweepNo, {setPassed})
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523})
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_RB7([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")
	AcquireData(s, PSQ_RB_FINALSCALE_FAKE_HIGH, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// frist two sweeps: baseline QC fails
	// rest:baseline QC passes
	// all: no spikes
	wv = 0
	wv[0,1][2, inf][0] = 1
End

static Function PS_RB7_REENTRY([str])
	string str

	variable sweepNo, setPassed, i, numEntries, onsetDelay
	variable initialDAScale, stepsize
	string key

	WAVE numericalValues = GetLBNumericalValues(str)

	sweepNo = 7

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SET_PASS, query = 1)
	setPassed = GetLastSettingIndep(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(setPassed, 0)

	WAVE/Z samplingIntervalQCWave = GetSamplingIntervalQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(samplingIntervalQCWave, {1, 1, 1, 1, 1, 1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {0, 0, 1, 1, 1, 1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z spikeDetectionWave = GetSpikeResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(spikeDetectionWave, {NaN, NaN, 0, 0, 0, 0, 0, 0}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 8)

	Make/FREE/D/N=(numEntries) stimScale = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/D/N=(numEntries) stimScaleRef
	stimScaleRef[0, 1]   = PSQ_GetFinalDAScaleFake() * ONE_TO_PICO
	stimScaleRef[2, inf] = (PSQ_GetFinalDAScaleFake() + (p - 2) * PSQ_RB_DASCALE_STEP_LARGE) * ONE_TO_PICO

	CHECK_EQUAL_WAVES(stimScale, stimScaleRef, mode = WAVE_DATA, tol = 1e-14)

	WAVE/Z durations = GetPulseDurations_IGNORE(sweepNo, str)
	Make/N=(numEntries) durationsRef = 3
	CHECK_EQUAL_WAVES(durations, durationsRef, mode = WAVE_DATA, tol = 0.01)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_STEPSIZE_FUTURE, query = 1)
	stepSize = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(stepSize, PSQ_RB_DASCALE_STEP_LARGE)

	CHECK_EQUAL_VAR(MIES_PSQ#PSQ_GetLastPassingLongRHSweep(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE_TEST_DURATION), -1)

	CommonAnalysisFunctionChecks(str, sweepNo, {setPassed})
	CheckPSQChunkTimes(str, {20, 520}, sweep = 0)
	CheckPSQChunkTimes(str, {20, 520}, sweep = 1)
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523}, sweep = 2)
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523}, sweep = 3)
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523}, sweep = 4)
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523}, sweep = 5)
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523}, sweep = 6)
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523}, sweep = 7)
End

// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_RB8([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")
	AcquireData(s, PSQ_RB_FINALSCALE_FAKE_LOW, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes
	// 0: spike
	// 1-2: no-spike
	// 3: spike
	wv = 0
	wv[0,1][][0] = 1
	wv[][0][1]   = 1
	wv[][3][1]   = 1
End

static Function PS_RB8_REENTRY([str])
	string str

	variable sweepNo, setPassed, i, numEntries, onsetDelay
	variable initialDAScale, stepsize
	string key

	WAVE numericalValues = GetLBNumericalValues(str)

	sweepNo = 3

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SET_PASS, query = 1)
	setPassed = GetLastSettingIndep(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(setPassed, 1)

	WAVE/Z samplingIntervalQCWave = GetSamplingIntervalQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(samplingIntervalQCWave, {1, 1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {1, 1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z spikeDetectionWave = GetSpikeResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(spikeDetectionWave, {1, 0, 0, 1}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 4)

	Make/FREE/D/N=(numEntries) stimScale = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/D/N=(numEntries) stimScaleRef

	stimScaleRef[0] = PSQ_GetFinalDAScaleFake()
	stimScaleRef[1] = stimScaleRef[0] - PSQ_RB_DASCALE_STEP_LARGE
	stimScaleRef[2] = stimScaleRef[1] + PSQ_RB_DASCALE_STEP_SMALL
	stimScaleRef[3] = stimScaleRef[2] + PSQ_RB_DASCALE_STEP_SMALL
	stimScaleRef *= ONE_TO_PICO

	CHECK_EQUAL_WAVES(stimScale, stimScaleRef, mode = WAVE_DATA, tol = 1e-14)

	WAVE/Z durations = GetPulseDurations_IGNORE(sweepNo, str)
	Make/N=(numEntries) durationsRef = 3
	CHECK_EQUAL_WAVES(durations, durationsRef, mode = WAVE_DATA, tol = 0.01)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_STEPSIZE_FUTURE, query = 1)
	stepSize = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(stepSize, PSQ_RB_DASCALE_STEP_SMALL)

	WAVE/Z limitedResolution = GetLimitedResolution_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(limitedResolution, {0}, mode = WAVE_DATA, tol = 0.01)

	CHECK_EQUAL_VAR(MIES_PSQ#PSQ_GetLastPassingLongRHSweep(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE_TEST_DURATION), 3)

	CommonAnalysisFunctionChecks(str, sweepNo, {setPassed})
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523})
End

// check behaviour of DAScale 0 with PSQ_RB_DASCALE_STEP_LARGE stepsize
// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_RB9([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")
	AcquireData(s, PSQ_RB_DASCALE_STEP_LARGE, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes and first spikes, second not, third spikes
	wv = 0
	wv[0,1][][0] = 1
	wv[][0][1]   = 1
	wv[][2][1]   = 1
End

static Function PS_RB9_REENTRY([str])
	string str

	variable sweepNo, setPassed, i, numEntries, onsetDelay
	variable initialDAScale, stepsize
	string key

	WAVE numericalValues = GetLBNumericalValues(str)

	sweepNo = 2

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SET_PASS, query = 1)
	setPassed = GetLastSettingIndep(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(setPassed, 1)

	WAVE/Z samplingIntervalQCWave = GetSamplingIntervalQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(samplingIntervalQCWave, {1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z spikeDetectionWave = GetSpikeResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(spikeDetectionWave, {1, 0, 1}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 3)

	Make/FREE/D/N=(numEntries) stimScale = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/D/N=(numEntries) stimScaleRef

	stimScaleRef[0] = PSQ_RB_DASCALE_STEP_LARGE
	stimScaleRef[1] = PSQ_RB_DASCALE_STEP_SMALL
	stimScaleRef[2] = 2 * PSQ_RB_DASCALE_STEP_SMALL
	stimScaleRef *= ONE_TO_PICO

	CHECK_EQUAL_WAVES(stimScale, stimScaleRef, mode = WAVE_DATA, tol = 1e-14)

	WAVE/Z durations = GetPulseDurations_IGNORE(sweepNo, str)
	Make/N=(numEntries) durationsRef = 3
	CHECK_EQUAL_WAVES(durations, durationsRef, mode = WAVE_DATA, tol = 0.01)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_STEPSIZE_FUTURE, query = 1)
	stepSize = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(stepSize, PSQ_RB_DASCALE_STEP_SMALL)

	WAVE/Z limitedResolution = GetLimitedResolution_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(limitedResolution, {0}, mode = WAVE_DATA, tol = 0.01)

	CHECK_EQUAL_VAR(MIES_PSQ#PSQ_GetLastPassingLongRHSweep(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE_TEST_DURATION), 2)

	CommonAnalysisFunctionChecks(str, sweepNo, {setPassed})
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523})
End

// check behaviour of DAScale 0 with PSQ_RB_DASCALE_STEP_SMALL stepsize
// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_RB10([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")
	AcquireData(s, -8e-12, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes and first spikes not, rest spikes
	wv = 0
	wv[0,1][][0] = 1
	wv[][0][1]   = 0
	wv[][1,inf][1] = 1
End

static Function PS_RB10_REENTRY([str])
	string str

	variable sweepNo, setPassed, i, numEntries, onsetDelay
	variable initialDAScale, stepsize
	string key

	WAVE numericalValues = GetLBNumericalValues(str)

	sweepNo = 1

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SET_PASS, query = 1)
	setPassed = GetLastSettingIndep(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(setPassed, 0)

	WAVE/Z samplingIntervalQCWave = GetSamplingIntervalQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(samplingIntervalQCWave, {1, 1}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {1, 1}, mode = WAVE_DATA)

	WAVE/Z spikeDetectionWave = GetSpikeResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(spikeDetectionWave, {0, 1}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 2)

	Make/FREE/D/N=(numEntries) stimScale = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/D/N=(numEntries) stimScaleRef

	stimScaleRef[0] = -8
	stimScaleRef[1] = 2

	CHECK_EQUAL_WAVES(stimScale, stimScaleRef, mode = WAVE_DATA, tol = 1e-14)

	WAVE/Z durations = GetPulseDurations_IGNORE(sweepNo, str)
	Make/N=(numEntries) durationsRef = 3
	CHECK_EQUAL_WAVES(durations, durationsRef, mode = WAVE_DATA, tol = 0.01)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_STEPSIZE_FUTURE, query = 1)
	stepSize = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(stepSize, PSQ_RB_DASCALE_STEP_SMALL)

	WAVE/Z limitedResolution = GetLimitedResolution_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(limitedResolution, {1}, mode = WAVE_DATA, tol = 0.01)

	CHECK_EQUAL_VAR(MIES_PSQ#PSQ_GetLastPassingLongRHSweep(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE_TEST_DURATION), -1)

	CommonAnalysisFunctionChecks(str, sweepNo, {setPassed})
	CheckPSQChunkTimes(str, {20, 520, 1023, 1523})
End

static Function PS_RB11_IGNORE(string device)
	AFH_AddAnalysisParameter("Rheobase_DA_0", "SamplingFrequency", var=10)
End

// Same as PS_RB1 but with failing sampling frequency check
//
// UTF_TD_GENERATOR HardwareMain#DeviceNameGeneratorMD1
static Function PS_RB11([str])
	string str

	STRUCT DAQSettings s
	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG_1")
	AcquireData(s, PSQ_RB_FINALSCALE_FAKE_HIGH, str, preAcquireFunc = PS_RB11_IGNORE)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// all tests fail, baseline QC and alternating spike finding
	wv = 0
End

static Function PS_RB11_REENTRY([str])
	string str

	variable sweepNo, setPassed, i, numEntries, onsetDelay, initialDAScale
	variable stepSize
	string key

	sweepNo = 0

	WAVE numericalValues = GetLBNumericalValues(str)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_SET_PASS, query = 1)
	setPassed = GetLastSettingIndep(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(setPassed, 0)

	WAVE/Z samplingIntervalQCWave = GetSamplingIntervalQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(samplingIntervalQCWave, {0}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {0}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 1)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_INITIAL_SCALE, query = 1)
	initialDAScale = GetLastSettingIndep(numericalValues, sweeps[0], key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(initialDAScale, PSQ_GetFinalDAScaleFake())

	Make/D/FREE/N=(numEntries) stimScale = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]

	Make/FREE/D/N=(numEntries) stimScaleRef = PSQ_GetFinalDAScaleFake() * ONE_TO_PICO
	CHECK_EQUAL_WAVES(stimScale, stimScaleRef, mode = WAVE_DATA)

	// no early abort on BL QC failure
	onsetDelay = GetLastSettingIndep(numericalValues, sweepNo, "Delay onset auto", DATA_ACQUISITION_MODE) + \
				 GetLastSettingIndep(numericalValues, sweepNo, "Delay onset user", DATA_ACQUISITION_MODE)

	Make/FREE/N=(numEntries) stimSetLengths = GetLastSetting(numericalValues, sweeps[p], "Stim set length", DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/N=(numEntries) sweepLengths   = DimSize(GetSweepWave(str, sweeps[p]), ROWS)

	sweepLengths[] -= onsetDelay / DimDelta(GetSweepWave(str, sweeps[p]), ROWS)

	CHECK_EQUAL_WAVES(stimSetLengths, sweepLengths, mode = WAVE_DATA)

	WAVE/Z durations = GetPulseDurations_IGNORE(sweepNo, str)
	Make/N=(numEntries) durationsRef = 3
	CHECK_EQUAL_WAVES(durations, durationsRef, mode = WAVE_DATA, tol = 0.01)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_STEPSIZE_FUTURE, query = 1)
	stepSize = GetLastSettingIndepRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
	CHECK_EQUAL_VAR(stepSize, PSQ_RB_DASCALE_STEP_LARGE)

	WAVE/Z limitedResolution = GetLimitedResolution_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(limitedResolution, {0}, mode = WAVE_DATA, tol = 0.01)

	CHECK_EQUAL_VAR(MIES_PSQ#PSQ_GetLastPassingLongRHSweep(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE_TEST_DURATION), -1)

	CommonAnalysisFunctionChecks(str, sweepNo, {setPassed})
	CheckPSQChunkTimes(str, {20, 520})
End
