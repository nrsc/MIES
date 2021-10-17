#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3 // Use modern global access method and strict wave access.
#pragma rtFunctionErrors=1

#ifdef AUTOMATED_TESTING
#pragma ModuleName=MIES_TP
#endif

/// @file MIES_TestPulse.ipf
/// @brief __TP__ Basic Testpulse related functionality

static Constant TP_MAX_VALID_RESISTANCE       = 3000 ///< Units MOhm
static Constant TP_TPSTORAGE_EVAL_INTERVAL    = 0.18
static Constant TP_FIT_POINTS                 = 5
static Constant TP_PRESSURE_INTERVAL          = 0.090  ///< [s]
static Constant TP_EVAL_POINT_OFFSET          = 5

// comment in for debugging
// #define TP_ANALYSIS_DEBUGGING

/// @brief Check if the value is a valid baseline fraction
Function TP_IsValidBaselineFraction(variable value)
	return value >= TP_BASELINE_FRACTION_LOW && value <= TP_BASELINE_FRACTION_HIGH
End

/// @brief Return the total length of a single testpulse with baseline
///
/// @param pulseDuration duration of the high portion of the testpulse in points or time
/// @param baselineFrac  fraction, *not* percentage, of the baseline
Function TP_CalculateTestPulseLength(pulseDuration, baselineFrac)
	variable pulseDuration, baselineFrac

	ASSERT(TP_IsValidBaselineFraction(baselineFrac), "baselineFrac is out of range")
	return pulseDuration / (1 - 2 * baselineFrac)
End

/// @brief Stores the given TP wave
///
/// @param panelTitle panel title
///
/// @param TPWave reference to wave holding the TP data in the same format as OscilloscopeData
///
/// @param tpMarker unique number for this set of TPs from all TP channels
///
/// @param hsList list of headstage numbers in the same order as the columns of TPWave
Function TP_StoreTP(panelTitle, TPWave, tpMarker, hsList)
	string panelTitle
	WAVE TPWave
	variable tpMarker
	string hsList

	variable index

	WAVE/WAVE storedTP = GetStoredTestPulseWave(panelTitle)
	index = GetNumberFromWaveNote(storedTP, NOTE_INDEX)
	EnsureLargeEnoughWave(storedTP, minimumSize=index)
	Note/K TPWave
	SetStringInWaveNote(TPWave, "TimeStamp", GetISO8601TimeStamp(numFracSecondsDigits = 3))
	SetNumberInWaveNote(TPWave, "TPMarker", tpMarker, format="%d")
	SetStringInWaveNote(TPWave, "Headstages", hsList)
	storedTP[index++] = TPWave

	SetNumberInWaveNote(storedTP, NOTE_INDEX, index)
End

/// @brief Split the stored testpulse wave reference wave into single waves
///        for easier handling
Function TP_SplitStoredTestPulseWave(panelTitle)
	string panelTitle

	variable numEntries, i

	WAVE/WAVE storedTP = GetStoredTestPulseWave(panelTitle)
	DFREF dfr = GetDeviceTestPulse(panelTitle)

	numEntries = GetNumberFromWaveNote(storedTP, NOTE_INDEX)
	for(i = 0; i < numEntries; i += 1)

		WAVE/Z wv = storedTP[i]

		if(!WaveExists(wv))
			continue
		endif

		Duplicate/O wv, dfr:$("StoredTestPulses_" + num2str(i))
	endfor
End

/// @brief Receives data from the async function TP_TSAnalysis(), buffers partial results and puts
/// complete results back to main thread,
/// results are base line level, steady state resistance, instantaneous resistance and their positions
/// collected results for all channels of a measurement are send to TP_RecordTP(), DQ_ApplyAutoBias() when complete
///
/// @param dfr output data folder from ASYNC frame work with results from workloads associated with this registered function
///		  The output parameter in the data folder follow the definition as created in TP_TSAnalysis()
///
/// @param err error code of TP_TSAnalysis() function
///
/// @param errmsg error message of TP_TSAnalysis() function
Function TP_ROAnalysis(dfr, err, errmsg)
	DFREF dfr
	variable err
	string errmsg

	variable i, j, bufSize
	variable posMarker, posAsync, tpBufferSize
	variable posBaseline, posSSRes, posInstRes
	variable posElevSS, posElevInst

	if(err)
		ASSERT(0, "RTError " + num2str(err) + " in TP_Analysis thread: " + errmsg)
	endif

	WAVE/SDFR=dfr inData=outData
	NVAR/SDFR=dfr now=now
	NVAR/SDFR=dfr hsIndex=hsIndex
	SVAR/SDFR=dfr panelTitle=panelTitle
	NVAR/SDFR=dfr marker=marker
	NVAR/SDFR=dfr activeADCs=activeADCs

	WAVE asyncBuffer = GetTPResultAsyncBuffer(panelTitle)

	bufSize = DimSize(asyncBuffer, ROWS)
	posMarker = FindDimLabel(asyncBuffer, LAYERS, "MARKER")
	posAsync = FindDimLabel(asyncBuffer, COLS, "ASYNCDATA")
	posBaseline = FindDimLabel(asyncBuffer, COLS, "BASELINE")
	posSSRes = FindDimLabel(asyncBuffer, COLS, "STEADYSTATERES")
	posInstRes = FindDimLabel(asyncBuffer, COLS, "INSTANTRES")
	posElevSS = FindDimLabel(asyncBuffer, COLS, "ELEVATED_SS")
	posElevInst = FindDimLabel(asyncBuffer, COLS, "ELEVATED_INST")

	FindValue/RMD=[][posAsync][posMarker, posMarker]/V=(marker)/T=0 asyncBuffer
	i = V_Value >= 0 ? V_Row : bufSize

	if(i == bufSize)
		Redimension/N=(bufSize + 1, -1, -1) asyncBuffer
		asyncBuffer[bufSize][][] = NaN
		asyncBuffer[bufSize][posAsync][%REC_CHANNELS] = 0
		asyncBuffer[bufSize][posAsync][posMarker] = marker
	endif

	asyncBuffer[i][posBaseline][hsIndex] = inData[%BASELINE]
	asyncBuffer[i][posSSRes][hsIndex] = inData[%STEADYSTATERES]
	asyncBuffer[i][posInstRes][hsIndex] = inData[%INSTANTRES]
	asyncBuffer[i][posElevSS][hsIndex] = inData[%ELEVATED_SS]
	asyncBuffer[i][posElevInst][hsIndex] = inData[%ELEVATED_INST]

	asyncBuffer[i][posAsync][%NOW] = now
	asyncBuffer[i][posAsync][%REC_CHANNELS] += 1

	// got one set of results ready
	if(asyncBuffer[i][posAsync][%REC_CHANNELS] == activeADCs)

		WAVE TPResults  = GetTPResults(panelTitle)
		WAVE TPSettings = GetTPSettings(panelTitle)

		MultiThread TPResults[%BaselineSteadyState][]   = asyncBuffer[i][posBaseline][q]
		MultiThread TPResults[%ResistanceSteadyState][] = asyncBuffer[i][posSSRes][q]
		MultiThread TPResults[%ResistanceInst][]        = asyncBuffer[i][posInstRes][q]
		MultiThread TPResults[%ElevatedSteadyState][]   = asyncBuffer[i][posElevSS][q]
		MultiThread TPResults[%ElevatedInst][]          = asyncBuffer[i][posElevInst][q]

		// Remove finished results from buffer
		DeletePoints i, 1, asyncBuffer
		if(!DimSize(asyncBuffer, ROWS))
			KillOrMoveToTrash(wv=asyncBuffer)
		endif

		if(TPSettings[%bufferSize][INDEP_HEADSTAGE] > 1)
			WAVE TPResultsBuffer = GetTPResultsBuffer(panelTitle)
			TP_CalculateAverage(TPResultsBuffer, TPResults)
		endif

		TP_RecordTP(panelTitle, TPResults, now, marker)
		DQ_ApplyAutoBias(panelTitle, TPResults)
	endif

End

/// @brief This function analyses a TP data set. It is called by the ASYNC frame work in an own thread.
/// 		  currently six properties are determined.
///
/// @param dfrInp input data folder from the ASYNC framework, parameter input order therein follows the setup in TP_SendToAnalysis()
///
threadsafe Function/DF TP_TSAnalysis(dfrInp)
	DFREF dfrInp

	variable evalRange, refTime, refPoint, tpStartPoint
	variable sampleInt
	variable avgBaselineSS, avgTPSS, avgInst

	DFREF dfrOut = NewFreeDataFolder()

	WAVE data = dfrInp:param0
	NVAR/SDFR=dfrInp clampAmp = param1
	NVAR/SDFR=dfrInp clampMode = param2
	NVAR/SDFR=dfrInp duration = param3
	NVAR/SDFR=dfrInp baselineFrac = param4
	NVAR/SDFR=dfrInp lengthTPInPoints = param5
	NVAR/SDFR=dfrInp now = param6
	NVAR/SDFR=dfrInp hsIndex = param7
	SVAR/SDFR=dfrInp panelTitle = param8
	NVAR/SDFR=dfrInp marker = param9
	NVAR/SDFR=dfrInp activeADCs = param10

#if defined(TP_ANALYSIS_DEBUGGING)
	DEBUGPRINT_TS("Marker: ", var = marker)
	Duplicate data dfrOut:colors
	Duplicate data dfrOut:data
	WAVE colors = dfrOut:colors
	colors = 0
	colors[0, lengthTPInPoints - 1] = 100
#endif

	// Rows:
	// 0: base line level
	// 1: steady state resistance
	// 2: instantaneous resistance
	// 3: averaged elevated level (steady state)
	// 4: avrraged elevated level (instantaneous)
	Make/N=5/D dfrOut:outData/wave=outData
	SetDimLabel ROWS, 0, BASELINE, outData
	SetDimLabel ROWS, 1, STEADYSTATERES, outData
	SetDimLabel ROWS, 2, INSTANTRES, outData
	SetDimLabel ROWS, 3, ELEVATED_SS, outData
	SetDimLabel ROWS, 4, ELEVATED_INST, outData

	sampleInt = DimDelta(data, ROWS)
	tpStartPoint = baseLineFrac * lengthTPInPoints
	evalRange = min(5 / sampleInt, min(duration * 0.2, tpStartPoint * 0.2)) * sampleInt

	refTime = (tpStartPoint - TP_EVAL_POINT_OFFSET) * sampleInt
	AvgBaselineSS = mean(data, refTime - evalRange, refTime)

#if defined(TP_ANALYSIS_DEBUGGING)
	// color BASE
	variable refpt = tpStartPoint - TP_EVAL_POINT_OFFSET
	colors[refpt - evalRange / sampleInt, refpt] = 50
	DEBUGPRINT_TS("SampleInt: ", var = sampleInt)
	DEBUGPRINT_TS("tpStartPoint: ", var = tpStartPoint)
	DEBUGPRINT_TS("evalRange (ms): ", var = evalRange)
	DEBUGPRINT_TS("evalRange in points: ", var = evalRange / sampleInt)
	DEBUGPRINT_TS("Base range begin (ms): ", var = refTime - evalRange)
	DEBUGPRINT_TS("Base range eng (ms): ", var = refTime)
	DEBUGPRINT_TS("average BaseLine: ", var = AvgBaselineSS)
#endif

	refTime = (lengthTPInPoints - tpStartPoint - TP_EVAL_POINT_OFFSET) * sampleInt
	avgTPSS = mean(data, refTime - evalRange, refTime)

#if defined(TP_ANALYSIS_DEBUGGING)
	DEBUGPRINT_TS("TPSS range begin (ms): ", var = refTime - evalRange)
	DEBUGPRINT_TS("TPSS range eng (ms): ", var = refTime)
	DEBUGPRINT_TS("average TPSS: ", var = avgTPSS)
	// color SS
	refpt = lengthTPInPoints - tpStartPoint - TP_EVAL_POINT_OFFSET
	colors[refpt - evalRange / sampleInt, refpt] = 50
	// color INST
	refpt = tpStartPoint + TP_EVAL_POINT_OFFSET
	colors[refpt, refpt + 0.25 / sampleInt] = 50
#endif

	refPoint = tpStartPoint + TP_EVAL_POINT_OFFSET
	Duplicate/FREE/R=[refPoint, refPoint + 0.25 / sampleInt] data, inst1d
	WaveStats/Q/M=1 inst1d
	avgInst = (clampAmp < 0) ? mean(inst1d, pnt2x(inst1d, V_minRowLoc - 1), pnt2x(inst1d, V_minRowLoc + 1)) : mean(inst1d, pnt2x(inst1d, V_maxRowLoc - 1), pnt2x(inst1d, V_maxRowLoc + 1))

#if defined(TP_ANALYSIS_DEBUGGING)
	refpt = V_minRowLoc + refPoint
	DEBUGPRINT_TS("refPoint IntSS: ", var = refpt)
	DEBUGPRINT_TS("average InstSS: ", var = avgInst)
	colors[refpt - 1, refpt + 1] = 75
#endif

	if(clampMode == I_CLAMP_MODE)
		outData[1] = (avgTPSS - avgBaselineSS) / clampAmp * 1000
		outData[2] = (avgInst - avgBaselineSS) / clampAmp * 1000
	else
		outData[1] = clampAmp / (avgTPSS - avgBaselineSS) * 1000
		outData[2] = clampAmp / (avgInst - avgBaselineSS) * 1000
	endif
	outData[0] = avgBaselineSS
	outData[3] = avgTPSS
	outData[4] = avgInst

#if defined(TP_ANALYSIS_DEBUGGING)
	DEBUGPRINT_TS("IntRes: ", var = outData[2])
	DEBUGPRINT_TS("SSRes: ", var = outData[1])
#endif

	// additional data copy
	variable/G dfrOut:now = now
	variable/G dfrOut:hsIndex = hsIndex
	string/G dfrOut:panelTitle = panelTitle
	variable/G dfrOut:marker = marker
	variable/G dfrOut:activeADCs = activeADCs

	return dfrOut
End

/// @brief Calculates running average [box average] for all entries and all headstages
static Function TP_CalculateAverage(WAVE TPResultsBuffer, WAVE TPResults)
	variable numEntries, numLayers

	MatrixOp/FREE TPResultsBufferCopy = rotateLayers(TPResultsBuffer, 1)
	TPResultsBuffer[][][]  = TPResultsBufferCopy[p][q][r]
	TPResultsBuffer[][][0] = TPResults[p][q]

	numLayers  = DimSize(TPResultsBuffer, LAYERS)
	numEntries = GetNumberFromWaveNote(TPResultsBuffer, NOTE_INDEX)

	if(numEntries < numLayers)
		numEntries += 1
		SetNumberInWaveNote(TPResultsBuffer, NOTE_INDEX, numEntries)
		Duplicate/FREE/RMD=[][][0, numEntries - 1] TPResultsBuffer, TPResultsBufferSub
		MatrixOp/FREE results = sumBeams(TPResultsBufferSub) / numEntries
	else
		ASSERT(numEntries == numLayers, "Unexpected number of entries/layers")
		MatrixOp/FREE results = sumBeams(TPResultsBuffer) / numEntries
	endif

	TPResults[][] = results[p][q]
End

/// @brief Records values from  BaselineSSAvg, InstResistance, SSResistance into TPStorage at defined intervals.
///
/// Used for analysis of TP over time.
/// When the TP is initiated by any method, the TP storageWave should be empty
/// If 200 ms have elapsed, or it is the first TP sweep,
/// data from the input waves is transferred to the storage waves.
static Function TP_RecordTP(panelTitle, TPResults, now, tpMarker)
	string panelTitle
	WAVE TPResults
	variable now, tpMarker

	variable delta, i, ret, lastPressureCtrl, timestamp
	WAVE TPStorage = GetTPStorage(panelTitle)
	WAVE hsProp = GetHSProperties(panelTitle)
	variable count = GetNumberFromWaveNote(TPStorage, NOTE_INDEX)
	variable lastRescaling = GetNumberFromWaveNote(TPStorage, DIMENSION_SCALING_LAST_INVOC)

	if(!count)
		// time of the first sweep
		TPStorage[0][][%TimeInSeconds] = now

		WAVE statusHS = DAG_GetChannelState(panelTitle, CHANNEL_TYPE_HEADSTAGE)

		for(i = 0 ; i < NUM_HEADSTAGES; i += 1)

			if(!statusHS[i])
				continue
			endif

			TP_UpdateHoldCmdInTPStorage(panelTitle, i)
		endfor
	endif

	ret = EnsureLargeEnoughWave(TPStorage, minimumSize=count, dimension=ROWS, initialValue=NaN, checkFreeMemory = 1)

	if(ret) // running out of memory
		printf "The amount of free memory is too low to increase TPStorage, please create a new experiment.\r"
		ControlWindowToFront()
		LOG_AddEntry(PACKAGE_MIES, "out of memory")
		DQ_StopDAQ(panelTitle, DQ_STOP_REASON_OUT_OF_MEMORY, startTPAfterDAQ = 0)
		TP_StopTestPulse(panelTitle)
		return NaN
	endif

	// use the last value if we don't have a current one
	if(count > 0)
		TPStorage[count][][%HoldingCmd_VC] = !IsFinite(TPStorage[count][q][%HoldingCmd_VC]) \
											 ? TPStorage[count - 1][q][%HoldingCmd_VC]      \
											 : TPStorage[count][q][%HoldingCmd_VC]

		TPStorage[count][][%HoldingCmd_IC] = !IsFinite(TPStorage[count][q][%HoldingCmd_IC]) \
											 ? TPStorage[count - 1][q][%HoldingCmd_IC]      \
											 : TPStorage[count][q][%HoldingCmd_IC]
	endif

	TPStorage[count][][%TimeInSeconds]              = now

	// store the current time in a variable first
	// so that all columns have the same timestamp
	timestamp = DateTime
	TPStorage[count][][%TimeStamp] = timestamp
	timestamp = DateTimeInUTC()
	TPStorage[count][][%TimeStampSinceIgorEpochUTC] = timestamp

	TPStorage[count][][%PeakResistance]        = min(TPResults[%ResistanceInst][q], TP_MAX_VALID_RESISTANCE)
	TPStorage[count][][%SteadyStateResistance] = min(TPResults[%ResistanceSteadyState][q], TP_MAX_VALID_RESISTANCE)
	TPStorage[count][][%ValidState]            = TPStorage[count][q][%PeakResistance] < TP_MAX_VALID_RESISTANCE \
															&& TPStorage[count][q][%SteadyStateResistance] < TP_MAX_VALID_RESISTANCE

	TPStorage[count][][%DAC]       = hsProp[q][%DAC]
	TPStorage[count][][%ADC]       = hsProp[q][%ADC]
	TPStorage[count][][%Headstage] = hsProp[q][%Enabled] ? q : NaN
	TPStorage[count][][%ClampMode] = hsProp[q][%ClampMode]

	TPStorage[count][][%Baseline_VC] = hsProp[q][%ClampMode] == V_CLAMP_MODE ? TPResults[%BaselineSteadyState][q] : NaN
	TPStorage[count][][%Baseline_IC] = hsProp[q][%ClampMode] == I_CLAMP_MODE ? TPResults[%BaselineSteadyState][q] : NaN

	TPStorage[count][][%DeltaTimeInSeconds] = count > 0 ? now - TPStorage[0][0][%TimeInSeconds] : 0
	TPStorage[count][][%TPMarker] = tpMarker

	lastPressureCtrl = GetNumberFromWaveNote(TPStorage, PRESSURE_CTRL_LAST_INVOC)
	if((now - lastPressureCtrl) > TP_PRESSURE_INTERVAL)
		P_PressureControl(panelTitle)
		SetNumberInWaveNote(TPStorage, PRESSURE_CTRL_LAST_INVOC, now, format="%.06f")
	endif

	TP_AnalyzeTP(panelTitle, TPStorage, count)

	WAVE TPStorageDat = ExtractLogbookSliceTimeStamp(TPStorage)
	EnsureLargeEnoughWave(TPStorageDat, minimumSize=count, dimension=ROWS, initialValue=NaN)
	TPStorageDat[count][] = TPStorage[count][q][%TimeStampSinceIgorEpochUTC]

	SetNumberInWaveNote(TPStorage, NOTE_INDEX, count + 1)
End

/// @brief Threadsafe wrapper for performing CurveFits on the TPStorage wave
threadsafe static Function CurveFitWrapper(TPStorage, startRow, endRow, headstage)
	WAVE TPStorage
	variable startRow, endRow, headstage

	variable V_FitQuitReason, V_FitOptions, V_FitError, V_AbortCode

	// finish early on missing data
	if(!IsFinite(TPStorage[startRow][headstage][%SteadyStateResistance])   \
	   || !IsFinite(TPStorage[endRow][headstage][%SteadyStateResistance]))
		return NaN
	endif

	Make/FREE/D/N=2 coefWave
	V_FitOptions = 4

	AssertOnAndClearRTError()
	try
		V_FitError  = 0
		V_AbortCode = 0
		CurveFit/Q/N=1/NTHR=1/M=0/W=2 line, kwCWave=coefWave, TPStorage[startRow,endRow][headstage][%SteadyStateResistance]/X=TPStorage[startRow,endRow][headstage][%TimeInSeconds]/AD=0/AR=0; AbortOnRTE
		return coefWave[1]
	catch
		ClearRTError()
	endtry

	return NaN
End

/// @brief Determine the slope of the steady state resistance
/// over a user defined window (in seconds)
///
/// @param panelTitle       locked device string
/// @param TPStorage        test pulse storage wave
/// @param endRow           last valid row index in TPStorage
static Function TP_AnalyzeTP(panelTitle, TPStorage, endRow)
	string panelTitle
	Wave/Z TPStorage
	variable endRow

	variable i, startRow, headstage

	startRow = endRow - ceil(TP_FIT_POINTS / TP_TPSTORAGE_EVAL_INTERVAL)

	if(startRow < 0 || startRow >= endRow || !WaveExists(TPStorage) || endRow >= DimSize(TPStorage,ROWS))
		return NaN
	endif

	Make/FREE/N=(NUM_HEADSTAGES) statusHS = 0

	for(i = 0; i < NUM_HEADSTAGES; i += 1)

		headstage = TPStorage[endRow][i][%Headstage]

		if(!IsFinite(headstage) || DC_GetChannelTypefromHS(panelTitle, headstage) != DAQ_CHANNEL_TYPE_TP)
			continue
		endif

		statusHS[i] = 1
	endfor

	Multithread TPStorage[0][][%Rss_Slope] = statusHS[q] ? CurveFitWrapper(TPStorage, startRow, endRow, q) : NaN
End

/// @brief Stop running background testpulse on all locked devices
Function TP_StopTestPulseOnAllDevices()

	CallFunctionForEachListItem(TP_StopTestPulse, GetListOfLockedDevices())
End

/// @sa TP_StopTestPulseWrapper
Function TP_StopTestPulseFast(panelTitle)
	string panelTitle

	return TP_StopTestPulseWrapper(panelTitle, fast = 1)
End

/// @sa TP_StopTestPulseWrapper
Function TP_StopTestPulse(panelTitle)
	string panelTitle

	return TP_StopTestPulseWrapper(panelTitle, fast = 0)
End

/// @brief Stop any running background test pulses
///
/// @param panelTitle device
/// @param fast       [optional, defaults to false] Performs only the totally
///                   necessary steps for tear down.
///
/// @return One of @ref TestPulseRunModes
static Function TP_StopTestPulseWrapper(panelTitle, [fast])
	string panelTitle
	variable fast

	variable runMode

	if(ParamIsDefault(fast))
		fast = 0
	else
		fast = !!fast
	endif

	NVAR runModeGlobal = $GetTestpulseRunMode(panelTitle)

	// create copy as TP_TearDown() will change runModeGlobal
	runMode = runModeGlobal

	// clear all modifiers from runMode
	runMode = runMode & ~TEST_PULSE_DURING_RA_MOD

	if(runMode == TEST_PULSE_BG_SINGLE_DEVICE)
		TPS_StopTestPulseSingleDevice(panelTitle, fast = fast)
		return runMode
	elseif(runMode == TEST_PULSE_BG_MULTI_DEVICE)
		TPM_StopTestPulseMultiDevice(panelTitle, fast = fast)
		return runMode
	elseif(runMode == TEST_PULSE_FG_SINGLE_DEVICE)
		// can not be stopped
		return runMode
	endif

	return TEST_PULSE_NOT_RUNNING
End

/// @brief Restarts a test pulse previously stopped with #TP_StopTestPulse
Function TP_RestartTestPulse(panelTitle, testPulseMode, [fast])
	string panelTitle
	variable testPulseMode, fast

	if(ParamIsDefault(fast))
		fast = 0
	else
		fast = !!fast
	endif

	switch(testPulseMode)
		case TEST_PULSE_NOT_RUNNING:
			break // nothing to do
		case TEST_PULSE_BG_SINGLE_DEVICE:
			TPS_StartTestPulseSingleDevice(panelTitle, fast = fast)
			break
		case TEST_PULSE_BG_MULTI_DEVICE:
			TPM_StartTestPulseMultiDevice(panelTitle, fast = fast)
			break
		default:
			DEBUGPRINT("Ignoring unknown value:", var=testPulseMode)
			break
	endswitch
End

/// @brief Prepare device for TestPulse
/// @param panelTitle  device
/// @param runMode     Testpulse running mode, one of @ref TestPulseRunModes
/// @param fast        [optional, defaults to false] Performs only the totally necessary steps for setup
Function TP_Setup(panelTitle, runMode, [fast])
	string panelTitle
	variable runMode
	variable fast

	variable multiDevice

	if(ParamIsDefault(fast))
		fast = 0
	else
		fast = !!fast
	endif

	if(fast)
		NVAR runModeGlobal = $GetTestpulseRunMode(panelTitle)
		runModeGlobal = runMode

		NVAR deviceID = $GetDAQDeviceID(panelTitle)
		HW_PrepareAcq(GetHardwareType(panelTitle), deviceID, TEST_PULSE_MODE, flags=HARDWARE_ABORT_ON_ERROR)
		return NaN
	endif

	multiDevice = (runMode & TEST_PULSE_BG_MULTI_DEVICE)

	TP_SetupCommon(panelTitle)

	if(!(runMode & TEST_PULSE_DURING_RA_MOD))
		DAP_ToggleTestpulseButton(panelTitle, TESTPULSE_BUTTON_TO_STOP)
		DisableControls(panelTitle, CONTROLS_DISABLE_DURING_DAQ_TP)
	endif

	NVAR runModeGlobal = $GetTestpulseRunMode(panelTitle)
	runModeGlobal = runMode

	DC_Configure(panelTitle, TEST_PULSE_MODE, multiDevice=multiDevice)

	NVAR deviceID = $GetDAQDeviceID(panelTitle)
	HW_PrepareAcq(GetHardwareType(panelTitle), deviceID, TEST_PULSE_MODE, flags=HARDWARE_ABORT_ON_ERROR)
End

/// @brief Common setup calls for TP and TP during DAQ
Function TP_SetupCommon(panelTitle)
	string panelTitle

	variable now, index

	// ticks are relative to OS start time
	// so we can have "future" timestamps from existing experiments
	WAVE TPStorage = GetTPStorage(panelTitle)
	now = ticks * TICKS_TO_SECONDS

	if(GetNumberFromWaveNote(TPStorage, DIMENSION_SCALING_LAST_INVOC) > now)
		SetNumberInWaveNote(TPStorage, DIMENSION_SCALING_LAST_INVOC, 0)
	endif

	if(GetNumberFromWaveNote(TPStorage, AUTOBIAS_LAST_INVOCATION_KEY) > now)
		SetNumberInWaveNote(TPStorage, AUTOBIAS_LAST_INVOCATION_KEY, 0)
	endif

	if(GetNumberFromWaveNote(TPStorage, PRESSURE_CTRL_LAST_INVOC) > now)
		SetNumberInWaveNote(TPStorage, PRESSURE_CTRL_LAST_INVOC, 0)
	endif

	index = GetNumberFromWaveNote(TPStorage, NOTE_INDEX)
	SetNumberInWaveNote(TPStorage, INDEX_ON_TP_START, index)

	WAVE tpAsyncBuffer = GetTPResultAsyncBuffer(panelTitle)
	KillOrMoveToTrash(wv=tpAsyncBuffer)
End

/// @brief Perform common actions after the testpulse
Function TP_Teardown(panelTitle, [fast])
	string panelTitle
	variable fast

	if(ParamIsDefault(fast))
		fast = 0
	else
		fast = !!fast
	endif

	NVAR runMode = $GetTestpulseRunMode(panelTitle)

	if(fast)
		runMode = TEST_PULSE_NOT_RUNNING
		return NaN
	endif

	if(!(runMode & TEST_PULSE_DURING_RA_MOD))
		EnableControls(panelTitle, CONTROLS_DISABLE_DURING_DAQ_TP)
		DAP_SwitchSingleMultiMode(panelTitle)
	endif

	DAP_ToggleTestpulseButton(panelTitle, TESTPULSE_BUTTON_TO_START)

	ED_TPDocumentation(panelTitle)

	SCOPE_KillScopeWindowIfRequest(panelTitle)

	runMode = TEST_PULSE_NOT_RUNNING

	TP_TeardownCommon(panelTitle)
End

/// @brief Common teardown calls for TP and TP during DAQ
Function TP_TeardownCommon(panelTitle)
	string panelTitle

	P_LoadPressureButtonState(panelTitle)
End
/// @brief Return the number of devices which have TP running
Function TP_GetNumDevicesWithTPRunning()

	variable numEntries, i, count
	string list, panelTitle

	list = GetListOfLockedDevices()
	numEntries = ItemsInList(list)
	for(i= 0; i < numEntries;i += 1)
		panelTitle = StringFromList(i, list)
		count += TP_CheckIfTestpulseIsRunning(panelTitle)
	endfor

	return count
End

/// @brief Check if the testpulse is running
///
/// Can not be used to check for foreground TP as during foreground TP/DAQ nothing else runs.
Function TP_CheckIfTestpulseIsRunning(panelTitle)
	string panelTitle

	NVAR runMode = $GetTestpulseRunMode(panelTitle)

	return isFinite(runMode) && runMode != TEST_PULSE_NOT_RUNNING && (IsDeviceActiveWithBGTask(panelTitle, TASKNAME_TP) || IsDeviceActiveWithBGTask(panelTitle, TASKNAME_TPMD))
End

/// @brief See if the testpulse has run enough times to create valid measurements
///
/// @param panelTitle		DA_Ephys panel name
/// @param cycles		number of cycles that test pulse must run
Function TP_TestPulseHasCycled(panelTitle, cycles)
	string panelTitle
	variable cycles

	variable index, indexOnTPStart

	WAVE TPStorage = GetTPStorage(panelTitle)
	index          = GetNumberFromWaveNote(TPStorage, NOTE_INDEX)
	indexOnTPStart = GetNumberFromWaveNote(TPStorage, INDEX_ON_TP_START)

	return (index - indexOnTPStart) > cycles
End

/// @brief Save the amplifier holding command in the TPStorage wave
Function TP_UpdateHoldCmdInTPStorage(panelTitle, headStage)
	string panelTitle
	variable headStage

	variable count, clampMode

	if(!TP_CheckIfTestpulseIsRunning(panelTitle))
		return NaN
	endif

	WAVE TPStorage = GetTPStorage(panelTitle)

	count = GetNumberFromWaveNote(TPStorage, NOTE_INDEX)
	EnsureLargeEnoughWave(TPStorage, minimumSize=count, dimension=ROWS, initialValue=NaN)

	if(!IsFinite(TPStorage[count][headstage][%Headstage])) // HS not active
		return NaN
	endif

	clampMode = TPStorage[count][headstage][%ClampMode]

	if(clampMode == V_CLAMP_MODE)
		TPStorage[count][headstage][%HoldingCmd_VC] = AI_GetHoldingCommand(panelTitle, headStage)
	else
		TPStorage[count][headstage][%HoldingCmd_IC] = AI_GetHoldingCommand(panelTitle, headStage)
	endif
End

/// @brief Create the testpulse wave with the current settings
Function TP_CreateTestPulseWave(panelTitle, dataAcqOrTP)
	string panelTitle
	variable dataAcqOrTP

	variable length, baselineFrac

	WAVE TestPulse = GetTestPulse()
	WAVE TPSettingsCalc = GetTPsettingsCalculated(panelTitle)

	length = (dataAcqOrTP == TEST_PULSE_MODE) ? TPSettingsCalc[%totalLengthPointsTP] : TPSettingsCalc[%totalLengthPointsDAQ]

	Redimension/N=(length) TestPulse
	FastOp TestPulse = 0

	baselineFrac = TPSettingsCalc[%baselineFrac]

	TestPulse[baselineFrac * length, (1 - baselineFrac) * length] = 1
End

/// @brief Send a TP data set to the asynchroneous analysis function TP_TSAnalysis
///
/// @param[in] panelTitle title of panel that ran this test pulse
/// @param tpInput holds the parameters send to analysis
Function TP_SendToAnalysis(string panelTitle, STRUCT TPAnalysisInput &tpInput)

	DFREF threadDF = ASYNC_PrepareDF("TP_TSAnalysis", "TP_ROAnalysis", WORKLOADCLASS_TP + panelTitle, inOrder=0)
	ASYNC_AddParam(threadDF, w=tpInput.data)
	ASYNC_AddParam(threadDF, var=tpInput.clampAmp)
	ASYNC_AddParam(threadDF, var=tpInput.clampMode)
	ASYNC_AddParam(threadDF, var=tpInput.duration)
	ASYNC_AddParam(threadDF, var=tpInput.baselineFrac)
	ASYNC_AddParam(threadDF, var=tpInput.tpLengthPoints)
	ASYNC_AddParam(threadDF, var=tpInput.readTimeStamp)
	ASYNC_AddParam(threadDF, var=tpInput.hsIndex)
	ASYNC_AddParam(threadDF, str=tpInput.panelTitle)
	ASYNC_AddParam(threadDF, var=tpInput.measurementMarker)
	ASYNC_AddParam(threadDF, var=tpInput.activeADCs)
	ASYNC_Execute(threadDF)
End

/// @brief Update calculated and LBN TP waves
///
/// Calling this function before DAQ/TP allows to query calculated TP settings during DAQ/TP via GetTPSettingsCalculated().
Function TP_UpdateTPSettingsLBNWaves(string panelTitle)
	WAVE TPSettings = GetTPSettings(panelTitle)

	WAVE calculated = GetTPSettingsCalculated(panelTitle)
	calculated = NaN

	// update the calculated values
	calculated[%baselineFrac]         = TPSettings[%baselinePerc][INDEP_HEADSTAGE] / 100

	calculated[%pulseLengthMS]        = TPSettings[%durationMS][INDEP_HEADSTAGE] // here for completeness
	calculated[%pulseLengthPointsTP]  = trunc(TPSettings[%durationMS][INDEP_HEADSTAGE] / (DAP_GetSampInt(panelTitle, TEST_PULSE_MODE) / 1000))
	calculated[%pulseLengthPointsDAQ] = trunc(TPSettings[%durationMS][INDEP_HEADSTAGE] / (DAP_GetSampInt(panelTitle, DATA_ACQUISITION_MODE) / 1000))

	calculated[%totalLengthMS]        = TP_CalculateTestPulseLength(calculated[%pulseLengthMS], calculated[%baselineFrac])
	calculated[%totalLengthPointsTP]  = trunc(TP_CalculateTestPulseLength(calculated[%pulseLengthPointsTP], calculated[%baselineFrac]))
	calculated[%totalLengthPointsDAQ] = trunc(TP_CalculateTestPulseLength(calculated[%pulseLengthPointsDAQ], calculated[%baselineFrac]))

	// store the current TP settings for later LBN writing via ED_TPSettingsDocumentation()
	KillOrMoveToTrash(wv=GetTPSettingsLabnotebook(panelTitle))
	KillOrMoveToTrash(wv=GetTPSettingsLabnotebookKeyWave(panelTitle))

	WAVE TPSettingsLBN  = GetTPSettingsLabnotebook(panelTitle)

	TPSettingsLBN[0][%$"TP Baseline Fraction"][INDEP_HEADSTAGE] = calculated[%baselineFrac]
	TPSettingsLBN[0][%$"TP Amplitude VC"][INDEP_HEADSTAGE]      = TPSettings[%amplitudeVC][INDEP_HEADSTAGE]
	TPSettingsLBN[0][%$"TP Amplitude IC"][INDEP_HEADSTAGE]      = TPSettings[%amplitudeIC][INDEP_HEADSTAGE]
	TPSettingsLBN[0][%$"TP Pulse Duration"][INDEP_HEADSTAGE]    = calculated[%pulseLengthMS]
End
