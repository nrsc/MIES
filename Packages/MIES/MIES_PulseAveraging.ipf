#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3 // Use modern global access method and strict wave access.
#pragma rtFunctionErrors=1

/// @file MIES_PulseAveraging.ipf
///
/// @brief __PA__ Routines for dealing with pulse averaging.

static StrConstant PULSE_AVERAGE_GRAPH_PREFIX = "PulseAverage"
static StrConstant SOURCE_WAVE_TIMESTAMP      = "SOURCE_WAVE_TS"

static StrConstant PA_AVERAGE_WAVE_PREFIX       = "average_"
static StrConstant PA_DECONVOLUTION_WAVE_PREFIX = "deconv_"

static StrConstant PA_USERDATA_SPECIAL_TRACES = "SPECIAL_TRACES"

static Constant PA_PLOT_STEPPING = 16

/// @brief Return a list of all average graphs
static Function/S PA_GetAverageGraphs()
	return WinList(PULSE_AVERAGE_GRAPH_PREFIX + "*", ";", "WIN:1")
End

static Function/S PA_GetGraphName(multipleGraphs, channelTypeStr, channelNumber, activeRegionCount)
	variable multipleGraphs, channelNumber, activeRegionCount
	string channelTypeStr

	if(multipleGraphs)
		return PULSE_AVERAGE_GRAPH_PREFIX + "_" + channelTypeStr + num2str(channelNumber) + "_R" + num2str(activeRegionCount)
	else
		return PULSE_AVERAGE_GRAPH_PREFIX
	endif
End

/// @brief Return the name of the pulse average graph
///
/// This function takes care of creating a graph if it does not exist, and laying it out correctly
///
/// Layout scheme for multiple graphs turned on:
/// - Positions the graphs right to `mainWin` in matrix form
/// - Columns: Regions (aka headstages with pulse starting time information respecting region selection in GUI)
/// - Rows:    Active unique channels
static Function/S PA_GetGraph(mainWin, multipleGraphs, channelTypeStr, channelNumber, region, activeRegionCount, activeChanCount)
	string mainWin, channelTypeStr
	variable multipleGraphs, channelNumber, region, activeRegionCount, activeChanCount

	variable top, left, bottom, right, i
	variable width, height, width_spacing, height_spacing, width_offset, height_offset
	string win, winAbove

	win = PA_GetGraphName(multipleGraphs, channelTypeStr, channelNumber, activeRegionCount)

	if(!WindowExists(win))

		if(multipleGraphs)
			width          = 100
			height         = 80
			width_spacing  = 10
			height_spacing = 3.5
			width_offset   = (activeRegionCount - 1) * (width  + width_spacing)
			height_offset  = (activeChanCount   - 1) * (height + 2 * height_spacing)
		else
			width         = 400
			height        = 400
			width_spacing = 10
			// rest is zero already
		endif

		GetWindow $mainWin wsize
		left   = V_right + width_spacing
		top    = V_top
		right  = left + width
		bottom = top + height

		left   += width_offset
		right  += width_offset
		top    += height_offset
		bottom += height_offset
		Display/W=(left, top, right, bottom)/K=1/N=$win

		if(multipleGraphs)
			winAbove = PA_GetGraphName(multipleGraphs, channelTypeStr, channelNumber - 1, activeRegionCount)

			for(i = channelNumber - 1; i >=0; i -= 1)
				winAbove = PA_GetGraphName(multipleGraphs, channelTypeStr, i, activeRegionCount)

				if(WindowExists(winAbove))
					DoWindow/B=$winAbove $win
					break
				endif
			endfor
		endif
	endif

	return win
End

/// @brief Return the names of the vertical and horizontal axes
static Function PA_GetAxes(multipleGraphs, activeRegionCount, activeChanCount, vertAxis, horizAxis)
	variable multipleGraphs, activeRegionCount, activeChanCount
	string &vertAxis, &horizAxis

	if(multipleGraphs)
		vertAxis  = "left"
		horizAxis = "bottom"
	else
		sprintf vertAxis,  "left_R%d_C%d", activeRegionCount, activeChanCount
		sprintf horizAxis, "bottom_R%d", activeRegionCount
	endif
End

/// @brief Return a wave with the pulse starting times from the labnotebook
///
/// In case nothing could be found in the labnotebook an invalid wave reference is returned.
static Function/WAVE PA_GetPulseStartTimesFromLB(textualValues, sweepNo, headstage)
	WAVE/T textualValues
	variable sweepNo, headstage

	WAVE/Z/T pulseStartTimes = GetLastSetting(textualValues, sweepNo, PULSE_START_TIMES_KEY, DATA_ACQUISITION_MODE)
	if(!WaveExists(pulseStartTimes))
		return $""
	endif

	return ListToNumericWave(pulseStartTimes[headstage], ";")
End

/// @brief Derive the pulse starting times from a DA wave
///
/// Uses plain FindLevels after the onset delay using 10% of the full range
/// above the minimum as threshold
///
/// @return wave with pulse starting times, or an invalid wave reference if none could be found.
static Function/WAVE PA_CalculatePulseStartTimes(DA, totalOnsetDelay)
	WAVE DA
	variable totalOnsetDelay

	variable level, delta
	string key
	ASSERT(totalOnsetDelay >= 0, "Invalid onsetDelay")

	key = CA_PulseStartTimes(DA, totalOnsetDelay)
	WAVE/Z cache = CA_TryFetchingEntryFromCache(key)
	if(WaveExists(cache))
		return cache
	endif

	WaveStats/Q/M=1/R=(totalOnsetDelay, inf) DA
	level = V_min + (V_Max - V_Min) * 0.1

	MAKE/FREE/D levels
	FindLevels/Q/R=(totalOnsetDelay, inf)/EDGE=1/DEST=levels DA, level

	if(DimSize(levels, ROWS) == 0)
		return $""
	endif

	delta = DimDelta(DA, ROWS)

	// FindLevels interpolates between two points and searches for a rising edge
	// so the returned value is commonly a bit too large
	// round to the last wave point
	levels[] = levels[p] - mod(levels[p], delta)

	CA_StoreEntryIntoCache(key, levels)
	return levels
End

/// @brief Add all available sweep data to traceData
///
/// This function can fill in the available data for traces which are *not*
/// shown.
static Function PA_AddMissingADTraceInfo(traceData)
	WAVE/T traceData

	variable numPaths, i, j, idx, cnt, sweepNumber
	variable numEntries, headstage
	string folder

	Duplicate/FREE/T traceData, newData
	newData = ""

	// get a list of folders holding the sweep data
	numPaths = DimSize(traceData, ROWS)
	Make/FREE/WAVE/N=(numPaths) shownWaves = $traceData[p][%fullPath]

	for(i = 0; i < numPaths; i += 1)
		DFREF sweepDFR = $GetWavesDataFolder(shownWaves[i], 1)
		WAVE/WAVE allWaves = GetITCDataSingleColumnWaves(sweepDFR, ITC_XOP_CHANNEL_TYPE_ADC)

		WAVE numericalValues = $traceData[i][%numericalValues]
		sweepNumber = str2num(traceData[i][%sweepNumber])

		WAVE ADCs = GetLastSetting(numericalValues, sweepNumber, "ADC", DATA_ACQUISITION_MODE)
		WAVE HS = GetLastSetting(numericalValues, sweepNumber, "Headstage Active", DATA_ACQUISITION_MODE)

		numEntries = DimSize(allWaves, ROWS)
		for(j = 0; j < numEntries; j += 1)
			WAVE/Z wv = allWaves[j]

			// no sweep data for this channel
			if(!WaveExists(wv))
				continue
			endif

			idx = GetRowIndex(shownWaves, refWave = allWaves[j])

			if(IsFinite(idx)) // single sweep data already in traceData
				continue
			endif

			// labnotebook layer where the ADC can be found is the headstage number
			headstage = GetRowIndex(ADCs, val=j)

			if(!IsFinite(headstage)) // unassociated ADC
				continue
			endif

			EnsureLargeEnoughWave(newData, minimumSize=cnt)
			newData[cnt][] = traceData[i][q]

			newData[cnt][%traceName]     = ""
			newData[cnt][%fullPath]      = GetWavesDataFolder(wv, 2)
			newData[cnt][%channelType]   = StringFromList(ITC_XOP_CHANNEL_TYPE_ADC, ITC_CHANNEL_NAMES)
			newData[cnt][%channelNumber] = num2str(j)
			newData[cnt][%headstage]     = num2str(headstage)
			cnt += 1
		endfor
	endfor

	if(cnt == 0)
		return NaN
	endif

	Redimension/N=(numPaths + cnt, -1) traceData

	traceData[numPaths, inf][] = newData[p - numPaths][q]
End

/// @brief Return a list of all sweep traces in the graph skipping traces which
///        refer to the same wave.
///
///        Columns have colum labels and include various userdata readout from the traces.
Function/WAVE PA_GetTraceInfos(graph, [includeOtherADData, channelType])
	string graph
	variable includeOtherADData, channelType

	variable numTraces, numEntries, i
	string trace, traceList, traceListClean, traceFullPath

	if(ParamIsDefault(includeOtherADData))
		includeOtherADData = 0
	else
		includeOtherADData = !!includeOtherADData
	endif

	if(ParamIsDefault(channelType))
		traceList = GetAllSweepTraces(graph)
	else
		traceList = GetAllSweepTraces(graph, channelType = channelType)
	endif

	numTraces = ItemsInList(traceList)

	if(numTraces == 0)
		return $""
	endif

	Make/FREE/T/N=(numTraces) traceWaveList = GetWavesDataFolder(TraceNameToWaveRef(graph, StringFromList(p, traceList)), 2)

	if(numTraces > 1)
		// replace duplicates with empty entries
		Make/T/FREE tracesFullPath
		FindDuplicates/Z/ST=""/STDS=tracesFullPath traceWaveList
	else
		WAVE/T tracesFullPath = traceWaveList
	endif

	WAVE indizes = FindIndizes(tracesFullPath, prop=PROP_NON_EMPTY, col=0)

	numTraces = DimSize(indizes, ROWS)
	Make/N=(numTraces, 8)/FREE/T traceData

	SetWaveDimLabel(traceData, "traceName;fullPath;channelType;channelNumber;sweepNumber;headstage;textualValues;numericalValues", COLS)

	traceData[][%traceName]        = StringFromList(indizes[p], traceList)
	traceData[][%fullPath]         = GetWavesDataFolder(TraceNameToWaveRef(graph, traceData[p][%traceName]), 2)
	traceData[][%channelType, inf] = GetUserData(graph, traceData[p][%traceName], GetDimLabel(traceData, COLS, q))

	if(includeOtherADData)
		PA_AddMissingADTraceInfo(traceData)
	endif

	SortColumns/A/DIML/KNDX={2, 3, 4, 5} sortWaves=traceData

	return traceData
End

/// @brief Return a wave with headstage numbers, duplicates replaced with NaN
///        so that the indizes still correspond the ones in traceData
///
///        Returns an invalid wave reference in case indizesChannelType does not exist.
static Function/WAVE PA_GetUniqueHeadstages(traceData, indizesChannelType)
	WAVE/T traceData
	WAVE/Z indizesChannelType

	if(!WaveExists(indizesChannelType))
		return $""
	endif

	Make/D/FREE/N=(DimSize(indizesChannelType, ROWS)) headstages = str2num(traceData[indizesChannelType[p]][%headstage])

	if(DimSize(headstages, ROWS) == 1)
		return headstages
	endif

	Make/FREE/D headstagesClean
	FindDuplicates/Z/SN=(NaN)/SNDS=headstagesClean headstages

	return headstagesClean
End

/// @brief Return the pulse starting times
///
/// @param traceData        2D wave with trace information, usually generated by PA_GetTraceInfos()
/// @param idx              Index into traceData, used for determining sweep numbers, labnotebooks, etc.
/// @param region           Region (headstage) to get pulse starting times for
/// @param channelTypeStr   Type of the channel, one of @ref ITC_CHANNEL_NAMES
/// @param removeOnsetDelay [optional, defaults to true] Remove the onset delay from the starting times (true) or not (false)
Function/WAVE PA_GetPulseStartTimes(traceData, idx, region, channelTypeStr, [removeOnsetDelay])
	WAVE/T traceData
	variable idx, region
	string channelTypeStr
	variable removeOnsetDelay

	variable sweepNo, totalOnsetDelay
	string str

	if(ParamIsDefault(removeOnsetDelay))
		removeOnsetDelay = 1
	else
		removeOnsetDelay = !!removeOnsetDelay
	endif

	// we currently use the regions from the sweep with the lowest
	// number, see the SortColumns invocation in PA_GetTraceInfos.
	sweepNo = str2num(traceData[idx][%sweepNumber])

	WAVE/Z textualValues   = $traceData[idx][%textualValues]
	WAVE/Z numericalValues = $traceData[idx][%numericalValues]

	ASSERT(WaveExists(textualValues) && WaveExists(numericalValues), "Missing labnotebook waves")

	if(removeOnsetDelay)
		totalOnsetDelay = GetTotalOnsetDelay(numericalValues, sweepNo)
	endif

	WAVE/Z pulseStartTimes = PA_GetPulseStartTimesFromLB(textualValues, sweepNo, region)

	if(WaveExists(pulseStartTimes))
		sprintf str, "Found pulse starting times for headstage %d", region
		DEBUGPRINT(str)

		pulseStartTimes[] -= totalOnsetDelay

		return pulseStartTimes
	endif

	// old data/stimsets without the required entries

	// find the folder where the referenced trace is located
	WAVE indizesCH    = FindIndizes(traceData, colLabel="channelType", str=channelTypeStr)
	WAVE indizesSweep = FindIndizes(traceData, colLabel="sweepNumber", var=sweepNo)
	WAVE indizesHS    = FindIndizes(traceData, colLabel="headstage", var=region)

	WAVE/Z indizes = GetSetIntersection(indizesHS, GetSetIntersection(indizesCH, indizesSweep))
	ASSERT(WaveExists(indizes) && DimSize(indizes, ROWS) == 1, "Unexpected state")

	DFREF singleSweepFolder = GetWavesDataFolderDFR($traceData[indizes[0]][%fullPath])
	ASSERT(DataFolderExistsDFR(singleSweepFolder), "Missing singleSweepFolder")

	// get the DA wave in that folder
	WAVE DACs = GetLastSetting(numericalValues, sweepNo, "DAC", DATA_ACQUISITION_MODE)
	WAVE DA = GetITCDataSingleColumnWave(singleSweepFolder, ITC_XOP_CHANNEL_TYPE_DAC, DACs[region])

	WAVE/Z pulseStartTimes = PA_CalculatePulseStartTimes(DA, totalOnsetDelay)

	if(!WaveExists(pulseStartTimes))
		return $""
	endif

	sprintf str, "Calculated pulse starting times for headstage %d", region
	DEBUGPRINT(str)

	pulseStartTimes[] -= totalOnsetDelay

	return pulseStartTimes
End

static Function PA_GetPulseToPulseLength(traceData, idx, region, pulseStartTimes, startingPulse, endingPulse, fallbackPulseLength)
	WAVE/T traceData, pulseStartTimes
	variable idx, region, startingPulse, endingPulse, fallbackPulseLength

	variable sweepNo

	WAVE numericalValues = $traceData[idx][%numericalValues]
	sweepNo = str2num(traceData[idx][%sweepNumber])
	WAVE/Z pulseToPulseLengths = GetLastSetting(numericalValues, sweepNo, PULSE_TO_PULSE_LENGTH_KEY, DATA_ACQUISITION_MODE)

	if(!WaveExists(pulseToPulseLengths) || pulseToPulseLengths[region] == 0)
		// either an old stim set without starting times or a new one
		// with poission distribution/mixed frequency turned on
		return PA_GetAveragePulseLength(pulseStartTimes, startingPulse, endingPulse, fallbackPulseLength)
	else
		// existing pulse train stimset and poisson distribution/mixed frequency turned off
		return pulseToPulseLengths[region]
	endif
End

static Function PA_GetAveragePulseLength(pulseStartTimes, startingPulse, endingPulse, fallbackPulseLength)
	WAVE pulseStartTimes
	variable startingPulse, endingPulse, fallbackPulseLength

	variable numPulses, minimum

	numPulses = endingPulse - startingPulse + 1

	if(numPulses <= 1)
		return fallbackPulseLength
	endif

	Make/FREE/D/N=(numPulses) pulseLengths
	pulseLengths[0] = NaN
	pulseLengths[1, inf] = pulseStartTimes[p] - pulseStartTimes[p - 1]

	minimum = WaveMin(pulseLengths)

	if(minimum > 0)
		return minimum
	endif

	// remove outliers which are too large
	// this happens with multiple epochs and space in between as then one
	// pulse to pulse length is way too big
	Extract/FREE pulseLengths, pulseLengthsClean, pulseLengths <= 2 * minimum

	WaveStats/Q/M=1 pulseLengthsClean

	return V_avg
End

static Function/WAVE PA_CreateAndFillPulseWaveIfReq(wv, singleSweepFolder, channelType, channelNumber, region, pulseIndex, first, length)
	WAVE/Z wv
	DFREF singleSweepFolder
	variable channelType, pulseIndex, first, length, channelNumber, region

	WAVE singlePulseWave = GetPulseAverageWave(singleSweepFolder, channelType, channelNumber, region, pulseIndex)

	if(first < 0 || length <= 0 || (DimSize(wv, ROWS) - first) <= length)
		return $""
	endif

	length = limit(length, 1, DimSize(wv, ROWS) - first)

	if(GetNumberFromWaveNote(singlePulseWave, "PulseLength") == length \
	   && GetNumberFromWaveNote(wv, SOURCE_WAVE_TIMESTAMP) == ModDate(wv))
		return singlePulseWave
	endif

	KillOrMoveToTrash(wv = GetBackupWave(singlePulseWave))

	Redimension/N=(length) singlePulseWave

	MultiThread singlePulseWave[] = wv[first + p]
	SetScale/P x, 0.0, DimDelta(wv, ROWS), WaveUnits(wv, ROWS), singlePulseWave
	SetNumberInWaveNote(singlePulseWave, NOTE_KEY_ZEROED, 0)
	SetNumberInWaveNote(singlePulseWave, "PulseLength", length)

	SetNumberInWaveNote(wv, SOURCE_WAVE_TIMESTAMP, ModDate(wv))

	return singlePulseWave
End

/// @brief Populates pps.pulseAverSett with the user selection from the panel
Function PA_GatherSettings(win, pps)
	string win
	STRUCT PostPlotSettings &pps

	string extPanel

	win      = GetMainWindow(win)
	extPanel = BSP_GetPanel(win)

	if(!PA_IsActive(win))
		InitPulseAverageSettings(pps.pulseAverSett)
		return 0
	endif

	pps.pulseAverSett.showIndividualTraces = GetCheckboxState(extPanel, "check_pulseAver_indTraces")
	pps.pulseAverSett.showAverageTrace     = GetCheckboxState(extPanel, "check_pulseAver_showAver")
	pps.pulseAverSett.multipleGraphs       = GetCheckboxState(extPanel, "check_pulseAver_multGraphs")
	pps.pulseAverSett.startingPulse        = GetSetVariable(extPanel, "setvar_pulseAver_startPulse")
	pps.pulseAverSett.endingPulse          = GetSetVariable(extPanel, "setvar_pulseAver_endPulse")
	pps.pulseAverSett.fallbackPulseLength  = GetSetVariable(extPanel, "setvar_pulseAver_fallbackLength")
	pps.pulseAverSett.regionSlider         = BSP_GetDDAQ(win)
	pps.pulseAverSett.zeroTraces           = GetCheckboxState(extPanel, "check_pulseAver_zeroTrac")

	PA_DeconvGatherSettings(win, pps.pulseAverSett.deconvolution)
End

/// @brief gather deconvolution settings from PA section in BSP
Function PA_DeconvGatherSettings(win, deconvolution)
	string win
	STRUCT PulseAverageDeconvSettings &deconvolution

	string bsPanel = BSP_GetPanel(win)

	deconvolution.enable = PA_DeconvolutionIsActive(win)
	deconvolution.smth   = GetSetVariable(bsPanel, "setvar_pulseAver_deconv_smth")
	deconvolution.tau    = GetSetVariable(bsPanel, "setvar_pulseAver_deconv_tau")
	deconvolution.range  = GetSetVariable(bsPanel, "setvar_pulseAver_deconv_range")
End

Function PA_ShowPulses(win, dfr, pa)
	string win
	DFREF dfr
	STRUCT PulseAverageSettings &pa

	string graph, preExistingGraphs
	string averageWaveName, convolutionWaveName, pulseTrace, channelTypeStr, str, traceList, traceFullPath
	variable numChannels, i, j, k, l, idx, numTraces, sweepNo, headstage, numPulsesTotal, numPulses
	variable first, numEntries, startingPulse, endingPulse, numGraphs, traceCount
	variable startingPulseSett, endingPulseSett, ret, pulseToPulseLength, numSweeps
	variable red, green, blue, channelNumber, region, channelType, numHeadstages, length
	variable numChannelTypeTraces, activeRegionCount, activeChanCount, totalOnsetDelay
	string listOfWaves, channelList, vertAxis, horizAxis, channelNumberStr
	string baseName, traceName
	string newlyCreatedGraphs = ""

	win = GetMainWindow(win)

	preExistingGraphs = PA_GetAverageGraphs()

	if(!PA_IsActive(win))
		KillWindows(preExistingGraphs)
		return NaN
	endif

	if(pa.startingPulse >= 0)
		startingPulseSett = pa.startingPulse
	endif

	if(pa.endingPulse >= 0)
		endingPulseSett = pa.endingPulse
	endif

	WAVE/T/Z traceData = PA_GetTraceInfos(win)

	if(!WaveExists(traceData)) // no traces
		KillWindows(preExistingGraphs)
		return NaN
	endif

	DFREF pulseAverageDFR = GetDevicePulseAverageFolder(dfr)

	// iterate over all channel types we want to have pulse averaging for
	for(i = 0; i < 2; i += 1)
		channelType    = i
		channelTypeStr = StringFromList(channelType, ITC_CHANNEL_NAMES)

		WAVE/Z indizesChannelType = FindIndizes(traceData, colLabel="channelType", str=channelTypeStr)
		WAVE/Z headstages         = PA_GetUniqueHeadstages(traceData, indizesChannelType)

		if(!WaveExists(headstages))
			continue
		endif

		numChannelTypeTraces = DimSize(indizesChannelType, ROWS)
		numHeadstages        = DimSize(headstages, ROWS)

		activeRegionCount = 0

		// iterate over all headstages, ignores duplicates from overlay sweeps
		for(j = 0; j < numHeadstages; j += 1)

			region = headstages[j]

			if(!IsFinite(region)) // duplicated headstages in traceData
				continue
			endif

			if(pa.regionSlider != -1 && pa.regionSlider != region) // unselected region in ddaq viewing mode
				continue
			endif

			WAVE/Z pulseStartTimes = PA_GetPulseStartTimes(traceData, j, region, channelTypeStr)

			if(!WaveExists(pulseStartTimes))
				printf "We tried to find pulse starting times but failed miserably. Trying the next headstage\r"
				continue
			endif

			activeRegionCount += 1
			activeChanCount    = 0
			channelList        = ""

			Make/FREE/T/N=(NUM_HEADSTAGES) wavesToAverage

			numPulsesTotal = DimSize(pulseStartTimes, ROWS)
			startingPulse  = max(0, startingPulseSett)
			endingPulse    = min(numPulsesTotal - 1, endingPulseSett)
			numPulses = endingPulse - startingPulse + 1

			pulseToPulseLength = PA_GetPulseToPulseLength(traceData, idx, region, pulseStartTimes, startingPulse, endingPulse, pa.fallbackPulseLength)

			Make/T/FREE/N=(GetNumberFromType(itcvar=channelType)) listOfWavesPerChannel = ""

			// we have the starting times for one channel type and headstage combination
			// iterate now over all channels of the same type and extract all
			// requested pulses for them
			for(k = 0; k < numChannelTypeTraces; k += 1)
				idx       = indizesChannelType[k]
				headstage = str2num(traceData[idx][%headstage])

				if(!IsFinite(headstage)) // ignore unassociated channels or duplicated headstages in traceData
					continue
				endif

				sweepNo              = str2num(traceData[idx][%sweepNumber])
				channelNumberStr     = traceData[idx][%channelNumber]
				channelNumber        = str2num(channelNumberStr)
				WAVE numericalValues = $traceData[idx][%numericalValues]

				if(WhichListItem(channelNumberStr, channelList) == -1)
					activeChanCount += 1
					channelList = AddListItem(channelNumberStr, channelList, ";", inf)
				endif

				DFREF singleSweepFolder = GetWavesDataFolderDFR($traceData[idx][%fullPath])
				ASSERT(DataFolderExistsDFR(singleSweepFolder), "Missing singleSweepFolder")
				WAVE wv = GetITCDataSingleColumnWave(singleSweepFolder, channelType, channelNumber)

				DFREF singlePulseFolder = GetSingleSweepFolder(pulseAverageDFR, sweepNo)

				totalOnsetDelay = GetTotalOnsetDelay(numericalValues, sweepNo)

				graph = PA_GetGraph(win, pa.multipleGraphs, channelTypeStr, channelNumber, region, activeRegionCount, activeChanCount)
				PA_GetAxes(pa.multipleGraphs, activeRegionCount, activeChanCount, vertAxis, horizAxis)

				if(WhichListItem(graph, newlyCreatedGraphs) == -1)
					RemoveTracesFromGraph(graph)
					SetWindow $graph, userData($PA_USERDATA_SPECIAL_TRACES) = ""
					newlyCreatedGraphs = AddListItem(graph, newlyCreatedGraphs, ";", inf)
				endif

				for(l = startingPulse; l <= endingPulse; l += 1)

					// ignore wave offset, as it is only used for display purposes
					// but use the totalOnsetDelay of this sweep
					first  = round((pulseStartTimes[l] + totalOnsetDelay) / DimDelta(wv, ROWS))
					length = round(pulseToPulseLength / DimDelta(wv, ROWS))

					WAVE/Z plotWave = PA_CreateAndFillPulseWaveIfReq(wv, singlePulseFolder, channelType, channelNumber, region, l, first, length)

					if(!WaveExists(plotWave))
						printf "Not adding pulse %d of region %d from sweep %d because it could not be extracted due to invalid coordinates.\r", l, region, sweepNo
						continue
					endif

					if(pa.showIndividualTraces)
						sprintf pulseTrace, "T%06d%s_IDX%d", traceCount, NameOfWave(plotWave), idx

						GetTraceColor(headstage, red, green, blue)
						AppendToGraph/Q/W=$graph/L=$vertAxis/B=$horizAxis/C=(red, green, blue, 65535 * 0.1) plotWave[0,inf;PA_PLOT_STEPPING]/TN=$pulseTrace
						traceCount += 1
					endif

					listOfWavesPerChannel[channelNumber] = AddListItem(GetWavesDataFolder(plotWave, 2), listOfWavesPerChannel[channelNumber], ";", inf)
				endfor
			endfor

			activeChanCount = 0
			channelList     = ""

			// handle graph legends and average calculation
			for(k = 0; k < numChannelTypeTraces; k += 1)

				idx       = indizesChannelType[k]
				headstage = str2num(traceData[idx][%headstage])

				if(!IsFinite(headstage)) // ignore unassociated channels or duplicated headstages in traceData
					continue
				endif

				sweepNo          = str2num(traceData[idx][%sweepNumber])
				channelNumberStr = traceData[idx][%channelNumber]
				channelNumber    = str2num(channelNumberStr)

				if(WhichListItem(channelNumberStr, channelList) == -1)
					activeChanCount += 1
					channelList = AddListItem(channelNumberStr, channelList, ";", inf)
				endif

				listOfWaves = listOfWavesPerChannel[channelNumber]
				numSweeps   = ItemsInList(listOfWaves) / numPulses

				graph = PA_GetGraph(win, pa.multipleGraphs, channelTypeStr, channelNumber, region, activeRegionCount, activeChanCount)
				PA_GetAxes(pa.multipleGraphs, activeRegionCount, activeChanCount, vertAxis, horizAxis)

				PA_ZeroTraces(listOfWaves, pa.zeroTraces)

				baseName = PA_BaseName(channelTypeStr, channelNumber, region)
				WAVE/Z averageWave = $""
				if(pa.showAverageTrace && !IsEmpty(listOfWaves))
					WAVE averageWave = PA_Average(listOfWaves, pulseAverageDFR, PA_AVERAGE_WAVE_PREFIX + baseName)

					GetTraceColor(NUM_HEADSTAGES + 1, red, green, blue)
					AppendToGraph/Q/W=$graph/L=$vertAxis/B=$horizAxis/C=(red, green, blue) averageWave[0,inf;PA_PLOT_STEPPING]
					SetWindow $graph, userData($PA_USERDATA_SPECIAL_TRACES) += NameOfWave(averageWave) + ";"

					listOfWavesPerChannel[channelNumber] = ""
				endif

				if(pa.deconvolution.enable && (activeRegionCount != activeChanCount) && !IsEmpty(listOfWaves))
					if(!WaveExists(averageWave))
						WAVE averageWave = PA_Average(listOfWaves, pulseAverageDFR, PA_AVERAGE_WAVE_PREFIX + baseName)
					endif
					traceName = PA_DECONVOLUTION_WAVE_PREFIX + baseName
					WAVE deconv = PA_Deconvolution(averageWave, pulseAverageDFR, traceName, pa.deconvolution)

					AppendToGraph/Q/W=$graph/L=$vertAxis/B=$horizAxis/C=(0,0,0) deconv[0,inf;PA_PLOT_STEPPING]/TN=$traceName
					ModifyGraph/W=$graph lsize($traceName)=2

					SetAxis/Z/W=$graph $horizAxis 0, pa.deconvolution.range
					SetWindow $graph, userData($PA_USERDATA_SPECIAL_TRACES) += NameOfWave(deconv) + ";"
				endif

				if(pa.multipleGraphs)
					sprintf str, "\\Z08\\Zr075#Pulses %g / #Swps. %d", numPulses, numSweeps
					Legend/W=$graph/C/N=leg/X=-5.00/Y=-5.00 str

					GetTraceColor(headstage, red, green, blue)
					sprintf str, "\\k(%d, %d, %d)\\K(%d, %d, %d)\\W555\\k(0, 0, 0)\\K(0, 0, 0)", red, green, blue, red, green, blue

					sprintf str, "%s%d / Reg. %d HS%s", channelTypeStr, channelNumber, region, str
					AppendText/W=$graph str
				endif

				ModifyGraph/W=$graph nticks=0, noLabel=2, axthick=0, margin=5
			endfor // channels

			if(!pa.multipleGraphs)
				EquallySpaceAxis(graph, axisRegExp="left_R" + num2str(activeRegionCount) + ".*", sortOrder=1)
				EquallySpaceAxis(graph, axisRegExp="bottom.*", sortOrder=0)
			endif

			ModifyGraph/W=$graph mode=0
		endfor // headstages
	endfor // channelType

	// kill all graphs from earlier runs which were not created anymore
	numGraphs = ItemsInList(preExistingGraphs)
	for(i = 0; i < numGraphs; i += 1)
		graph = StringFromList(i, preExistingGraphs)
		if(WhichListItem(graph, newlyCreatedGraphs) == -1)
			KillWindow/Z $graph
		endif
	endfor
End

/// @brief Generate a static base name for objects in the current averaging folder
static Function/S PA_BaseName(channelTypeStr, channelNumber, headStage)
	string channelTypeStr
	variable channelNumber, headStage

	string baseName
	baseName = channelTypeStr + num2str(channelNumber)
	baseName += "_HS" + num2str(headStage)

	return baseName
End

/// @brief Zero pulse averaging traces using @c ZeroWave
///
/// This function has to be the first function to call before altering waves
/// from listofWaves.
///
/// @param listOfWaves   a list with full wave paths where to apply zeroing
/// @param setZero       add/remove zeroing from the wave
static Function PA_ZeroTraces(listOfWaves, setZero)
	string listOfWaves
	variable setZero

	variable i, numWaves

	if(IsEmpty(listOfWaves))
		return NaN
	endif
	setZero = !!setZero

	numWaves = ItemsInList(listOfWaves)
	for(i = 0; i < numWaves; i += 1)
		WAVE wv = $StringFromList(i, listOfWaves)
		if(setZero)
			ZeroWave(wv)
		else
			ReplaceWaveWithBackup(wv, nonExistingBackupIsFatal = 0)
		endif
	endfor
End

/// @brief calculate the average wave from a @p listOfWaves
///
/// Note: MIES_fWaveAverage() usually takes 5 times longer than CA_AveragingKey()
///
/// @returns wave reference to the average wave specified by @p outputDFR and @p outputWaveName
Function/WAVE PA_Average(listOfWaves, outputDFR, outputWaveName)
	string listOfWaves
	DFREF outputDFR
	string outputWaveName

	WAVE wv = CalculateAverage(listOfWaves, outputDFR, outputWaveName, skipCRC = 1)

	return wv
End

Function/WAVE PA_SmoothDeconv(input, deconvolution)
	WAVE input
	STRUCT PulseAverageDeconvSettings &deconvolution

	variable range_pnts, smoothingFactor
	string key

	range_pnts = deconvolution.range / DimDelta(input, ROWS)
	smoothingFactor = max(min(deconvolution.smth, 32767), 1)

	key = CA_SmoothDeconv(input, smoothingFactor, range_pnts)
	WAVE/Z cache = CA_TryFetchingEntryFromCache(key, options = CA_OPTS_NO_DUPLICATE)
	if(WaveExists(cache))
		return cache
	endif

	Duplicate/FREE/R=[0, range_pnts] input wv
	Smooth smoothingFactor, wv

	CA_StoreEntryIntoCache(key, wv)
	return wv
End

Function/WAVE PA_Deconvolution(average, outputDFR, outputWaveName, deconvolution)
	WAVE average
	DFREF outputDFR
	string outputWaveName
	STRUCT PulseAverageDeconvSettings &deconvolution

	variable step
	string key

	WAVE smoothed = PA_SmoothDeconv(average, deconvolution)

	key = CA_Deconv(smoothed, deconvolution.tau)
	WAVE/Z cache = CA_TryFetchingEntryFromCache(key, options = CA_OPTS_NO_DUPLICATE)
	if(WaveExists(cache))
		Duplicate/O cache outputDFR:$outputWaveName/WAVE=wv
		return wv
	endif

	Duplicate/O/R=[0, DimSize(smoothed, ROWS) - 2] smoothed outputDFR:$outputWaveName/WAVE=wv
	step = deconvolution.tau / DimDelta(average, 0)
	MultiThread wv = step * (smoothed[p + 1] - smoothed[p]) + smoothed[p]

	CA_StoreEntryIntoCache(key, wv)
	return wv
End

Function PA_CheckProc_Common(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch(cba.eventCode)
		case 2: // mouse up
			UpdateSweepPlot(cba.win)
			break
	endswitch

	return 0
End

Function PA_CheckProc_Average(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch(cba.eventCode)
		case 2: // mouse up
			BSP_SetDeconvControlStatus(cba.win)
			UpdateSweepPlot(cba.win)
			break
	endswitch

	return 0
End

Function PA_CheckProc_Deconvolution(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			BSP_SetDeconvControlStatus(cba.win)
			PA_UpdateSweepPlotDeconvolution(cba.win, cba.checked)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function PA_SetVarProc_Common(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch(sva.eventCode)
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			UpdateSweepPlot(sva.win)
			break
	endswitch

	return 0
End

/// @brief checks if PA is active.
Function PA_IsActive(win)
	string win

	return BSP_IsActive(win, MIES_BSP_PA)
End

/// @brief checks if "show average trace" in PA is activated.
Function PA_AverageIsActive(win)
	string win

	string bsPanel

	if(!PA_IsActive(win))
		return 0
	endif

	bsPanel = BSP_GetPanel(win)
	return GetCheckboxState(bsPanel, "check_pulseAver_showAver")
End

/// @brief checks if "show average trace" in PA is activated.
Function PA_DeconvolutionIsActive(win)
	string win

	string bsPanel

	if(!PA_AverageIsActive(win))
		return 0
	endif

	bsPanel = BSP_GetPanel(win)
	return GetCheckboxState(bsPanel, "check_pulseAver_deconv")
End

/// @brief Update deconvolution traces in Sweep Plots
Function PA_UpdateSweepPlotDeconvolution(win, show)
	string win
	variable show

	string graph, graphs, horizAxis, vertAxis, axisFlags
	string traceList, traceListOut, traceName, traceMatch, traceInformation
	string baseName, bsPanel
	variable i, numGraphs, multipleGraphs, j, numTraces, numDiagonalElements
	STRUCT PulseAverageDeconvSettings deconvolution

	win = GetMainWindow(win)
	if(!PA_IsActive(win))
		return 0
	endif

	bsPanel = BSP_GetPanel(win)
	PA_DeconvGatherSettings(bsPanel, deconvolution)

	if(!!show)
		traceMatch = PA_AVERAGE_WAVE_PREFIX
	else
		traceMatch = PA_DECONVOLUTION_WAVE_PREFIX
	endif

	multipleGraphs = GetCheckboxState(bsPanel, "check_pulseAver_multGraphs")
	if(multipleGraphs)
		graphs = PA_GetAverageGraphs()
		numGraphs = ItemsInList(graphs)
	else
		graphs = AddListItem(PULSE_AVERAGE_GRAPH_PREFIX, "")
		numGraphs = 1
	endif

	for(i = 0; i < numGraphs; i += 1)
		graph = StringFromList(i, graphs)

		traceList = GetUserData(graph, "", PA_USERDATA_SPECIAL_TRACES)
		traceListOut = traceList
		ASSERT(ItemsInList(traceList) > 0, "UserData empty. No average Traces? You could call TraceNameList to check.")
		traceList = ListMatch(traceList, traceMatch + "*")

		numTraces = ItemsInList(traceList)
		if(show)
			numDiagonalElements = round(sqrt(numTraces)) // assume square matrix
		endif
		for(j = 0; j < numTraces; j += 1)
			traceName = StringFromList(j, traceList)

			traceInformation = TraceInfo(graph, traceName, 0)
			vertAxis  = StringByKey("YAXIS", traceInformation)
			horizAxis = StringByKey("XAXIS", traceInformation)
			axisFlags = StringByKey("AXISFLAGS", traceInformation)
			if(!IsEmpty(axisFlags))
				ASSERT(StringMatch(axisFlags, "*/B*"), "Axis not handled.")
				ASSERT(StringMatch(axisFlags, "*/L*"), "Axis not handled.")
			endif

			if(!show)
				RemoveFromGraph/W=$graph $traceName
				SetAxis/Z/W=$graph $horizAxis 0, *
				traceListOut = RemoveFromList(traceName, traceListOut)
				continue
			endif

			// skip diagonal elements
			if(mod(j, numDiagonalElements) == floor(j / numDiagonalElements))
				continue
			endif

			WAVE averageWave = TraceNameToWaveRef(graph, traceName)
			DFREF pulseAverageDFR = GetWavesDataFolderDFR(averageWave)

			SplitString/E=(traceMatch + "(.*)") NameOfWave(averageWave), baseName
			ASSERT(V_flag == 1, "Unexpected Trace Name")

			traceName = PA_DECONVOLUTION_WAVE_PREFIX + baseName
			ASSERT(WhichListItem(traceName, traceList) == -1, "Unexpected Behavior: Trace already in graph.")
			WAVE deconv = PA_Deconvolution(averageWave, pulseAverageDFR, traceName, deconvolution)

			AppendToGraph/Q/W=$graph/L=$vertAxis/B=$horizAxis/C=(0,0,0) deconv/TN=$traceName
			ModifyGraph/W=$graph lsize($traceName)=2
			SetAxis/Z/W=$graph $horizAxis 0, deconvolution.range

			traceListOut = AddListItem(NameOfWave(deconv), traceListOut)
		endfor

		SetWindow $graph, userData($PA_USERDATA_SPECIAL_TRACES) = traceListOut
	endfor
End
