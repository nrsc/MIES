#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3 // Use modern global access method and strict wave access.
#pragma rtFunctionErrors=1
#pragma ModuleName=PatchSeqTestRheobase

static Constant PSQ_RHEOBASE_TEST_DURATION  = 2
static Constant PSQ_RB_FINALSCALE_FAKE_HIGH = 70e-12
static Constant PSQ_RB_FINALSCALE_FAKE_LOW  = 40e-12

static Function [STRUCT DAQSettings s] PS_GetDAQSettings(string device)

	InitDAQSettingsFromString(s, "MD1_RA1_I0_L0_BKG1_DB1"               + \
								 "__HS" + num2str(PSQ_TEST_HEADSTAGE) + "_DA0_AD0_CM:IC:_ST:Rheobase_DA_0:")

	 return [s]
End

static Function GlobalPreAcq(string device)
	variable ret

	PGC_SetAndActivateControl(device, "check_DataAcq_AutoBias", val = 1)
	PGC_SetAndActivateControl(device, "setvar_DataAcq_AutoBiasV", val = 70)

	PGC_SetAndActivateControl(device, "SetVar_DataAcq_TPBaselinePerc", val = 25)
End

static Function GlobalPreInit(string device)

	AdjustAnalysisParamsForPSQ(device, "Rheobase_DA_0")
	PrepareForPublishTest()
End

static Function SetFinalDAScale(variable var)

	Make/O/N=(0) root:overrideResults/Wave=overrideResults
	Note/K overrideResults

	SetNumberInWaveNote(overrideResults, PSQ_RB_FINALSCALE_FAKE_KEY, var)
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

static Function/WAVE GetAsyncQCResults_IGNORE(sweepNo, device)
	variable sweepNo
	string device

	string key

	WAVE numericalValues = GetLBNumericalValues(device)

	key = CreateAnaFuncLBNKey(PSQ_RHEOBASE, PSQ_FMT_LBN_ASYNC_PASS, query = 1)
	return GetLastSettingIndepEachRAC(numericalValues, sweepNo, key, UNKNOWN_MODE)
End

static Function PS_RB1_preAcq(string device)

	Make/FREE asyncChannels = {2, 4}
	AFH_AddAnalysisParameter("Rheobase_DA_0", "AsyncQCChannels", wv = asyncChannels)

	SetAsyncChannelProperties(device, asyncChannels, -1e6, +1e6)

	SetFinalDAScale(PSQ_RB_FINALSCALE_FAKE_HIGH)
End

// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function PS_RB1([str])
	string str

	[STRUCT DAQSettings s] = PS_GetDAQSettings(str)
	AcquireData_NG(s, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// all tests fail, baseline QC, async QC and alternating spike finding
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

	WAVE/Z asyncQCWave = GetAsyncQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(asyncQCWave, {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, mode = WAVE_DATA)

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

static Function PS_RB2_preAcq(string device)

	Make/FREE asyncChannels = {2, 4}
	AFH_AddAnalysisParameter("Rheobase_DA_0", "AsyncQCChannels", wv = asyncChannels)

	SetAsyncChannelProperties(device, asyncChannels, -1e6, +1e6)

	SetFinalDAScale(PSQ_RB_FINALSCALE_FAKE_HIGH)
End

// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function PS_RB2([str])
	string str

	[STRUCT DAQSettings s] = PS_GetDAQSettings(str)
	AcquireData_NG(s, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes, async QC passes and no spikes at all
	wv = 0
	wv[0,1][][0] = 1
	wv[0,1][][0] = 1
	wv[][][2] = 1
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

	WAVE/Z asyncQCWave = GetAsyncQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(asyncQCWave, {1, 1, 1, 1, 1, 1}, mode = WAVE_DATA)

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

static Function PS_RB3_preAcq(string device)

	Make/FREE asyncChannels = {2, 4}
	AFH_AddAnalysisParameter("Rheobase_DA_0", "AsyncQCChannels", wv = asyncChannels)

	SetAsyncChannelProperties(device, asyncChannels, -1e6, +1e6)

	SetFinalDAScale(PSQ_RB_FINALSCALE_FAKE_HIGH)
End

// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function PS_RB3([str])
	string str

	[STRUCT DAQSettings s] = PS_GetDAQSettings(str)
	AcquireData_NG(s, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes, async QC passes and always spikes
	wv = 0
	wv[0,1][][0] = 1
	wv[][][1]    = 1
	wv[][][2]    = 1
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

	WAVE/Z asyncQCWave = GetAsyncQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(asyncQCWave, {1, 1, 1, 1, 1, 1}, mode = WAVE_DATA)

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

static Function PS_RB4_preAcq(string device)

	Make/FREE asyncChannels = {2, 4}
	AFH_AddAnalysisParameter("Rheobase_DA_0", "AsyncQCChannels", wv = asyncChannels)

	SetAsyncChannelProperties(device, asyncChannels, -1e6, +1e6)

	SetFinalDAScale(PSQ_RB_FINALSCALE_FAKE_HIGH)
End

// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function PS_RB4([str])
	string str

	[STRUCT DAQSettings s] = PS_GetDAQSettings(str)
	AcquireData_NG(s, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes, async QC passes and first spikes, second not
	wv = 0
	wv[0,1][][0] = 1
	wv[][0][1]   = 1
	wv[][][2]    = 1
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

	WAVE/Z asyncQCWave = GetAsyncQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(asyncQCWave, {1, 1}, mode = WAVE_DATA)

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

static Function PS_RB5_preAcq(string device)

	Make/FREE asyncChannels = {2, 4}
	AFH_AddAnalysisParameter("Rheobase_DA_0", "AsyncQCChannels", wv = asyncChannels)

	SetAsyncChannelProperties(device, asyncChannels, -1e6, +1e6)

	SetFinalDAScale(PSQ_RB_FINALSCALE_FAKE_HIGH)
End

// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function PS_RB5([str])
	string str

	[STRUCT DAQSettings s] = PS_GetDAQSettings(str)
	AcquireData_NG(s, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes, async QC passes and first spikes not, second does
	wv = 0
	wv[0,1][][0] = 1
	wv[][1][1]   = 1
	wv[][][2]    = 1
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

	WAVE/Z asyncQCWave = GetAsyncQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(asyncQCWave, {1, 1}, mode = WAVE_DATA)

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

static Function PS_RB6_preAcq(string device)

	Make/FREE asyncChannels = {2, 4}
	AFH_AddAnalysisParameter("Rheobase_DA_0", "AsyncQCChannels", wv = asyncChannels)

	SetAsyncChannelProperties(device, asyncChannels, -1e6, +1e6)

	SetFinalDAScale(PSQ_RB_FINALSCALE_FAKE_HIGH)
End

// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function PS_RB6([str])
	string str

	[STRUCT DAQSettings s] = PS_GetDAQSettings(str)
	AcquireData_NG(s, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes, async QC passes (except first) and first two spike not, third does
	wv = 0
	wv[0,1][][0] = 1
	wv[][2][1]   = 1
	wv[][1,2][2] = 1
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

	WAVE/Z asyncQCWave = GetAsyncQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(asyncQCWave, {0, 1, 1}, mode = WAVE_DATA)

	WAVE/Z baselineQCWave = GetBaselineQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(baselineQCWave, {1, 1, 1}, mode = WAVE_DATA)

	WAVE/Z spikeDetectionWave = GetSpikeResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(spikeDetectionWave, {NaN, 0, 1}, mode = WAVE_DATA)

	WAVE/Z sweeps = AFH_GetSweepsFromSameRACycle(numericalValues, sweepNo)
	CHECK_WAVE(sweeps, NUMERIC_WAVE)
	numEntries = DimSize(sweeps, ROWS)
	CHECK_EQUAL_VAR(numEntries, 3)

	Make/FREE/D/N=(numEntries) stimScale    = GetLastSetting(numericalValues, sweeps[p], STIMSET_SCALE_FACTOR_KEY, DATA_ACQUISITION_MODE)[PSQ_TEST_HEADSTAGE]
	Make/FREE/D/N=(numEntries) stimScaleRef
	stimScaleRef[0, 1] = PSQ_GetFinalDAScaleFake() * ONE_TO_PICO
	stimScaleRef[2, inf] = (PSQ_GetFinalDAScaleFake() + (p - 1) * PSQ_RB_DASCALE_STEP_LARGE) * ONE_TO_PICO

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

static Function PS_RB7_preAcq(string device)

	Make/FREE asyncChannels = {2, 4}
	AFH_AddAnalysisParameter("Rheobase_DA_0", "AsyncQCChannels", wv = asyncChannels)

	SetAsyncChannelProperties(device, asyncChannels, -1e6, +1e6)

	SetFinalDAScale(PSQ_RB_FINALSCALE_FAKE_HIGH)
End

// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function PS_RB7([str])
	string str

	[STRUCT DAQSettings s] = PS_GetDAQSettings(str)
	AcquireData_NG(s, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// frist two sweeps: baseline QC fails
	// rest:baseline QC passes
	// all: no spikes, async QC passes
	wv = 0
	wv[0,1][2, inf][0] = 1
	wv[][][2] = 1
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

	WAVE/Z asyncQCWave = GetAsyncQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(asyncQCWave, {1, 1, 1, 1, 1, 1, 1, 1}, mode = WAVE_DATA)

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

static Function PS_RB8_preAcq(string device)

	Make/FREE asyncChannels = {2, 4}
	AFH_AddAnalysisParameter("Rheobase_DA_0", "AsyncQCChannels", wv = asyncChannels)

	SetAsyncChannelProperties(device, asyncChannels, -1e6, +1e6)

	SetFinalDAScale(PSQ_RB_FINALSCALE_FAKE_LOW)
End

// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function PS_RB8([str])
	string str

	[STRUCT DAQSettings s] = PS_GetDAQSettings(str)
	AcquireData_NG(s, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes, async QC passes
	// 0: spike
	// 1-2: no-spike
	// 3: spike
	wv = 0
	wv[0,1][][0] = 1
	wv[][0][1]   = 1
	wv[][3][1]   = 1
	wv[][][2] = 1
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

	WAVE/Z asyncQCWave = GetAsyncQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(asyncQCWave, {1, 1, 1, 1}, mode = WAVE_DATA)

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

static Function PS_RB9_preAcq(string device)

	Make/FREE asyncChannels = {2, 4}
	AFH_AddAnalysisParameter("Rheobase_DA_0", "AsyncQCChannels", wv = asyncChannels)

	SetAsyncChannelProperties(device, asyncChannels, -1e6, +1e6)

	SetFinalDAScale(PSQ_RB_DASCALE_STEP_LARGE)
End

// check behaviour of DAScale 0 with PSQ_RB_DASCALE_STEP_LARGE stepsize
// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function PS_RB9([str])
	string str

	[STRUCT DAQSettings s] = PS_GetDAQSettings(str)
	AcquireData_NG(s, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes, async QC passes and first spikes, second not, third spikes
	wv = 0
	wv[0,1][][0] = 1
	wv[][0][1]   = 1
	wv[][2][1]   = 1
	wv[][][2]    = 1
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

	WAVE/Z asyncQCWave = GetAsyncQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(asyncQCWave, {1, 1, 1}, mode = WAVE_DATA)

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

static Function PS_RB10_preAcq(string device)

	Make/FREE asyncChannels = {2, 4}
	AFH_AddAnalysisParameter("Rheobase_DA_0", "AsyncQCChannels", wv = asyncChannels)

	SetAsyncChannelProperties(device, asyncChannels, -1e6, +1e6)

	SetFinalDAScale(-8e-12)
End

// check behaviour of DAScale 0 with PSQ_RB_DASCALE_STEP_SMALL stepsize
// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function PS_RB10([str])
	string str

	[STRUCT DAQSettings s] = PS_GetDAQSettings(str)
	AcquireData_NG(s, str)

	WAVE wv = PSQ_CreateOverrideResults(str, PSQ_TEST_HEADSTAGE, PSQ_RHEOBASE)
	// baseline QC passes, async QC passes and first spikes not, rest spikes
	wv = 0
	wv[0,1][][0] = 1
	wv[][0][1]   = 0
	wv[][1,inf][1] = 1
	wv[][][2] = 1
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

	WAVE/Z asyncQCWave = GetAsyncQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(asyncQCWave, {1, 1}, mode = WAVE_DATA)

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

static Function PS_RB11_preAcq(string device)
	AFH_AddAnalysisParameter("Rheobase_DA_0", "SamplingFrequency", var=10)

	Make/FREE asyncChannels = {2, 4}
	AFH_AddAnalysisParameter("Rheobase_DA_0", "AsyncQCChannels", wv = asyncChannels)

	SetAsyncChannelProperties(device, asyncChannels, -1e6, +1e6)

	SetFinalDAScale(PSQ_RB_FINALSCALE_FAKE_HIGH)
End

// Same as PS_RB1 but with failing sampling frequency check
//
// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function PS_RB11([str])
	string str

	[STRUCT DAQSettings s] = PS_GetDAQSettings(str)
	AcquireData_NG(s, str)

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

	WAVE/Z asyncQCWave = GetAsyncQCResults_IGNORE(sweepNo, str)
	CHECK_EQUAL_WAVES(asyncQCWave, {0}, mode = WAVE_DATA)

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
