#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3 // Use modern global access method and strict wave access.
#pragma rtFunctionErrors=1

#ifdef AUTOMATED_TESTING
#pragma ModuleName=MIES_SF
#endif

// to enable debug mode with more persistent data
// #define SWEEPFORMULA_DEBUG

/// @file MIES_SweepFormula.ipf
///
/// @brief __SF__ Sweep formula allows to do analysis on sweeps with a
/// dedicated formula language

static Constant SF_STATE_UNINITIALIZED = -1
static Constant SF_STATE_COLLECT = 1
static Constant SF_STATE_ADDITION = 2
static Constant SF_STATE_SUBTRACTION = 3
static Constant SF_STATE_MULTIPLICATION = 4
static Constant SF_STATE_PARENTHESIS = 6
static Constant SF_STATE_FUNCTION = 7
static Constant SF_STATE_ARRAY = 8
static Constant SF_STATE_ARRAYELEMENT = 9
static Constant SF_STATE_WHITESPACE = 10
static Constant SF_STATE_NEWLINE = 12
static Constant SF_STATE_OPERATION = 13
static Constant SF_STATE_STRING = 14
static Constant SF_STATE_STRINGTERMINATOR = 15

static Constant SF_ACTION_UNINITIALIZED = -1
static Constant SF_ACTION_SKIP = 0
static Constant SF_ACTION_COLLECT = 1
static Constant SF_ACTION_CALCULATION = 2
static Constant SF_ACTION_SAMECALCULATION = 3
static Constant SF_ACTION_HIGHERORDER = 4
static Constant SF_ACTION_ARRAYELEMENT = 5
static Constant SF_ACTION_PARENTHESIS = 6
static Constant SF_ACTION_FUNCTION = 7
static Constant SF_ACTION_ARRAY = 8

/// Regular expression which extracts both formulas from `$a vs $b`
static StrConstant SF_SWEEPFORMULA_REGEXP = "^(.+?)(?:\\bvs\\b(.+))?$"
/// Regular expression which extracts formulas pairs from `$a vs $b\rand\r$c vs $d\rand\r...`
static StrConstant SF_SWEEPFORMULA_GRAPHS_REGEXP = "^(.+?)(?:\\r[ \t]*and[ \t]*\\r(.*))?$"
/// Regular expression which extracts y-formulas from `$a\rwith\r$b\rwith\r$c\r...`
static StrConstant SF_SWEEPFORMULA_WITH_REGEXP = "^(.+?)(?:\\r[ \t]*with[ \t]*\\r(.*))?$"

static Constant SF_MAX_NUMPOINTS_FOR_MARKERS = 1000

static Constant SF_APFREQUENCY_FULL          = 0x0
static Constant SF_APFREQUENCY_INSTANTANEOUS = 0x1
static Constant SF_APFREQUENCY_APCOUNT       = 0x2

static StrConstant SF_OP_MINUS = "-"
static StrConstant SF_OP_PLUS = "+"
static StrConstant SF_OP_MULT = "*"
static StrConstant SF_OP_DIV = "~1"
static StrConstant SF_OP_RANGE = "range"
static StrConstant SF_OP_RANGESHORT = "…"
static StrConstant SF_OP_MIN = "min"
static StrConstant SF_OP_MAX = "max"
static StrConstant SF_OP_AVG = "avg"
static StrConstant SF_OP_MEAN = "mean"
static StrConstant SF_OP_RMS = "rms"
static StrConstant SF_OP_VARIANCE = "variance"
static StrConstant SF_OP_STDEV = "stdev"
static StrConstant SF_OP_DERIVATIVE = "derivative"
static StrConstant SF_OP_INTEGRATE = "integrate"
static StrConstant SF_OP_TIME = "time"
static StrConstant SF_OP_XVALUES = "xvalues"
static StrConstant SF_OP_TEXT = "text"
static StrConstant SF_OP_LOG = "log"
static StrConstant SF_OP_LOG10 = "log10"
static StrConstant SF_OP_APFREQUENCY = "apfrequency"
static StrConstant SF_OP_CURSORS = "cursors"
static StrConstant SF_OP_SWEEPS = "sweeps"
static StrConstant SF_OP_AREA = "area"
static StrConstant SF_OP_SETSCALE = "setscale"
static StrConstant SF_OP_BUTTERWORTH = "butterworth"
static StrConstant SF_OP_CHANNELS = "channels"
static StrConstant SF_OP_DATA = "data"
static StrConstant SF_OP_LABNOTEBOOK = "labnotebook"
static StrConstant SF_OP_WAVE = "wave"
static StrConstant SF_OP_FINDLEVEL = "findlevel"
static StrConstant SF_OP_EPOCHS = "epochs"
static StrConstant SF_OP_TP = "tp"
static StrConstant SF_OP_STORE = "store"
static StrConstant SF_OP_SELECT = "select"
static StrConstant SF_OP_POWERSPECTRUM = "powerspectrum"
static StrConstant SF_OP_TPSS = "tpss"
static StrConstant SF_OP_TPINST = "tpinst"
static StrConstant SF_OP_TPBASE = "tpbase"
static StrConstant SF_OP_TPFIT = "tpfit"

static StrConstant SF_OPSHORT_MINUS = "minus"
static StrConstant SF_OPSHORT_PLUS = "plus"
static StrConstant SF_OPSHORT_MULT = "mult"
static StrConstant SF_OPSHORT_DIV = "div"

static StrConstant SF_OP_EPOCHS_TYPE_RANGE = "range"
static StrConstant SF_OP_EPOCHS_TYPE_NAME = "name"
static StrConstant SF_OP_EPOCHS_TYPE_TREELEVEL = "treelevel"
static StrConstant SF_OP_TP_TYPE_BASELINE = "base"
static StrConstant SF_OP_TP_TYPE_INSTANT = "inst"
static StrConstant SF_OP_TP_TYPE_STATIC = "ss"
static StrConstant SF_OP_SELECT_CLAMPMODE_ALL = "all"
static StrConstant SF_OP_SELECT_CLAMPMODE_IC = "ic"
static StrConstant SF_OP_SELECT_CLAMPMODE_VC = "vc"
static StrConstant SF_OP_SELECT_CLAMPMODE_IZERO = "izero"
static Constant SF_OP_SELECT_CLAMPCODE_ALL = -1

static StrConstant SF_OP_TPFIT_FUNC_EXP = "exp"
static StrConstant SF_OP_TPFIT_FUNC_DEXP = "doubleexp"
static StrConstant SF_OP_TPFIT_RET_TAULARGE = "tau"
static StrConstant SF_OP_TPFIT_RET_TAUSMALL = "tausmall"
static StrConstant SF_OP_TPFIT_RET_AMP = "amp"
static StrConstant SF_OP_TPFIT_RET_MINAMP = "minabsamp"
static StrConstant SF_OP_TPFIT_RET_FITQUALITY = "fitq"

static Constant EPOCHS_TYPE_INVALID = -1
static Constant EPOCHS_TYPE_RANGE = 0
static Constant EPOCHS_TYPE_NAME = 1
static Constant EPOCHS_TYPE_TREELEVEL = 2

static StrConstant SF_CHAR_COMMENT = "#"
static StrConstant SF_CHAR_CR = "\r"
static StrConstant SF_CHAR_NEWLINE = "\n"

static Constant SF_TRANSFER_ALL_DIMS = -1

static StrConstant SF_WORKING_DF = "FormulaData"
static StrConstant SF_WREF_MARKER = "\"WREF@\":"

static StrConstant SF_PLOTTER_GUIDENAME = "HOR"

static StrConstant SF_XLABEL_USER = ""

static Constant SF_MSG_OK = 1
static Constant SF_MSG_ERROR = 0
static Constant SF_MSG_WARN = -1

static Constant SF_NUMTRACES_ERROR_THRESHOLD = 10000
static Constant SF_NUMTRACES_WARN_THRESHOLD = 1000

static StrConstant SF_AVERAGING_NONSWEEPDATA_LBL = "NOSWEEPDATA"

static StrConstant SF_POWERSPECTRUM_UNIT_DEFAULT = "default"
static StrConstant SF_POWERSPECTRUM_UNIT_DB = "db"
static StrConstant SF_POWERSPECTRUM_UNIT_NORMALIZED = "normalized"
static StrConstant SF_POWERSPECTRUM_AVG_ON = "avg"
static StrConstant SF_POWERSPECTRUM_AVG_OFF = "noavg"
static StrConstant SF_POWERSPECTRUM_WINFUNC_NONE = "none"
static Constant SF_POWERSPECTRUM_RATIO_DELTAHZ = 10
static Constant SF_POWERSPECTRUM_RATIO_EPSILONHZ = 0.25
static Constant SF_POWERSPECTRUM_RATIO_EPSILONPOSFIT = 1E-3
static Constant SF_POWERSPECTRUM_RATIO_MAXFWHM = 5
static Constant SF_POWERSPECTRUM_RATIO_GAUSS_SIGMA2FWHM = 2.35482004503
static Constant SF_POWERSPECTRUM_RATIO_GAUSS_NUMCOEFS = 4

static StrConstant SF_USER_DATA_BROWSER = "browser"

Menu "GraphPopup"
	"Bring browser to front", /Q, SF_BringBrowserToFront()
End

Function SF_BringBrowserToFront()
	string browser, graph

	graph = GetMainWindow(GetCurrentWindow())
	browser = SF_GetBrowserForFormulaGraph(graph)

	if(IsEmpty(browser))
		print "This menu option only applies to SweepFormula plots."
		return NaN
	elseif(!WindowExists(browser))
		printf "The browser %s does not exist anymore.\r", browser
		return NaN
	endif

	DoWindow/F $browser
End

/// @brief Return the SweepBrowser/DataBrowser from which the given
///        SweepFormula plot window originated from
static Function/S SF_GetBrowserForFormulaGraph(string win)

	return GetUserData(win, "", SF_USER_DATA_BROWSER)
End

Function/WAVE SF_GetNamedOperations()

	Make/FREE/T wt = {SF_OP_RANGE, SF_OP_MIN, SF_OP_MAX, SF_OP_AVG, SF_OP_MEAN, SF_OP_RMS, SF_OP_VARIANCE, SF_OP_STDEV, \
					  SF_OP_DERIVATIVE, SF_OP_INTEGRATE, SF_OP_TIME, SF_OP_XVALUES, SF_OP_TEXT, SF_OP_LOG, \
					  SF_OP_LOG10, SF_OP_APFREQUENCY, SF_OP_CURSORS, SF_OP_SWEEPS, SF_OP_AREA, SF_OP_SETSCALE, SF_OP_BUTTERWORTH, \
					  SF_OP_CHANNELS, SF_OP_DATA, SF_OP_LABNOTEBOOK, SF_OP_WAVE, SF_OP_FINDLEVEL, SF_OP_EPOCHS, SF_OP_TP, \
					  SF_OP_STORE, SF_OP_SELECT, SF_OP_POWERSPECTRUM, SF_OP_TPSS, SF_OP_TPBASE, SF_OP_TPINST, SF_OP_TPFIT}

	return wt
End

Function/WAVE SF_GetFormulaKeywords()

	// see also SF_SWEEPFORMULA_REGEXP and SF_SWEEPFORMULA_GRAPHS_REGEXP
	Make/FREE/T wt = {"vs", "and", "with"}

	return wt
End

static Function/S SF_StringifyState(variable state)

	switch(state)
		case SF_STATE_COLLECT:
			return "SF_STATE_COLLECT"
		case SF_STATE_ADDITION:
			return "SF_STATE_ADDITION"
		case SF_STATE_SUBTRACTION:
			return "SF_STATE_SUBTRACTION"
		case SF_STATE_MULTIPLICATION:
			return "SF_STATE_MULTIPLICATION"
		case SF_STATE_PARENTHESIS:
			return "SF_STATE_PARENTHESIS"
		case SF_STATE_FUNCTION:
			return "SF_STATE_FUNCTION"
		case SF_STATE_ARRAY:
			return "SF_STATE_ARRAY"
		case SF_STATE_ARRAYELEMENT:
			return "SF_STATE_ARRAYELEMENT"
		case SF_STATE_WHITESPACE:
			return "SF_STATE_WHITESPACE"
		case SF_STATE_NEWLINE:
			return "SF_STATE_NEWLINE"
		case SF_STATE_OPERATION:
			return "SF_STATE_OPERATION"
		case SF_STATE_STRING:
			return "SF_STATE_STRING"
		case SF_STATE_STRINGTERMINATOR:
			return "SF_STATE_STRINGTERMINATOR"
		case SF_STATE_UNINITIALIZED:
			return "SF_STATE_UNINITIALIZED"
		default:
			ASSERT(0, "unknown state")
	endswitch
End

static Function/S SF_StringifyAction(variable action)

	switch(action)
		case SF_ACTION_SKIP:
			return "SF_ACTION_SKIP"
		case SF_ACTION_COLLECT:
			return "SF_ACTION_COLLECT"
		case SF_ACTION_CALCULATION:
			return "SF_ACTION_CALCULATION"
		case SF_ACTION_SAMECALCULATION:
			return "SF_ACTION_SAMECALCULATION"
		case SF_ACTION_HIGHERORDER:
			return "SF_ACTION_HIGHERORDER"
		case SF_ACTION_ARRAYELEMENT:
			return "SF_ACTION_ARRAYELEMENT"
		case SF_ACTION_PARENTHESIS:
			return "SF_ACTION_PARENTHESIS"
		case SF_ACTION_FUNCTION:
			return "SF_ACTION_FUNCTION"
		case SF_ACTION_ARRAY:
			return "SF_ACTION_ARRAY"
		case SF_ACTION_UNINITIALIZED:
			return "SF_ACTION_UNINITIALIZED"
		default:
			ASSERT(0, "Unknown action")
	endswitch
End

/// @brief Assertion for sweep formula
///
/// This assertion does *not* indicate a genearl programmer error but a
/// sweep formula user error.
///
/// All programmer error checks must still use ASSERT().
static Function SF_Assert(variable condition, string message[, variable jsonId])

	if(!condition)
		if(!ParamIsDefault(jsonId))
			JSON_Release(jsonId, ignoreErr=1)
		endif
		SVAR error = $GetSweepFormulaParseErrorMessage()
		error = message
#ifdef AUTOMATED_TESTING_DEBUGGING
		Debugger
#endif
		Abort
	endif
End

/// @brief preparse user input to correct formula patterns
///
/// @return parsed formula
static Function/S SF_FormulaPreParser(string formula)

	SF_Assert(CountSubstrings(formula, "(") == CountSubstrings(formula, ")"), "Bracket mismatch in formula.")
	SF_Assert(CountSubstrings(formula, "[") == CountSubstrings(formula, "]"), "Array bracket mismatch in formula.")
	SF_Assert(!mod(CountSubstrings(formula, "\""), 2), "Quotation marks mismatch in formula.")

	formula = ReplaceString("...", formula, "…")

	return formula
End

static Function SF_IsStateGathering(variable state)

	return state == SF_STATE_COLLECT || state == SF_STATE_WHITESPACE || state == SF_STATE_NEWLINE
End

static Function SF_IsActionComplex(variable action)

	return action == SF_ACTION_PARENTHESIS|| action == SF_ACTION_FUNCTION || action == SF_ACTION_ARRAY
End

/// @brief serialize a string formula into JSON
///
/// @param formula  string formula
/// @param createdArray [optional, default 0] set on recursive calls, returns boolean if parser created a JSON array
/// @param indentLevel [internal use only] recursive call level, used for debug output
/// @returns a JSONid representation
static Function SF_FormulaParser(string formula, [variable &createdArray, variable indentLevel])

	variable i, parenthesisStart, parenthesisEnd, jsonIDdummy, jsonIDarray, subId
	variable formulaLength, bufferOffset
	string tempPath
	string indentation = ""
	variable action = SF_ACTION_UNINITIALIZED
	string token = ""
	string buffer = ""
	variable state = SF_STATE_UNINITIALIZED
	variable lastState = SF_STATE_UNINITIALIZED
	variable lastCalculation = SF_STATE_UNINITIALIZED
	variable level = 0
	variable arrayLevel = 0
	variable createdArrayLocal, wasArrayCreated
	variable lastAction = SF_ACTION_UNINITIALIZED

	variable jsonID = JSON_New()
	string jsonPath = ""

#ifdef DEBUGGING_ENABLED
	for(i = 0; i < indentLevel; i += 1)
		indentation += "-> "
	endfor

	if(DP_DebuggingEnabledForCaller())
		printf "%sformula %s\r", indentation, formula
	endif
#endif

	formulaLength = strlen(formula)

	if(formulaLength == 0)
		return jsonID
	endif

	for(i = 0; i < formulaLength; i += 1)
		token += formula[i]

		// state
		strswitch(token)
			case "/":
				state = SF_STATE_OPERATION
				break
			case "*":
				state = SF_STATE_MULTIPLICATION
				break
			case "-":
				state = SF_STATE_SUBTRACTION
				break
			case "+":
				state = SF_STATE_ADDITION
				break
			case "…":
				state = SF_STATE_OPERATION
				break
			case "(":
				level += 1
				break
			case ")":
				level -= 1
				if(GrepString(buffer, "^(?i)[+-]?\\([\s\S]*$"))
					state = SF_STATE_PARENTHESIS
					break
				endif
				if(GrepString(buffer, "^[A-Za-z]"))
					state = SF_STATE_FUNCTION
					break
				endif
				state = SF_STATE_COLLECT
				break
			case "[":
				arrayLevel += 1
				break
			case "]":
				arrayLevel -= 1
				state = SF_STATE_ARRAY
				break
			case ",":
				state = SF_STATE_ARRAYELEMENT
				break
			case "\"":
				state = SF_STATE_STRINGTERMINATOR
				break
			case "\r":
				state = SF_STATE_NEWLINE
				break
			case " ":
			case "\t":
				state = SF_STATE_WHITESPACE
				break
			default:
				if(!(char2num(token) > 0))
					continue
				endif
				state = SF_STATE_COLLECT
				SF_Assert(GrepString(token, "[A-Za-z0-9_\.:;=]"), "undefined pattern in formula: " + formula[i, i + 5], jsonId=jsonId)
		endswitch

		if(level > 0 || arrayLevel > 0)
			// transfer sub level "as is" to buffer
			state = SF_STATE_COLLECT
		endif

#ifdef DEBUGGING_ENABLED
		if(DP_DebuggingEnabledForCaller())
			printf "%stoken %s, state %s, lastCalculation %s, ", indentation, token, PadString(SF_StringifyState(state), 25, 0x20),  PadString(SF_StringifyState(lastCalculation), 25, 0x20)
		endif
#endif

		SF_ASSERT(!(lastState == SF_STATE_ARRAYELEMENT && state == SF_STATE_ARRAYELEMENT), "Found , following a ,")
		// state transition
		if(lastState == SF_STATE_STRING && state != SF_STATE_STRINGTERMINATOR)
			// collect between quotation marks
			action = SF_ACTION_COLLECT
		elseif(lastState == SF_STATE_SUBTRACTION && state == SF_STATE_SUBTRACTION)
			// if we just did a substraction and the next char is another - then it must be a sign
			action = SF_ACTION_COLLECT
		elseif(lastState == SF_STATE_ADDITION && state == SF_STATE_ADDITION)
			// if we just did a addition and the next char is another + then it must be a sign
			action = SF_ACTION_COLLECT
		elseif(state != lastState)
			switch(state)
				// priority ladder of calculations: +, -, *, /
				case SF_STATE_ADDITION:
					if(lastCalculation == SF_STATE_SUBTRACTION)
						action = SF_ACTION_HIGHERORDER
						break
					endif
				case SF_STATE_SUBTRACTION:
					// if we initially start with a (- or +) or we are not after a ")", "]" or function or were not already collecting chars
					// then it the - or + must be a sign of a number. (The sign char must be the first when we start collecting)
					if(lastState == SF_STATE_UNINITIALIZED || !(SF_IsStateGathering(lastState) || SF_IsActionComplex(lastAction)))
						action = SF_ACTION_COLLECT
						break
					endif
					if(lastCalculation == SF_STATE_MULTIPLICATION)
						action = SF_ACTION_HIGHERORDER
						break
					endif
				case SF_STATE_MULTIPLICATION:
					if(lastCalculation == SF_STATE_OPERATION)
						action = SF_ACTION_HIGHERORDER
						break
					endif
				case SF_STATE_OPERATION:
					if(IsEmpty(buffer))
						action = SF_ACTION_HIGHERORDER
						break
					endif
					action = SF_ACTION_CALCULATION
					if(state == lastCalculation)
						action = SF_ACTION_SAMECALCULATION
					endif
					if(lastCalculation == SF_STATE_ARRAYELEMENT)
						action = SF_ACTION_COLLECT
					endif
					break

				case SF_STATE_PARENTHESIS:
					action = SF_ACTION_PARENTHESIS
					if(lastCalculation == SF_STATE_ARRAYELEMENT)
						action = SF_ACTION_COLLECT
					endif
					break
				case SF_STATE_FUNCTION:
					action = SF_ACTION_FUNCTION
					if(lastCalculation == SF_STATE_ARRAYELEMENT)
						action = SF_ACTION_COLLECT
					endif
					break
				case SF_STATE_ARRAYELEMENT:
					SF_ASSERT(lastState != SF_STATE_UNINITIALIZED, "No value before ,")
					action = SF_ACTION_ARRAYELEMENT
					if(lastCalculation != SF_STATE_ARRAYELEMENT)
						action = SF_ACTION_HIGHERORDER
					endif
					break
				case SF_STATE_ARRAY:
					action = SF_ACTION_ARRAY
					break
				case SF_STATE_NEWLINE:
				case SF_STATE_WHITESPACE:
					action = SF_ACTION_SKIP
					break
				case SF_STATE_COLLECT:
					action = SF_ACTION_COLLECT
					break
				case SF_STATE_STRINGTERMINATOR:
					if(lastState != SF_STATE_STRING)
						state = SF_STATE_STRING
					endif
					action = SF_ACTION_COLLECT
					break
				default:
					SF_Assert(0, "Encountered undefined transition " + num2istr(state), jsonId=jsonId)
			endswitch
			lastState = state
		endif

#ifdef DEBUGGING_ENABLED
		if(DP_DebuggingEnabledForCaller())
			printf "action %s, lastState %s\r", PadString(SF_StringifyAction(action), 25, 0x20), PadString(SF_StringifyState(lastState), 25, 0x20)
		endif
#endif

		// Checks for simple syntax dependencies
		if(action != SF_ACTION_SKIP)
			switch(lastAction)
				case SF_ACTION_ARRAY:
					// If the last action was the handling of "]" from an array
					SF_ASSERT(action == SF_ACTION_ARRAYELEMENT || action == SF_ACTION_HIGHERORDER, "Expected \",\" after \"]\"")
					break
				default:
					break
			endswitch
		endif

		// action
		switch(action)
			case SF_ACTION_COLLECT:
				buffer += token
			case SF_ACTION_SKIP:
				token = ""
				continue
			case SF_ACTION_FUNCTION:
				tempPath = jsonPath
				if(JSON_GetType(jsonID, jsonPath) == JSON_ARRAY)
					JSON_AddObjects(jsonID, jsonPath)
					tempPath += "/" + num2istr(JSON_GetArraySize(jsonID, jsonPath) - 1)
				endif
				tempPath += "/"
				parenthesisStart = strsearch(buffer, "(", 0, 0)
				tempPath += SF_EscapeJsonPath(buffer[0, parenthesisStart - 1])
				subId = SF_FormulaParser(buffer[parenthesisStart + 1, inf], createdArray=wasArrayCreated, indentLevel = indentLevel + 1)
				SF_FPAddArray(jsonId, tempPath, subId, wasArrayCreated)
				break
			case SF_ACTION_PARENTHESIS:
				if(!CmpStr(buffer[0], "-"))
					JSON_AddJSON(jsonID, jsonPath, SF_FormulaParser("*-1", indentLevel = indentLevel + 1))
					if(JSON_GetType(jsonID, jsonPath) == JSON_ARRAY)
						jsonPath += "/1/*"
					else
						jsonPath += "/*"
					endif
				endif
				bufferOffset = !CmpStr(buffer[0], "+") || !CmpStr(buffer[0], "-") ? 2 : 1
				JSON_AddJSON(jsonID, jsonPath, SF_FormulaParser(buffer[bufferOffset, inf], indentLevel = indentLevel + 1))
				break
			case SF_ACTION_HIGHERORDER:
				// - called if for the first time a "," is encountered (from SF_STATE_ARRAYELEMENT)
				// - called if a higher priority calculation, e.g. * over + requires to put array in sub json path
				lastCalculation = state
				if(state == SF_STATE_ARRAYELEMENT)
					SF_ASSERT(!(IsEmpty(buffer) && (lastAction == SF_ACTION_COLLECT || lastAction == SF_ACTION_SKIP || lastAction == SF_ACTION_UNINITIALIZED)), "array element has no value")
				endif
				if(!IsEmpty(buffer))
					JSON_AddJSON(jsonID, jsonPath, SF_FormulaParser(buffer, indentLevel = indentLevel + 1))
				endif
				jsonPath = SF_EscapeJsonPath(token)
				if(!cmpstr(jsonPath, ",") || !cmpstr(jsonPath, "]"))
					jsonPath = ""
				endif
				jsonId = SF_FPPutInArrayAtPath(jsonID, jsonPath)
				createdArrayLocal = 1
				break
			case SF_ACTION_ARRAY:
				// - buffer has collected chars between "[" and "]"(where "]" is not included in the buffer here)
				// - Parse recursively the inner part of the brackets
				// - return if the parsing of the inner part created implicitly in the JSON brackets or not
				// If there was no array created, we have to add another outer array around the returned json
				// An array needs to be also added if the returned json is a simple value as this action requires
				// to return an array.
				SF_Assert(!cmpstr(buffer[0], "["), "Can not find array start. (Is there a \",\" before \"[\" missing?)", jsonId=jsonId)
				subId = SF_FormulaParser(buffer[1, inf], createdArray=wasArrayCreated, indentLevel = indentLevel + 1)
				SF_FPAddArray(jsonId, jsonPath, subId, wasArrayCreated)
				break
			case SF_ACTION_CALCULATION:
				if(JSON_GetType(jsonID, jsonPath) == JSON_ARRAY)
					JSON_AddObjects(jsonID, jsonPath) // prepare for decent
					jsonPath += "/" + num2istr(JSON_GetArraySize(jsonID, jsonPath) - 1)
				endif
				jsonPath += "/" + SF_EscapeJsonPath(token)
			case SF_ACTION_ARRAYELEMENT:
				// - "," was encountered, thus we have multiple elements, we need to set an array at current path
				// The actual content is added in the case fall-through
				SF_ASSERT(!(IsEmpty(buffer) && (lastAction == SF_ACTION_COLLECT || lastAction == SF_ACTION_SKIP || lastAction == SF_ACTION_HIGHERORDER)), "array element has no value")
				JSON_AddTreeArray(jsonID, jsonPath)
				lastCalculation = state
			case SF_ACTION_SAMECALCULATION:
			default:
				if(!IsEmpty(buffer))
					JSON_AddJSON(jsonID, jsonPath, SF_FormulaParser(buffer, indentLevel = indentLevel + 1))
				endif
		endswitch
		lastAction = action
		buffer = ""
		token = ""
	endfor

	if(lastAction != SF_ACTION_UNINITIALIZED)
		SF_ASSERT(state != SF_STATE_ADDITION && \
		state != SF_STATE_SUBTRACTION && \
		state != SF_STATE_MULTIPLICATION && \
		state != SF_STATE_OPERATION \
		, "Expected value after +, -, * or /")
	endif

	SF_ASSERT(state != SF_STATE_ARRAYELEMENT, "Expected value after \",\"")

	if(!ParamIsDefault(createdArray))
		if(createdArrayLocal)
			ASSERT(JSON_GetType(jsonID, "") == JSON_ARRAY, "SF Parser Error: Expected Array")
		endif
		createdArray = createdArrayLocal
	endif

	if(IsEmpty(buffer))
		return jsonId
	endif

	// last element (recursion)
	if(!cmpstr(buffer, formula))
		if(GrepString(buffer, "^(?i)[+-]?[0-9]+(?:\.[0-9]+)?(?:[\+-]?E[0-9]+)?$"))
			// optionally signed Number
			JSON_AddVariable(jsonID, jsonPath, str2num(formula))
		elseif(!cmpstr(buffer, "\"\"")) // dummy check
			// empty string with explicit quotation marks
			JSON_AddString(jsonID, jsonPath, "")
		elseif(GrepString(buffer, "^\".*\"$"))
			// non-empty string with quotation marks
			JSON_AddString(jsonID, jsonPath, buffer[1, strlen(buffer) - 2])
		else
			// string without quotation marks
			JSON_AddString(jsonID, jsonPath, buffer)
		endif
	else
		JSON_AddJSON(jsonID, jsonPath, SF_FormulaParser(buffer))
	endif

	return jsonID
End

/// @brief Create a new empty array object, add mainId into it at path and return created json, release subId
static Function SF_FPPutInArrayAtPath(variable subId, string jsonPath)

	variable newId

	newId = JSON_New()
	JSON_AddTreeArray(newId, jsonPath)
	if(JSON_GetType(subId, "") != JSON_NULL)
		JSON_AddJSON(newId, jsonPath, subId)
	endif
	JSON_Release(subId)

	return newId
End

/// @brief Adds subId to mainId, if necessary puts subId into an array, release subId
static Function SF_FPAddArray(variable mainId, string jsonPath, variable subId, variable arrayWasCreated)

	variable tmpId

	if(JSON_GetType(subId, "") != JSON_ARRAY || !arrayWasCreated)

		tmpId = JSON_New()
		JSON_AddTreeArray(tmpId, "")
		JSON_AddJSON(tmpId, "", subId)

		JSON_AddJSON(mainId, jsonPath, tmpId)
		JSON_Release(tmpId)
	else
		JSON_AddJSON(mainId, jsonPath, subId)
	endif

	JSON_Release(subId)
End

/// @brief add escape characters to a path element
static Function/S SF_EscapeJsonPath(string str)

	return ReplaceString("/", str, "~1")
End

static Function SF_PlaceSubArrayAt(WAVE/Z out, WAVE/Z subArray, variable index)

	if(!WaveExists(out))
		return NaN
	endif

	SF_FormulaWaveScaleTransfer(subArray, out, ROWS, COLS)
	SF_FormulaWaveScaleTransfer(subArray, out, COLS, LAYERS)
	SF_FormulaWaveScaleTransfer(subArray, out, LAYERS, CHUNKS)
	// Copy max 3d subarray to data
	if(IsTextWave(out))
		WAVE/T outT = out
		WAVE/T subArrayT = subArray
		Multithread outT[index][0, max(0, DimSize(subArray, ROWS) - 1)][0, max(0, DimSize(subArray, COLS) - 1)][0, max(0, DimSize(subArray, LAYERS) - 1)] = subArrayT[q][r][s]
	else
		Multithread out[index][0, max(0, DimSize(subArray, ROWS) - 1)][0, max(0, DimSize(subArray, COLS) - 1)][0, max(0, DimSize(subArray, LAYERS) - 1)] = subArray[q][r][s]
	endif
End

/// @brief Execute the formula parsed by SF_FormulaParser
///
/// Recursively executes the formula parsed into jsonID.
///
/// @param graph    graph to read from, mainly used by the `data` operation
/// @param jsonID   JSON object ID from the JSON XOP
/// @param jsonPath JSON pointer compliant path
Function/WAVE SF_FormulaExecutor(string graph, variable jsonID, [string jsonPath])

	string opName
	variable JSONType, numArrObjElems, arrayElemJSONType, effectiveArrayDimCount, dim
	variable colSize, layerSize, chunkSize, arrOrObjAtIndex, operationsWithScalarResultCount

	if(ParamIsDefault(jsonPath))
		jsonPath = ""
	endif
	SF_ASSERT(!IsEmpty(graph), "Name of graph window must not be empty.")

#ifdef DEBUGGING_ENABLED
	if(DP_DebuggingEnabledForCaller())
		printf "##########################\r"
		printf "%s\r", JSON_Dump(jsonID, indent = 2)
		printf "##########################\r"
	endif
#endif

	// object and array evaluation
	JSONtype = JSON_GetType(jsonID, jsonPath)
	if(JSONtype == JSON_NUMERIC)
		Make/FREE out = { JSON_GetVariable(jsonID, jsonPath) }
		return SF_GetOutputForExecutorSingle(out, graph, "ExecutorNumberReturn")
	elseif(JSONtype == JSON_STRING)
		Make/FREE/T outT = { JSON_GetString(jsonID, jsonPath) }
		return SF_GetOutputForExecutorSingle(outT, graph, "ExecutorStringReturn")
	elseif(JSONtype == JSON_ARRAY)
		// Evaluate an array consisting of any elements including subarrays and objects (operations)

		// If we want to return an Igor Pro data wave the final dimensionality can not exceed 4
		WAVE topArraySize = JSON_GetMaxArraySize(jsonID, jsonPath)
		effectiveArrayDimCount = DimSize(topArraySize, ROWS)
		SF_ASSERT(effectiveArrayDimCount <= MAX_DIMENSION_COUNT, "Array in evaluation has more than " + num2istr(MAX_DIMENSION_COUNT) + "dimensions.", jsonId=jsonId)
		// Check against empty array
		if(DimSize(topArraySize, ROWS) == 1 && topArraySize[0] == 0)
			Make/FREE/N=0 out
			return SF_GetOutputForExecutorSingle(out, graph, "ExecutorNumberReturn")
		endif

		// Get all types of current level (row)
		Make/FREE/N=(topArraySize[0]) types = JSON_GetType(jsonID, jsonPath + "/" + num2istr(p))
		// Do not allow null, that can happen if a formula like "integrate()" is executed and SF_GetArgumentTop attempts to parse all arguments into one array
		FindValue/V=(JSON_NULL) types
		SF_ASSERT(!(V_Value >= 0), "Encountered null element in array.", jsonId=jsonId)

		WAVE/T/Z outT = JSON_GetTextWave(jsonID, jsonPath, ignoreErr=1)
		WAVE/Z out = JSON_GetWave(jsonID, jsonPath, ignoreErr=1)
		SF_ASSERT(WaveExists(out) || WaveExists(outT), "Mixed types in array not supported.")

		// Increase dimensionality of data to 4D
		Redimension/N=(MAX_DIMENSION_COUNT) topArraySize
		topArraySize[] = topArraySize[p] != 0 ? topArraySize[p] : 1
		if(WaveExists(out))
			Redimension/N=(topArraySize[0], topArraySize[1], topArraySize[2], topArraySize[3])/E=1 out
		endif
		if(WaveExists(outT))
			Redimension/N=(topArraySize[0], topArraySize[1], topArraySize[2], topArraySize[3])/E=1 outT
		endif

		// Get indices of Objects and Arrays on current level
		EXTRACT/FREE/INDX types, arrOrObjAt, (types[p] == JSON_OBJECT) || (types[p] == JSON_ARRAY)
		numArrObjElems = DimSize(arrOrObjAt, ROWS)
		Make/FREE/D/N=0 indicesOfOperationsWithScalarResult
		// Iterate over all subarrays and objects on current level
		for(index : arrOrObjAt)
			WAVE subArray = SF_GetArgumentSingle(jsonID, jsonPath, graph, "ExecutorSubArrayEvaluation", index, checkExist=1)
			SF_ASSERT(numpnts(subArray), "Encountered subArray with zero size.")
			// Type check, decide on type
			if(IsNumericWave(subArray))
				WAVE/T/Z outT = $""
			endif
			if(IsTextWave(subArray))
				WAVE/Z out = $""
				WAVE/T subArrayT = subArray
			endif
			SF_ASSERT(WaveExists(out) || WaveExists(outT), "Mixed types in array not supported.")

			SF_ASSERT(WaveDims(subArray) < MAX_DIMENSION_COUNT, "Encountered 4d sub array at " + jsonPath)

			// Promote WaveNote with meta data if topArray is 1 point.
			// The single topArray element is object or array at this point
			if(WaveExists(out) && numpnts(out) == 1)
				Note/K out, note(subArray)
			endif
			if(WaveExists(outT) && numpnts(outT) == 1)
				Note/K outT, note(subArray)
			endif

			// subArray will be inserted into the current array, thus the dimension will be WaveDims(subArray) + 1
			// Thus, [1, [2]] returns the correct wave of size (2, 1) with {{1, 2}}.
			effectiveArrayDimCount = max(effectiveArrayDimCount, WaveDims(subArray) + 1)

			// If the whole JSON array consists of STRING or NUMERIC types then topArraySize already is of the correct size.
			// If we encounter an Object aka operation it could return an array that is larger than a single element,
			// then we might have to resize beyond the original topArraySize.
			// Increase 4D array size tracking according to new data
			topArraySize[1,*] = max(topArraySize[p], DimSize(subArray, p - 1))
			WAVE outCombinedType = SelectWave(WaveExists(outT), out, outT)
			// resize data according to new topArraySize adapted by sub array size and fill new elements with NaN
			if((DimSize(outCombinedType, COLS)   < topArraySize[1]) || \
			   (DimSize(outCombinedType, LAYERS) < topArraySize[2]) || \
			   (DimSize(outCombinedType, CHUNKS) < topArraySize[3]))

				if(WaveExists(out))
					Duplicate/FREE out, outTmp
					Redimension/N=(topArraySize[0], topArraySize[1], topArraySize[2], topArraySize[3]) outTmp
					FastOp outTmp = (NaN)
					Multithread outTmp[0, DimSize(out, ROWS) - 1][0, DimSize(out, COLS) - 1][0, DimSize(out, LAYERS) - 1][0, DimSize(out, CHUNKS) - 1] = out[p][q][r][s]
					WAVE out = outTmp
				endif
				if(WaveExists(outT))
					Redimension/N=(topArraySize[0], topArraySize[1], topArraySize[2], topArraySize[3]) outT
				endif
			endif
			SF_PlaceSubArrayAt(out, subArray, index)
			SF_PlaceSubArrayAt(outT, subArrayT, index)

			// Save indices of operation/subArray evaluations that returned scalar results
			if(numpnts(subArray) == 1)
				EnsureLargeEnoughWave(indicesOfOperationsWithScalarResult, minimumSize=operationsWithScalarResultCount + 1)
				indicesOfOperationsWithScalarResult[operationsWithScalarResultCount] = index
				operationsWithScalarResultCount += 1
			endif
			arrOrObjAtIndex += 1
		endfor
		Redimension/N=(operationsWithScalarResultCount) indicesOfOperationsWithScalarResult

		// SCALAR EXTENSION
		// Find all indices that are not subArray or objects but either string or numeric, depending on final type determined above
		// As the first element is string or numeric, the array element itself is a skalar.
		// We also consider operations/subArrays that returned a scalar result that we gathered above.
		// The non-skalar case:
		// If from object elements (operations) the topArraySize is increased and as example one operations returns a 3x3 array
		// and another operation a 2x2 array, then for the first operation the topArraySize increase happens, the data from the
		// second operation is just filled in the array with remaining "untouched" elements in that row. These elements stay with the fill
		// value NaN or "".
		arrayElemJSONType = WaveExists(outT) ? JSON_STRING : JSON_NUMERIC
		EXTRACT/FREE/INDX types, indices, types[p] == arrayElemJSONType
		Concatenate/FREE/NP {indicesOfOperationsWithScalarResult}, indices
		if(WaveExists(outT))
			for(index : indices)
				Multithread outT[index][][][] = outT[index][0][0][0]
			endfor
		else
			for(index : indices)
				Multithread out[index][][][] = out[index][0][0][0]
			endfor
		endif

		// out can be text or numeric, afterwards if following code has no type expectations
		if(WaveExists(outT))
			WAVE out = outT
		endif
		// shrink data to actual array size
		for(dim = effectiveArrayDimCount; dim < MAX_DIMENSION_COUNT; dim += 1)
			ASSERT(topArraySize[dim] == 1, "Inconsistent array dimension size")
			topArraySize[dim] = 0
		endfor
		Redimension/N=(topArraySize[0], topArraySize[1], topArraySize[2], topArraySize[3])/E=1 out
		return SF_GetOutputForExecutorSingle(out, graph, "ExecutorArrayReturn")
	endif

	// operation evaluation
	SF_ASSERT(JSONtype == JSON_OBJECT, "Topmost element needs to be an object", jsonId=jsonId)
	WAVE/T operations = JSON_GetKeys(jsonID, jsonPath)
	SF_ASSERT(DimSize(operations, ROWS) == 1, "Only one operation is allowed", jsonId=jsonId)
	jsonPath += "/" + SF_EscapeJsonPath(operations[0])
	SF_ASSERT(JSON_GetType(jsonID, jsonPath) == JSON_ARRAY, "An array is required to hold the operands of the operation.", jsonId=jsonId)

	opName = LowerStr(operations[0])
#ifdef AUTOMATED_TESTING
	strswitch(opName)
		case SF_OP_MINUS:
		case SF_OP_PLUS:
		case SF_OP_DIV:
		case SF_OP_MULT:
		case SF_OP_RANGESHORT:
			break
		default:
			WAVE ops = SF_GetNamedOperations()
			ASSERT(GetRowIndex(ops, str = opName) >= 0, "List of operations with long name is out of date")
			break
	endswitch
#endif

	/// @name SweepFormulaOperations
	/// @{
	strswitch(opName)
		case SF_OP_MINUS:
			WAVE out = SF_OperationMinus(jsonId, jsonPath, graph)
			break
		case SF_OP_PLUS:
			WAVE out = SF_OperationPlus(jsonId, jsonPath, graph)
			break
		case SF_OP_DIV: // division
			WAVE out = SF_OperationDiv(jsonId, jsonPath, graph)
			break
		case SF_OP_MULT:
			WAVE out = SF_OperationMult(jsonId, jsonPath, graph)
			break
		case SF_OP_RANGE:
		case SF_OP_RANGESHORT:
			WAVE out = SF_OperationRange(jsonId, jsonPath, graph)
			break
		case SF_OP_MIN:
			WAVE out = SF_OperationMin(jsonId, jsonPath, graph)
			break
		case SF_OP_MAX:
			WAVE out = SF_OperationMax(jsonId, jsonPath, graph)
			break
		case SF_OP_AVG:
		case SF_OP_MEAN:
			WAVE out = SF_OperationAvg(jsonId, jsonPath, graph)
			break
		case SF_OP_RMS:
			WAVE out = SF_OperationRMS(jsonId, jsonPath, graph)
			break
		case SF_OP_VARIANCE:
			WAVE out = SF_OperationVariance(jsonId, jsonPath, graph)
			break
		case SF_OP_STDEV:
			WAVE out = SF_OperationStdev(jsonId, jsonPath, graph)
			break
		case SF_OP_DERIVATIVE:
			WAVE out = SF_OperationDerivative(jsonId, jsonPath, graph)
			break
		case SF_OP_INTEGRATE:
			WAVE out = SF_OperationIntegrate(jsonId, jsonPath, graph)
			break
		case SF_OP_EPOCHS:
			WAVE out = SF_OperationEpochs(jsonId, jsonPath, graph)
			break
		case SF_OP_AREA:
			WAVE out = SF_OperationArea(jsonId, jsonPath, graph)
			break
		case SF_OP_BUTTERWORTH:
			WAVE out = SF_OperationButterworth(jsonId, jsonPath, graph)
			break
		case SF_OP_TIME:
		case SF_OP_XVALUES:
			WAVE out = SF_OperationXValues(jsonId, jsonPath, graph)
			break
		case SF_OP_TEXT:
			WAVE out = SF_OperationText(jsonId, jsonPath, graph)
			break
		case SF_OP_SETSCALE:
			WAVE out = SF_OperationSetScale(jsonId, jsonPath, graph)
			break
		case SF_OP_WAVE:
			WAVE out = SF_OperationWave(jsonId, jsonPath, graph)
			break
		case SF_OP_CHANNELS:
			WAVE out = SF_OperationChannels(jsonId, jsonPath, graph)
			break
		case SF_OP_SWEEPS:
			WAVE out = SF_OperationSweeps(jsonId, jsonPath, graph)
			break
		case SF_OP_DATA:
			WAVE out = SF_OperationData(jsonId, jsonPath, graph)
			break
		case SF_OP_LABNOTEBOOK:
			WAVE out = SF_OperationLabnotebook(jsonId, jsonPath, graph)
			break
		case SF_OP_LOG: // JSON logic debug operation
			WAVE out = SF_OperationLog(jsonId, jsonPath, graph)
			break
		case SF_OP_LOG10: // decadic logarithm
			WAVE out = SF_OperationLog10(jsonId, jsonPath, graph)
			break
		case SF_OP_CURSORS:
			WAVE out = SF_OperationCursors(jsonId, jsonPath, graph)
			break
		case SF_OP_FINDLEVEL:
			WAVE out = SF_OperationFindLevel(jsonId, jsonPath, graph)
			break
		case SF_OP_APFREQUENCY:
			WAVE out = SF_OperationApFrequency(jsonId, jsonPath, graph)
			break
		case SF_OP_TP:
			WAVE out = SF_OperationTP(jsonId, jsonPath, graph)
			break
		case SF_OP_STORE:
			WAVE out = SF_OperationStore(jsonId, jsonPath, graph)
			break
		case SF_OP_SELECT:
			WAVE out = SF_OperationSelect(jsonId, jsonPath, graph)
			break
		case SF_OP_POWERSPECTRUM:
			WAVE out = SF_OperationPowerSpectrum(jsonId, jsonPath, graph)
			break
		case SF_OP_TPSS:
			WAVE out = SF_OperationTPSS(jsonId, jsonPath, graph)
			break
		case SF_OP_TPINST:
			WAVE out = SF_OperationTPInst(jsonId, jsonPath, graph)
			break
		case SF_OP_TPBASE:
			WAVE out = SF_OperationTPBase(jsonId, jsonPath, graph)
			break
		case SF_OP_TPFIT:
			WAVE out = SF_OperationTPFit(jsonId, jsonPath, graph)
			break
		default:
			SF_ASSERT(0, "Undefined Operation", jsonId=jsonId)
	endswitch
	/// @}

	return out
End

static Function [WAVE/WAVE formulaResults, STRUCT SF_PlotMetaData plotMetaData] SF_GatherFormulaResults(string xFormula, string yFormula, string graph)

	variable i, numResultsY, numResultsX
	variable useXLabel, addDataUnitsInAnnotation
	string dataUnits, dataUnitCheck

	WAVE/WAVE formulaResults = GetFormulaGatherWave()

	WAVE/WAVE/Z wvXRef = $""
	if(!IsEmpty(xFormula))
		WAVE/WAVE wvXRef = SF_ExecuteFormula(xFormula, graph)
		SF_ASSERT(WaveExists(wvXRef), "x part of formula returned no result.")
	endif
	WAVE/WAVE wvYRef = SF_ExecuteFormula(yFormula, graph)
	SF_ASSERT(WaveExists(wvYRef), "y part of formula returned no result.")
	numResultsY = DimSize(wvYRef, ROWS)
	if(WaveExists(wvXRef))
		numResultsX = DimSize(wvXRef, ROWS)
		SF_ASSERT(numResultsX == numResultsY || numResultsX == 1, "X-Formula data not fitting to Y-Formula.")
	endif

	useXLabel = 1
	addDataUnitsInAnnotation = 1
	Redimension/N=(numResultsY, -1) formulaResults
	for(i = 0; i < numResultsY; i += 1)
		WAVE/Z wvYdata = wvYRef[i]
		if(WaveExists(wvYdata))
			if(WaveExists(wvXRef))
				if(numResultsX == 1)
					WAVE/Z wvXdata = wvXRef[0]
					if(WaveExists(wvXdata) && DimSize(wvXdata, ROWS) == numResultsY && numpnts(wvYdata) == 1)
						if(IsTextWave(wvXdata))
							WAVE/T wT = wvXdata
							Make/FREE/T wvXnewDataT = {wT[i]}
							formulaResults[i][%FORMULAX] = wvXnewDataT
						else
							WAVE wv = wvXdata
							Make/FREE/D wvXnewDataD = {wv[i]}
							formulaResults[i][%FORMULAX] = wvXnewDataD
						endif
					else
						formulaResults[i][%FORMULAX] = wvXRef[0]
					endif
				else
					formulaResults[i][%FORMULAX] = wvXRef[i]
				endif

				WAVE/Z wvXdata = formulaResults[i][%FORMULAX]
				if(WaveExists(wvXdata))
					useXLabel = 0
				endif
			endif

			dataUnits = WaveUnits(wvYdata, -1)
			if(IsNull(dataUnitCheck))
				dataUnitCheck = dataUnits
			elseif(CmpStr(dataUnitCheck, dataUnits))
				addDataUnitsInAnnotation = 0
			endif

			formulaResults[i][%FORMULAY] = wvYdata
		endif
	endfor

	dataUnits = ""
	if(!IsNull(dataUnitCheck))
		dataUnits = SelectString(addDataUnitsInAnnotation && !IsEmpty(dataUnitCheck), "", "(" + dataUnitCheck + ")")
	endif

	plotMetaData.dataType = JWN_GetStringFromWaveNote(wvYRef, SF_META_DATATYPE)
	plotMetaData.opStack = JWN_GetStringFromWaveNote(wvYRef, SF_META_OPSTACK)
	plotMetaData.xAxisLabel = SelectString(useXLabel, SF_XLABEL_USER, JWN_GetStringFromWaveNote(wvYRef, SF_META_XAXISLABEL))
	plotMetaData.yAxisLabel = JWN_GetStringFromWaveNote(wvYRef, SF_META_YAXISLABEL) + dataUnits

	return [formulaResults, plotMetaData]
End

static Function/S SF_GetTraceAnnotationText(STRUCT SF_PlotMetaData& plotMetaData, WAVE data)

	variable channelNumber, channelType, sweepNo, isAveraged
	string channelId, prefix
	string traceAnnotation

	prefix = RemoveEnding(ReplaceString(";", plotMetaData.opStack, " "), " ")

	strswitch(plotMetaData.dataType)
		case SF_DATATYPE_TP:
			sweepNo = JWN_GetNumberFromWaveNote(data, SF_META_SWEEPNO)
			if(IsValidSweepNumber(sweepNo))
				channelNumber = JWN_GetNumberFromWaveNote(data, SF_META_CHANNELNUMBER)
				channelType = JWN_GetNumberFromWaveNote(data, SF_META_CHANNELTYPE)
				channelId = StringFromList(channelType, XOP_CHANNEL_NAMES) + num2istr(channelNumber)
				sprintf traceAnnotation, "TP Sweep %d %s", sweepNo, channelId
			else
				sprintf traceAnnotation, "TP"
			endif
			break
		case SF_DATATYPE_SWEEP:
			channelNumber = JWN_GetNumberFromWaveNote(data, SF_META_CHANNELNUMBER)
			channelType = JWN_GetNumberFromWaveNote(data, SF_META_CHANNELTYPE)
			sweepNo = JWN_GetNumberFromWaveNote(data, SF_META_SWEEPNO)
			channelId = StringFromList(channelType, XOP_CHANNEL_NAMES) + num2istr(channelNumber)
			sprintf traceAnnotation, "Sweep %d %s", sweepNo, channelId
			break
		default:
			if(WhichListItem(SF_OP_DATA, plotMetaData.opStack) == -1)
				sprintf traceAnnotation, "%s", prefix
			else
				channelNumber = JWN_GetNumberFromWaveNote(data, SF_META_CHANNELNUMBER)
				channelType = JWN_GetNumberFromWaveNote(data, SF_META_CHANNELTYPE)
				if(IsNaN(channelNumber) || IsNaN(channelType))
					return ""
				endif
				isAveraged = JWN_GetNumberFromWaveNote(data, SF_META_ISAVERAGED)
				if(IsNaN(isAveraged) || !isAveraged)
					sweepNo = JWN_GetNumberFromWaveNote(data, SF_META_SWEEPNO)
					if(IsNaN(sweepNo))
						return ""
					endif
				endif
				channelId = StringFromList(channelType, XOP_CHANNEL_NAMES) + num2istr(channelNumber)
				if(isAveraged)
					sprintf traceAnnotation, "%s Sweep(s) averaged %s", prefix, channelId
				else
					sprintf traceAnnotation, "%s Sweep %d %s", prefix, sweepNo, channelId
				endif
			endif
			break
	endswitch

	return traceAnnotation
End

static Function/S SF_GetMetaDataAnnotationText(STRUCT SF_PlotMetaData& plotMetaData, WAVE data, string traceName)

	return "\\s(" + traceName + ") " + SF_GetTraceAnnotationText(plotMetaData, data) + "\r"
End

static Function [STRUCT RGBColor s] SF_GetTraceColor(string graph, string opStack, WAVE data)

	variable i, channelNumber, channelType, sweepNo, headstage, numDoInh, minVal, isAveraged

	s.red = 0xFFFF
	s.green = 0x0000
	s.blue = 0x0000

	Make/FREE/T stopInheritance = {SF_OPSHORT_MINUS, SF_OPSHORT_PLUS, SF_OPSHORT_DIV, SF_OPSHORT_MULT}
	Make/FREE/T doInheritance = {SF_OP_DATA, SF_OP_TP}

	WAVE/T opStackW = ListToTextWave(opStack, ";")
	numDoInh = DimSize(doInheritance, ROWS)
	Make/FREE/N=(numDoInh) findPos
	for(i = 0; i < numDoInh; i += 1)
		FindValue/TEXT=doInheritance[i]/TXOP=4 opStackW
		findPos[i] = V_Value == -1 ? NaN : V_Value
	endfor
	minVal = WaveMin(findPos)
	if(IsNaN(minVal))
		return [s]
	endif

	Redimension/N=(minVal) opStackW
	WAVE/Z/T common = GetSetIntersection(opStackW, stopInheritance)
	if(WaveExists(common))
		return [s]
	endif

	channelNumber = JWN_GetNumberFromWaveNote(data, SF_META_CHANNELNUMBER)
	channelType = JWN_GetNumberFromWaveNote(data, SF_META_CHANNELTYPE)
	isAveraged = JWN_GetNumberFromWaveNote(data, SF_META_ISAVERAGED)
	sweepNo = isAveraged == 1 ? JWN_GetNumberFromWaveNote(data, SF_META_AVERAGED_FIRST_SWEEP) : JWN_GetNumberFromWaveNote(data, SF_META_SWEEPNO)
	if(!IsValidSweepNumber(sweepNo))
		return [s]
	endif

	WAVE/Z numericalValues = BSP_GetLogbookWave(graph, LBT_LABNOTEBOOK, LBN_NUMERICAL_VALUES, sweepNumber = sweepNo)
	if(WaveExists(numericalValues))
		headstage = GetHeadstageForChannel(numericalValues, sweepNo, channelType, channelNumber, DATA_ACQUISITION_MODE)
		[s] = GetHeadstageColor(headstage)
	endif

	return [s]
End

static Function [string traceName, variable traceCnt] SF_CreateTraceName(variable dataNum, STRUCT SF_PlotMetaData& plotMetaData, WAVE data)

	string traceAnnotation

	traceAnnotation = SF_GetTraceAnnotationText(plotMetaData, data)
	traceAnnotation = ReplaceString(" ", traceAnnotation, "_")
	traceAnnotation = CleanupName(traceAnnotation, 0)
	traceName = GetTraceNamePrefix(traceCnt) + "d" + num2istr(dataNum) + "_" + traceAnnotation
	traceCnt += 1

	return [traceName, traceCnt]
End

/// Reduces a multi line legend to a single line if only the sweep number changes.
/// Returns the original annotation if more changes or the legend text does not follow the exected format
static Function/S SF_ShrinkLegend(string annotation)

	string str, tracePrefix, opPrefix, sweepNum, suffix
	string opPrefixOld, suffixOld
	string sweepList = ""
	variable firstRun = 1

	string expr="(\\\\s\\([\\s\\S]+\\)) ([\\s\\S]*Sweep) (\\d+) ([\\s\\S]*)"

	WAVE/T lines = ListToTextWave(annotation, "\r")
	if(DimSize(lines, ROWS) < 2)
		return annotation
	endif

	SplitString/E=expr lines[0], tracePrefix, opPrefixOld, sweepNum, suffixOld
	if(V_flag != 4)
		return annotation
	endif
	sweepList = AddListItem(sweepNum, sweepList, ",")

	for(line : lines)
		if(firstRun)
			firstRun = 0
			continue
		endif

		SplitString/E=expr line, str, opPrefix, sweepNum, suffix
		if(V_flag != 4 || CmpStr(opPrefixOld, opPrefix, 2) || CmpStr(suffixOld, suffix, 2))
			return annotation
		endif

		sweepList = AddListItem(sweepNum, sweepList, ",", Inf)
	endfor

	sweepList = CompressNumericalList(sweepList, ",")

	return tracePrefix + opPrefixOld + "s " + sweepList + " " + suffixOld
End

static Function [WAVE/T plotGraphs, WAVE/WAVE infos] SF_PreparePlotter(string winNameTemplate, string graph, variable winDisplayMode, variable numGraphs)

	variable i, guidePos, restoreCursorInfo
	string panelName, guideName1, guideName2, win

	Make/FREE/T/N=(numGraphs) plotGraphs
	Make/FREE/WAVE/N=(numGraphs, 2) infos
	SetDimensionLabels(infos, "axes;cursors", COLS)

	// collect infos
	for(i = 0; i < numGraphs; i += 1)
		if(winDisplayMode == SF_DM_NORMAL)
			win = winNameTemplate + num2istr(i)
		elseif(winDisplayMode == SF_DM_SUBWINDOWS)
			win = winNameTemplate + "#" + "Graph" + num2istr(i)
		endif

		if(WindowExists(win))
			WAVE/T/Z axes    = GetAxesRanges(win)
			WAVE/T/Z cursors = GetCursorInfos(win)

			if(WaveExists(cursors) && winDisplayMode == SF_DM_SUBWINDOWS)
				restoreCursorInfo = 1
			endif

			infos[i][%axes]    = axes
			infos[i][%cursors] = cursors
		endif
	endfor

	if(winDisplayMode == SF_DM_NORMAL)
		for(i = 0; i < numGraphs; i += 1)
			win = winNameTemplate + num2istr(i)

			if(!WindowExists(win))
				Display/N=$win as win
				win = S_name
			endif

			SF_CommonWindowSetup(win, graph)

			plotGraphs[i] = win
		endfor
	elseif(winDisplayMode == SF_DM_SUBWINDOWS)
		KillWindow/Z $winNameTemplate
		NewPanel/N=$winNameTemplate
		winNameTemplate = S_name

		SF_CommonWindowSetup(winNameTemplate, graph)

		if(restoreCursorInfo)
			ShowInfo/W=$winNameTemplate
		endif

		// create horizontal guides (one more than graphs)
		for(i = 0; i < numGraphs + 1; i += 1)
			guideName1 = SF_PLOTTER_GUIDENAME + num2istr(i)
			guidePos = i / numGraphs
			DefineGuide $guideName1={FT, guidePos, FB}
		endfor

		// and now the subwindow graphs
		for(i = 0; i < numGraphs; i += 1)
			guideName1 = SF_PLOTTER_GUIDENAME + num2istr(i)
			guideName2 = SF_PLOTTER_GUIDENAME + num2istr(i + 1)
			Display/HOST=$winNameTemplate/FG=(FL, $guideName1, FR, $guideName2)/N=$("Graph" + num2str(i))
			plotGraphs[i] = winNameTemplate + "#" + S_name
		endfor
	endif

	// @todo IP9: workaround IP bug as plotGraphs can not be used directly in the range-based for loop
	WAVE/T localPlotGraphs = plotGraphs
	for(win : localPlotGraphs)
		RemoveTracesFromGraph(win)
		ModifyGraph/W=$win swapXY = 0
	endfor

	return [plotGraphs, infos]
End

static Function SF_CommonWindowSetup(string win, string graph)

	string newTitle

	NVAR JSONid = $GetSettingsJSONid()
	PS_InitCoordinates(JSONid, win, "sweepformula_" + win)

	SetWindow $win hook(resetScaling)=IH_ResetScaling, userData(browser)=graph

	newTitle = BSP_GetFormulaGraphTitle(graph)
	DoWindow/T $win, newTitle
End

static Function/WAVE SF_GatherYUnits(WAVE/WAVE formulaResults, string explicitLbl, WAVE/T/Z yUnits)

	variable i, size, numData

	if(!WaveExists(yUnits))
		Make/FREE/T/N=0 yUnits
	endif

	size = DimSize(yUnits, ROWS)
	if(!isEmpty(explicitLbl))
		Redimension/N=(size + 1) yUnits
		yUnits[size] = explicitLbl
		return yUnits
	endif

	numData = DimSize(formulaResults, ROWS)
	Redimension/N=(size + numData) yUnits

	for(i = 0; i < numData; i += 1)
		WAVE/Z wvResultY = formulaResults[i][%FORMULAY]
		if(!WaveExists(wvResultY))
			continue
		endif
		yUnits[size] = WaveUnits(wvResultY, COLS)
		size += 1
	endfor
	Redimension/N=(size) yUnits

	return yUnits
End

static Function/S SF_CombineYUnits(WAVE/T units)

	string separator = " / "
	string result = ""

	WAVE/T unique = GetUniqueEntries(units, dontDuplicate=1)
	for(unit : unique)
		// @todo Remove if part when "null string for empty string wave elment" bug in IP9 is fixed
		if(IsNull(unit))
			unit = ""
		endif
		result += unit + separator
	endfor

	return RemoveEndingRegExp(result, separator)
End

static Function SF_CheckNumTraces(string graph, variable numTraces)

	string bsPanel, msg

	bsPanel = BSP_GetPanel(GetMainWindow(graph))
	if(numTraces > SF_NUMTRACES_ERROR_THRESHOLD)
		if(!AlreadyCalledOnce(CO_SF_TOO_MANY_TRACES))
			printf "If you really need the feature to plot more than %d traces in the SweepFormula plotter\r", SF_NUMTRACES_ERROR_THRESHOLD
			printf "create an new issue on our development platform. Simply select \"Report an issue\" in the \"Mies Panels\" menu.\r"
		endif

		sprintf msg, "Attempt to plot too many traces (%d).", numTraces
		SF_ASSERT(0, msg)
	endif
	if(numTraces > SF_NUMTRACES_WARN_THRESHOLD)
		sprintf msg, "Plotting %d traces...", numTraces
		SF_SetStatusDisplay(bsPanel, msg, SF_MSG_WARN)
		DoUpdate/W=$bsPanel
	endif
End

static Function SF_CleanUpPlotWindowsOnFail(WAVE/T plotGraphs)

	for(str : plotGraphs)
		WAVE/Z wv = WaveRefIndexed(str, 0, 1)
		if(!WaveExists(wv))
			KillWindow/Z $str
		endif
	endfor
End

/// @brief  Plot the formula using the data from graph
///
/// @param graph  graph to pass to SF_FormulaExecutor
/// @param formula formula to plot
/// @param dfr     [optional, default current] working dataFolder
/// @param dmMode  [optional, default DM_SUBWINDOWS] display mode that defines how multiple sweepformula graphs are arranged
static Function SF_FormulaPlotter(string graph, string formula, [DFREF dfr, variable dmMode])

	string trace
	variable i, j, k, numTraces, splitTraces, splitY, splitX, numGraphs, numWins, numData, dataCnt, traceCnt
	variable dim1Y, dim2Y, dim1X, dim2X, winDisplayMode
	variable xMxN, yMxN, xPoints, yPoints, keepUserSelection, numAnnotations
	string win, wList, winNameTemplate, exWList, wName, annotation, yAxisLabel
	string yFormula, yFormulasRemain
	STRUCT SF_PlotMetaData plotMetaData
	STRUCT RGBColor color

	winDisplayMode = ParamIsDefault(dmMode) ? SF_DM_SUBWINDOWS : dmMode
	ASSERT(winDisplaymode == SF_DM_NORMAL || winDisplaymode == SF_DM_SUBWINDOWS, "Invalid display mode.")

	if(ParamIsDefault(dfr))
		dfr = GetDataFolderDFR()
	endif

	WAVE/T graphCode = SF_SplitCodeToGraphs(formula)
	WAVE/T/Z formulaPairs = SF_SplitGraphsToFormulas(graphCode)
	SF_Assert(WaveExists(formulaPairs), "Could not determine y [vs x] formula pair.")

	DFREF dfrWork = SF_GetWorkingDF(graph)
	KillOrMoveToTrash(dfr=dfrWork)

	SVAR lastCode = $GetLastSweepFormulaCode(dfr)
	keepUserSelection = !cmpstr(lastCode, formula)

	numGraphs = DimSize(formulaPairs, ROWS)
	wList = ""
	winNameTemplate = SF_GetFormulaWinNameTemplate(graph)

	[WAVE/T plotGraphs, WAVE/WAVE infos] = SF_PreparePlotter(winNameTemplate, graph, winDisplayMode, numGraphs)

	for(j = 0; j < numGraphs; j += 1)

		traceCnt = 0
		numAnnotations = 0
		WAVE/Z wvX = $""
		WAVE/T/Z yUnits = $""

		yFormulasRemain = formulaPairs[j][%FORMULA_Y]

		win = plotGraphs[j]
		wList = AddListItem(win, wList)

		Make/FREE=1/T/N=(MINIMUM_WAVE_SIZE) wAnnotations

		do

			annotation = ""

			SplitString/E=SF_SWEEPFORMULA_WITH_REGEXP yFormulasRemain, yFormula, yFormulasRemain
			if(!V_flag)
				break
			endif
			WAVE/WAVE/Z formulaResults = $""
			try
				[formulaResults, plotMetaData] = SF_GatherFormulaResults(formulaPairs[j][%FORMULA_X], yFormula, graph)
			catch
				SF_CleanUpPlotWindowsOnFail(plotGraphs)
				Abort
			endtry
			WAVE/T yUnitsResult = SF_GatherYUnits(formulaResults, plotMetaData.yAxisLabel, yUnits)
			WAVE/T yUnits = yUnitsResult

			numData = DimSize(formulaResults, ROWS)
			for(k = 0; k < numData; k += 1)

				WAVE/Z wvResultX = formulaResults[k][%FORMULAX]
				WAVE/Z wvResultY = formulaResults[k][%FORMULAY]
				if(!WaveExists(wvResultY))
					continue
				endif

				SF_ASSERT(!(IsTextWave(wvResultY) && WaveDims(wvResultY) > 1), "Plotter got 2d+ text wave as y data.")

				[color] = SF_GetTraceColor(graph, plotMetaData.opStack, wvResultY)

				if(!WaveExists(wvResultX) && !IsEmpty(plotMetaData.xAxisLabel))
					WAVE/Z wvResultX = JWN_GetNumericWaveFromWaveNote(wvResultY, SF_META_XVALUES)
				endif

				if(WaveExists(wvResultX))

					SF_ASSERT(!(IsTextWave(wvResultX) && WaveDims(wvResultX) > 1), "Plotter got 2d+ text wave as x data.")

					xPoints = DimSize(wvResultX, ROWS)
					dim1X = max(1, DimSize(wvResultX, COLS))
					dim2X = max(1, DimSize(wvResultX, LAYERS))
					xMxN = dim1X * dim2X
					if(xMxN)
						Redimension/N=(-1, xMxN)/E=1 wvResultX
					endif

					WAVE wvX = GetSweepFormulaX(dfr, dataCnt)
					if(WaveType(wvResultX, 1) == WaveType(wvX, 1))
						Duplicate/O wvResultX $GetWavesDataFolder(wvX, 2)
					else
						MoveWaveWithOverWrite(wvX, wvResultX)
					endif
					WAVE wvX = GetSweepFormulaX(dfr, dataCnt)
				endif

				yPoints = DimSize(wvResultY, ROWS)
				dim1Y = max(1, DimSize(wvResultY, COLS))
				dim2Y = max(1, DimSize(wvResultY, LAYERS))
				yMxN = dim1Y * dim2Y
				if(yMxN)
					Redimension/N=(-1, yMxN)/E=1 wvResultY
				endif

				WAVE wvY = GetSweepFormulaY(dfr, dataCnt)
				if(WaveType(wvResultY, 1) == WaveType(wvY, 1))
					Duplicate/O wvResultY $GetWavesDataFolder(wvY, 2)
				else
					MoveWaveWithOverWrite(wvY, wvResultY)
				endif
				WAVE wvY = GetSweepFormulaY(dfr, dataCnt)
				SF_Assert(!(IsTextWave(wvY) && IsTextWave(wvX)), "One wave needs to be numeric for plotting")

				if(IsTextWave(wvY))
					SF_Assert(WaveExists(wvX), "Cannot plot a single text wave")
					ModifyGraph/W=$win swapXY = 1
					WAVE dummy = wvY
					WAVE wvY = wvX
					WAVE wvX = dummy
				endif

				if(!WaveExists(wvX))
					numTraces = yMxN
					SF_CheckNumTraces(graph, numTraces)
					for(i = 0; i < numTraces; i += 1)
						[trace, traceCnt] = SF_CreateTraceName(k, plotMetaData, wvResultY)
						AppendTograph/W=$win/C=(color.red, color.green, color.blue) wvY[][i]/TN=$trace
						annotation += SF_GetMetaDataAnnotationText(plotMetaData, wvResultY, trace)
					endfor
				elseif((xMxN == 1) && (yMxN == 1)) // 1D
					if(yPoints == 1) // 0D vs 1D
						numTraces = xPoints
						SF_CheckNumTraces(graph, numTraces)
						for(i = 0; i < numTraces; i += 1)
							[trace, traceCnt] = SF_CreateTraceName(k, plotMetaData, wvResultY)
							AppendTograph/W=$win/C=(color.red, color.green, color.blue) wvY[][0]/TN=$trace vs wvX[i][]
							annotation += SF_GetMetaDataAnnotationText(plotMetaData, wvResultY, trace)
						endfor
					elseif(xPoints == 1) // 1D vs 0D
						numTraces = yPoints
						SF_CheckNumTraces(graph, numTraces)
						for(i = 0; i < numTraces; i += 1)
							[trace, traceCnt] = SF_CreateTraceName(k, plotMetaData, wvResultY)
							AppendTograph/W=$win/C=(color.red, color.green, color.blue) wvY[i][]/TN=$trace vs wvX[][0]
							annotation += SF_GetMetaDataAnnotationText(plotMetaData, wvResultY, trace)
						endfor
					else // 1D vs 1D
						splitTraces = min(yPoints, xPoints)
						numTraces = floor(max(yPoints, xPoints) / splitTraces)
						SF_CheckNumTraces(graph, numTraces)
						if(mod(max(yPoints, xPoints), splitTraces) == 0)
							DebugPrint("Unmatched Data Alignment in ROWS.")
						endif
						for(i = 0; i < numTraces; i += 1)
							[trace, traceCnt] = SF_CreateTraceName(k, plotMetaData, wvResultY)
							splitY = SF_SplitPlotting(wvY, ROWS, i, splitTraces)
							splitX = SF_SplitPlotting(wvX, ROWS, i, splitTraces)
							AppendTograph/W=$win/C=(color.red, color.green, color.blue) wvY[splitY, splitY + splitTraces - 1][0]/TN=$trace vs wvX[splitX, splitX + splitTraces - 1][0]
							annotation += SF_GetMetaDataAnnotationText(plotMetaData, wvResultY, trace)
						endfor
					endif
				elseif(yMxN == 1) // 1D vs 2D
					numTraces = xMxN
					SF_CheckNumTraces(graph, numTraces)
					for(i = 0; i < numTraces; i += 1)
						[trace, traceCnt] = SF_CreateTraceName(k, plotMetaData, wvResultY)
						AppendTograph/W=$win/C=(color.red, color.green, color.blue) wvY[][0]/TN=$trace vs wvX[][i]
						annotation += SF_GetMetaDataAnnotationText(plotMetaData, wvResultY, trace)
					endfor
				elseif(xMxN == 1) // 2D vs 1D or 0D
					if(xPoints == 1) // 2D vs 0D -> extend X to 1D with constant value
						Redimension/N=(yPoints) wvX
						xPoints = yPoints
						wvX = wvX[0]
					endif
					numTraces = yMxN
					SF_CheckNumTraces(graph, numTraces)
					for(i = 0; i < numTraces; i += 1)
						[trace, traceCnt] = SF_CreateTraceName(k, plotMetaData, wvResultY)
						AppendTograph/W=$win/C=(color.red, color.green, color.blue) wvY[][i]/TN=$trace vs wvX
						annotation += SF_GetMetaDataAnnotationText(plotMetaData, wvResultY, trace)
					endfor
				else // 2D vs 2D
					numTraces = WaveExists(wvX) ? max(1, max(yMxN, xMxN)) : max(1, yMxN)
					SF_CheckNumTraces(graph, numTraces)
					if(yPoints != xPoints)
						DebugPrint("Size mismatch in data rows for plotting waves.")
					endif
					if(DimSize(wvY, COLS) != DimSize(wvX, COLS))
						DebugPrint("Size mismatch in entity columns for plotting waves.")
					endif
					for(i = 0; i < numTraces; i += 1)
						[trace, traceCnt] = SF_CreateTraceName(k, plotMetaData, wvResultY)
						if(WaveExists(wvX))
							AppendTograph/W=$win/C=(color.red, color.green, color.blue) wvY[][min(yMxN - 1, i)]/TN=$trace vs wvX[][min(xMxN - 1, i)]
						else
							AppendTograph/W=$win/C=(color.red, color.green, color.blue) wvY[][i]/TN=$trace
						endif
						annotation += SF_GetMetaDataAnnotationText(plotMetaData, wvResultY, trace)
					endfor
				endif

				if(DimSize(wvY, ROWS) < SF_MAX_NUMPOINTS_FOR_MARKERS \
					&& (!WaveExists(wvX) \
					|| DimSize(wvx, ROWS) <  SF_MAX_NUMPOINTS_FOR_MARKERS))
					ModifyGraph/W=$win mode=3,marker=19
				endif

				dataCnt += 1
			endfor

			if(!IsEmpty(annotation))
				EnsureLargeEnoughWave(wAnnotations, minimumSize=numAnnotations + 1)
				wAnnotations[numAnnotations] = annotation
				numAnnotations += 1
			endif
		while(1)

		yAxisLabel = SF_CombineYUnits(yUnits)

		if(numAnnotations)
			annotation = ""
			for(k = 0; k < numAnnotations; k += 1)
				annotation += SF_ShrinkLegend(wAnnotations[k]) + "\r"
			endfor
			annotation = RemoveEnding(annotation, "\r")
			annotation = RemoveEnding(annotation, "\r")
			Legend/W=$win/C/N=metadata/F=2 annotation
		endif
		if(!IsEmpty(plotMetaData.xAxisLabel) && traceCnt > 0)
			Label/W=$win bottom plotMetaData.xAxisLabel
			ModifyGraph/W=$win tickUnit(bottom)=1
		endif
		if(!IsEmpty(yAxisLabel) && traceCnt > 0)
			Label/W=$win left yAxisLabel
			ModifyGraph/W=$win tickUnit(left)=1
		endif
		if(traceCnt > 0)
			ModifyGraph/W=$win zapTZ(bottom)=1
		endif

		if(keepUserSelection)
			WAVE/Z cursorInfos = infos[j][%cursors]
			WAVE/Z axesRanges  = infos[j][%axes]

			if(WaveExists(cursorInfos))
				RestoreCursors(win, cursorInfos)
			endif

			if(WaveExists(axesRanges))
				SetAxesRanges(win, axesRanges)
			endif
		endif
	endfor

	if(winDisplayMode == SF_DM_NORMAL)
		exWList = WinList(winNameTemplate + "*", ";", "WIN:1")
		numWins = ItemsInList(exWList)
		for(i = 0; i < numWins; i += 1)
			wName = StringFromList(i, exWList)
			if(WhichListItem(wName, wList) == -1)
				KillWindow/Z $wName
			endif
		endfor
	endif
End

/// @brief utility function for @c SF_FormulaPlotter
///
/// split dimension @p dim of wave @p wv into slices of size @p split and get
/// the starting index @p i
///
static Function SF_SplitPlotting(WAVE wv, variable dim, variable i, variable split)

	return min(i, floor(DimSize(wv, dim) / split) - 1) * split
End

static Function/WAVE SF_GetEmptyRange()

	Make/FREE/D range = {NaN, NaN}

	return range
End

static Function SF_IsEmptyRange(WAVE range)

	ASSERT(IsNumericWave(range), "Invalid Range wave")
	WAVE rangeRef = SF_GetEmptyRange()

	return	EqualWaves(rangeRef, range, 1)
End

/// @brief Returns a range from a epochName
///
/// @param graph name of databrowser graph
/// @param epochName name epoch
/// @param sweep number of sweep
/// @param channel number of DA channel
/// @returns a 1D wave with two elements, [startTime, endTime] in ms, if no epoch could be resolved [NaN, NaN] is returned
static Function/WAVE SF_GetRangeFromEpoch(string graph, string epochName, variable sweep, variable channel)

	string regex
	variable numEpochs

	WAVE range = SF_GetEmptyRange()
	if(IsEmpty(epochName) || !IsValidSweepNumber(sweep))
		return range
	endif

	WAVE/Z numericalValues = BSP_GetLogbookWave(graph, LBT_LABNOTEBOOK, LBN_NUMERICAL_VALUES, sweepNumber = sweep)
	if(!WaveExists(numericalValues))
		return range
	endif

	WAVE/Z textualValues = BSP_GetLogbookWave(graph, LBT_LABNOTEBOOK, LBN_TEXTUAL_VALUES, sweepNumber = sweep)
	if(!WaveExists(textualValues))
		return range
	endif

	regex = "^" + epochName + "$"
	WAVE/T/Z epochs = EP_GetEpochs(numericalValues, textualValues, sweep, XOP_CHANNEL_TYPE_DAC, channel, regex)
	if(!WaveExists(epochs))
		return range
	endif
	numEpochs = DimSize(epochs, ROWS)
	SF_ASSERT(numEpochs <= 1, "Found several fitting epochs. Currently only a single epoch is supported")
	if(numEpochs == 0)
		return range
	endif

	range[0] = str2num(epochs[0][EPOCH_COL_STARTTIME]) * ONE_TO_MILLI
	range[1] = str2num(epochs[0][EPOCH_COL_ENDTIME]) * ONE_TO_MILLI

	return range
End

static Function SF_GetDAChannel(string graph, variable sweep, variable channelType, variable channelNumber)

	variable DAC, index

	WAVE/Z numericalValues = BSP_GetLogbookWave(graph, LBT_LABNOTEBOOK, LBN_NUMERICAL_VALUES, sweepNumber = sweep)
	if(!WaveExists(numericalValues))
		return NaN
	endif
	[WAVE settings, index] = GetLastSettingChannel(numericalValues, $"", sweep, "DAC", channelNumber, channelType, DATA_ACQUISITION_MODE)
	if(WaveExists(settings))
		DAC = settings[index]
		ASSERT(IsFinite(DAC) && index < NUM_HEADSTAGES, "Only associated channels are supported.")
		return DAC
	endif

	return NaN
End

static Function/WAVE SF_GetSweepsForFormula(string graph, WAVE range, WAVE/Z selectData, string opShort)

	variable i, rangeStart, rangeEnd, DAChannel, sweepNo
	variable chanNr, chanType, cIndex, isSweepBrowser
	variable numSelected, index
	string dimLabel, device, dataFolder, epochName

	ASSERT(WindowExists(graph), "graph window does not exist")

	SF_ASSERT(DimSize(range, COLS) == 0, "Range must be a 1d wave.")
	if(IsTextWave(range))
		SF_ASSERT(DimSize(range, ROWS) == 1, "A epoch range must be a single string with the epoch name.")
		WAVE/T wEpochName = range
		epochName = wEpochName[0]
	else
		SF_ASSERT(DimSize(range, ROWS) == 2, "A numerical range is must have two rows for range start and end.")
	endif
	if(!WaveExists(selectData))
		WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, 0)
		JWN_SetStringInWaveNote(output, SF_META_DATATYPE, SF_DATATYPE_SWEEP)
		return output
	endif
	SF_ASSERT(DimSize(selectData, COLS) == 3, "Select data must have 3 columns.")

	numSelected = DimSize(selectData, ROWS)
	WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, numSelected)

	isSweepBrowser = BSP_IsSweepBrowser(graph)

	if(isSweepBrowser)
		DFREF sweepBrowserDFR = SB_GetSweepBrowserFolder(graph)
		WAVE/T sweepMap = GetSweepBrowserMap(sweepBrowserDFR)
	else
		SF_ASSERT(BSP_HasBoundDevice(graph), "No device bound.")
		device = BSP_GetDevice(graph)
		DFREF deviceDFR = GetDeviceDataPath(device)
	endif

	for(i = 0; i < numSelected; i += 1)

		sweepNo = selectData[i][%SWEEP]
		chanNr = selectData[i][%CHANNELNUMBER]
		chanType = selectData[i][%CHANNELTYPE]

		if(isSweepBrowser)
			cIndex = FindDimLabel(sweepMap, COLS, "Sweep")
			FindValue/RMD=[][cIndex]/TEXT=num2istr(sweepNo)/TXOP=4 sweepMap
			if(V_value == -1)
				continue
			endif
			dataFolder = sweepMap[V_row][%DataFolder]
			device     = sweepMap[V_row][%Device]
			DFREF deviceDFR  = GetAnalysisSweepPath(dataFolder, device)
		else
			if(DB_SplitSweepsIfReq(graph, sweepNo))
				continue
			endif
		endif

		DFREF sweepDFR = GetSingleSweepFolder(deviceDFR, sweepNo)

		WAVE/Z sweep = GetDAQDataSingleColumnWave(sweepDFR, chanType, chanNr)
		if(!WaveExists(sweep))
			continue
		endif

		if(WaveExists(wEpochName))
			DAChannel = SF_GetDAChannel(graph, sweepNo, chanType, chanNr)
			WAVE range = SF_GetRangeFromEpoch(graph, epochName, sweepNo, DAChannel)
			if(SF_IsEmptyRange(range))
				continue
			endif
		endif
		rangeStart = range[0]
		rangeEnd = range[1]

		SF_ASSERT(!IsNaN(rangeStart) && !IsNaN(rangeEnd), "Specified range not valid.")
		SF_ASSERT(rangeStart == -inf || (IsFinite(rangeStart) && rangeStart >= leftx(sweep) && rangeStart < rightx(sweep)), "Specified starting range not inside sweep " + num2istr(sweepNo) + ".")
		SF_ASSERT(rangeEnd == inf || (IsFinite(rangeEnd) && rangeEnd >= leftx(sweep) && rangeEnd < rightx(sweep)), "Specified ending range not inside sweep " + num2istr(sweepNo) + ".")
		Duplicate/FREE/R=(rangeStart, rangeEnd) sweep, rangedSweepData

		JWN_SetNumberInWaveNote(rangedSweepData, SF_META_SWEEPNO, sweepNo)
		JWN_SetNumberInWaveNote(rangedSweepData, SF_META_CHANNELTYPE, chanType)
		JWN_SetNumberInWaveNote(rangedSweepData, SF_META_CHANNELNUMBER, chanNr)

		output[index] = rangedSweepData
		index += 1
	endfor
	Redimension/N=(index) output

	JWN_SetStringInWaveNote(output, SF_META_DATATYPE, SF_DATATYPE_SWEEP)

	return output
End

/// @brief transfer the wave scaling from one wave to another
///
/// Note: wave scale transfer requires wave units for the first wave or second wave
///
/// @param source    Wave whos scaling should get transferred
/// @param dest      Wave that accepts the new scaling
/// @param dimSource dimension of the source wave, if SF_TRANSFER_ALL_DIMS is used then all scales and units are transferred on the same dimensions,
///                  dimDest is ignored in that case, no unit check is applied in that case
/// @param dimDest   dimension of the destination wave
static Function SF_FormulaWaveScaleTransfer(WAVE source, WAVE dest, variable dimSource, variable dimDest)

	string sourceUnit, destUnit

	if(dimSource == SF_TRANSFER_ALL_DIMS)
		CopyScales/P source, dest
		return NaN
	endif

	if(!(WaveDims(source) > dimSource && dimSource >= 0) || !(WaveDims(dest) > dimDest && dimDest >= 0))
		return NaN
	endif

	sourceUnit = WaveUnits(source, dimSource)
	destUnit = WaveUnits(dest, dimDest)

	if(IsEmpty(sourceUnit) && IsEmpty(destUnit))
		return NaN
	endif

	switch(dimDest)
		case ROWS:
			SetScale/P x, DimOffset(source, dimSource), DimDelta(source, dimSource), WaveUnits(source, dimSource), dest
			break
		case COLS:
			SetScale/P y, DimOffset(source, dimSource), DimDelta(source, dimSource), WaveUnits(source, dimSource), dest
			break
		case LAYERS:
			SetScale/P z, DimOffset(source, dimSource), DimDelta(source, dimSource), WaveUnits(source, dimSource), dest
			break
		case CHUNKS:
			SetScale/P t, DimOffset(source, dimSource), DimDelta(source, dimSource), WaveUnits(source, dimSource), dest
			break
		default:
			ASSERT(0, "Invalid dimDest")
	endswitch
End

/// @brief Use the labnotebook information to return the active channel numbers
///        for a given set of sweeps
///
/// @param graph           DataBrowser or SweepBrowser reference graph
/// @param channels        @c SF_FormulaExecutor style @c channels() wave
/// @param sweeps          @c SF_FormulaExecutor style @c sweeps() wave
/// @param fromDisplayed   boolean variable, if set the selectdata is determined from the displayed sweeps
/// @param clampMode       numerical variable, sets the clamp mode considered
///
/// @return a selectData style wave with three columns
///         containing sweepNumber, channelType and channelNumber
static Function/WAVE SF_GetActiveChannelNumbersForSweeps(string graph, WAVE/Z channels, WAVE/Z sweeps, variable fromDisplayed, variable clampMode)

	variable i, j, k, l, channelType, channelNumber, sweepNo, sweepNoT, outIndex
	variable numSweeps, numInChannels, numSettings, maxChannels, activeChannel, numActiveChannels
	variable isSweepBrowser, cIndex
	variable dimPosSweep, dimPosChannelNumber, dimPosChannelType
	variable dimPosTSweep, dimPosTChannelNumber, dimPosTChannelType
	variable numTraces
	string setting, settingList, msg, device, dataFolder, singleSweepDFStr

	if(!WaveExists(sweeps) || !DimSize(sweeps, ROWS))
		return $""
	endif

	if(!WaveExists(channels) || !DimSize(channels, ROWS))
		return $""
	endif

	fromDisplayed = !!fromDisplayed

	if(fromDisplayed)
		if(clampMode == SF_OP_SELECT_CLAMPCODE_ALL)
			WAVE/T/Z traces = GetTraceInfos(graph)
		else
			WAVE/T/Z traces = GetTraceInfos(graph, addFilterKeys = {"clampMode"}, addFilterValues={num2istr(clampMode)})
		endif
		if(!WaveExists(traces))
			return $""
		endif
		numTraces = DimSize(traces, ROWS)
		dimPosTSweep = FindDimLabel(traces, COLS, "sweepNumber")
		Make/FREE/D/N=(numTraces) displayedSweeps = str2num(traces[p][dimPosTSweep])
		WAVE displayedSweepsUnique = GetUniqueEntries(displayedSweeps, dontDuplicate=1)
		MatrixOp/FREE sweepsDP = fp64(sweeps)
		WAVE/Z sweepsIntersect = GetSetIntersection(sweepsDP, displayedSweepsUnique)
		if(!WaveExists(sweepsIntersect))
			return $""
		endif
		WAVE sweeps = sweepsIntersect
		numSweeps = DimSize(sweeps, ROWS)

		WAVE selectDisplayed = SF_NewSelectDataWave(numTraces, 1)
		dimPosSweep = FindDimLabel(selectDisplayed, COLS, "SWEEP")
		dimPosChannelType = FindDimLabel(selectDisplayed, COLS, "CHANNELTYPE")
		dimPosChannelNumber = FindDimLabel(selectDisplayed, COLS, "CHANNELNUMBER")

		dimPosTChannelType = FindDimLabel(traces, COLS, "channelType")
		dimPosTChannelNumber = FindDimLabel(traces, COLS, "channelNumber")
		for(i = 0; i < numSweeps; i += 1)
			sweepNo = sweeps[i]
			for(j = 0; j < numTraces; j += 1)
				sweepNoT = str2num(traces[j][dimPosTSweep])
				if(sweepNo == sweepNoT)
					selectDisplayed[outIndex][dimPosSweep] = sweepNo
					selectDisplayed[outIndex][dimPosChannelType] = WhichListItem(traces[j][dimPosTChannelType], XOP_CHANNEL_NAMES)
					selectDisplayed[outIndex][dimPosChannelNumber] = str2num(traces[j][dimPosTChannelNumber])
					outIndex += 1
				endif
				if(outIndex == numTraces)
					break
				endif
			endfor
			if(outIndex == numTraces)
				break
			endif
		endfor
		Redimension/N=(outIndex, -1) selectDisplayed
		numTraces = outIndex

		outIndex = 0
	else
		isSweepBrowser = BSP_IsSweepBrowser(graph)
		if(isSweepBrowser)
			DFREF sweepBrowserDFR = SB_GetSweepBrowserFolder(graph)
			WAVE/T sweepMap = GetSweepBrowserMap(sweepBrowserDFR)
		else
			SF_ASSERT(BSP_HasBoundDevice(graph), "No device bound.")
			device = BSP_GetDevice(graph)
			DFREF deviceDFR = GetDeviceDataPath(device)
		endif
	endif

	// search sweeps for active channels
	numSweeps = DimSize(sweeps, ROWS)
	numInChannels = DimSize(channels, ROWS)

	WAVE selectData = SF_NewSelectDataWave(numSweeps, NUM_DA_TTL_CHANNELS + NUM_AD_CHANNELS)
	if(!fromDisplayed)
		dimPosSweep = FindDimLabel(selectData, COLS, "SWEEP")
		dimPosChannelType = FindDimLabel(selectData, COLS, "CHANNELTYPE")
		dimPosChannelNumber = FindDimLabel(selectData, COLS, "CHANNELNUMBER")
	endif

	for(i = 0; i < numSweeps; i += 1)
		sweepNo = sweeps[i]

		if(!IsValidSweepNumber(sweepNo))
			continue
		endif

		if(!fromDisplayed)
			if(isSweepBrowser)
				cIndex = FindDimLabel(sweepMap, COLS, "Sweep")
				FindValue/RMD=[][cIndex]/TEXT=num2istr(sweepNo)/TXOP=4 sweepMap
				if(V_value == -1)
					continue
				endif
				dataFolder = sweepMap[V_row][%DataFolder]
				device     = sweepMap[V_row][%Device]
				DFREF deviceDFR  = GetAnalysisSweepPath(dataFolder, device)
			else
				if(DB_SplitSweepsIfReq(graph, sweepNo))
					continue
				endif
			endif
			singleSweepDFStr = GetSingleSweepFolderAsString(deviceDFR, sweepNo)
			if(!DataFolderExists(singleSweepDFStr))
				continue
			endif
			DFREF sweepDFR = $singleSweepDFStr
			WAVE/Z numericalValues = BSP_GetLogbookWave(graph, LBT_LABNOTEBOOK, LBN_NUMERICAL_VALUES, sweepNumber = sweepNo)
			if(!WaveExists(numericalValues))
				continue
			endif
		endif

		for(j = 0; j < numInChannels; j += 1)

			channelType = channels[j][%channelType]
			channelNumber = channels[j][%channelNumber]

			if(IsNaN(channelType))
				settingList = "ADC;DAC;"
			else
				switch(channelType)
					case XOP_CHANNEL_TYPE_DAC:
						settingList = "DAC;"
						break
					case XOP_CHANNEL_TYPE_ADC:
						settingList = "ADC;"
						break
					default:
						sprintf msg, "Unhandled channel type %g in channels() at position %d", channelType, j
						SF_ASSERT(0, msg)
				endswitch
			endif

			numSettings = ItemsInList(settingList)
			for(k = 0; k < numSettings; k += 1)
				setting = StringFromList(k, settingList)
				strswitch(setting)
					case "DAC":
						channelType = XOP_CHANNEL_TYPE_DAC
						maxChannels = NUM_DA_TTL_CHANNELS
						break
					case "ADC":
						channelType = XOP_CHANNEL_TYPE_ADC
						maxChannels = NUM_AD_CHANNELS
						break
					default:
						SF_ASSERT(0, "Unexpected setting entry for channel type resolution.")
						break
				endswitch

				if(fromDisplayed)
					for(l = 0; l < numTraces; l += 1)
						if(IsNaN(channelNumber))
							if(sweepNo == selectDisplayed[l][dimPosSweep] && channelType == selectDisplayed[l][dimPosChannelType])
								activeChannel = selectDisplayed[l][dimPosChannelNumber]
								if(activeChannel < maxChannels)
									selectData[outIndex][dimPosSweep] = sweepNo
									selectData[outIndex][dimPosChannelType] = channelType
									selectData[outIndex][dimPosChannelNumber] = selectDisplayed[l][dimPosChannelNumber]
									outIndex += 1
								endif
							endif
						else
							if(sweepNo == selectDisplayed[l][dimPosSweep] && channelType == selectDisplayed[l][dimPosChannelType] && channelNumber == selectDisplayed[l][dimPosChannelNumber] && channelNumber < maxChannels)
								selectData[outIndex][dimPosSweep] = sweepNo
								selectData[outIndex][dimPosChannelType] = channelType
								selectData[outIndex][dimPosChannelNumber] = channelNumber
								outIndex += 1
							endif
						endif
					endfor
				else
					WAVE/Z activeChannels = GetLastSetting(numericalValues, sweepNo, setting, DATA_ACQUISITION_MODE)
					if(!WaveExists(activeChannels))
						continue
					endif
					if(clampMode != SF_OP_SELECT_CLAMPCODE_ALL)
						WAVE/Z clampModes = GetLastSetting(numericalValues, sweepNo, CLAMPMODE_ENTRY_KEY, DATA_ACQUISITION_MODE)
						if(!WaveExists(clampModes))
							continue
						endif
					endif
					if(IsNaN(channelNumber))
						// faster than ZapNaNs due to no mem alloc
						numActiveChannels = DimSize(activeChannels, ROWS)
						for(l = 0; l < numActiveChannels; l += 1)
							if(clampMode != SF_OP_SELECT_CLAMPCODE_ALL && clampMode != clampModes[l])
								continue
							endif
							activeChannel = activeChannels[l]
							if(!IsNaN(activeChannel) && activeChannel < maxChannels)
								selectData[outIndex][dimPosSweep] = sweepNo
								selectData[outIndex][dimPosChannelType] = channelType
								selectData[outIndex][dimPosChannelNumber] = activeChannel
								outIndex += 1
							endif
						endfor
					elseif(channelNumber < maxChannels)
						FindValue/V=(channelNumber) activeChannels
						if(V_Value >= 0 && (clampMode == SF_OP_SELECT_CLAMPCODE_ALL || clampMode == clampModes[V_Value]))
							selectData[outIndex][dimPosSweep] = sweepNo
							selectData[outIndex][dimPosChannelType] = channelType
							selectData[outIndex][dimPosChannelNumber] = channelNumber
							outIndex += 1
						endif
					endif
				endif

			endfor
		endfor
	endfor
	if(!outIndex)
		return $""
	endif

	Redimension/N=(outIndex, -1) selectData
	WAVE out = SF_SortSelectData(selectData)

	return out
End

static Function/WAVE SF_SortSelectData(WAVE selectData)

	variable dimPosSweep, dimPosChannelType, dimPosChannelNumber

	if(DimSize(selectData, ROWS) >= 1)
		dimPosSweep = FindDimLabel(selectData, COLS, "SWEEP")
		dimPosChannelType = FindDimLabel(selectData, COLS, "CHANNELTYPE")
		dimPosChannelNumber = FindDimLabel(selectData, COLS, "CHANNELNUMBER")

		SortColumns/KNDX={dimPosSweep, dimPosChannelType, dimPosChannelNumber} sortWaves=selectData
	endif

	return selectData
End

/// @brief Pre process code entered into the notebook
///        - unify line endings to CR
///        - remove comments at line ending
///        - cut off last CR from back conversion with TextWaveToList
static Function/S SF_PreprocessInput(string formula)

	variable endsWithCR

	if(IsEmpty(formula))
		return ""
	endif

	formula = NormalizeToEOL(formula, SF_CHAR_CR)
	endsWithCR = StringEndsWith(formula, SF_CHAR_CR)

	WAVE/T lines = ListToTextWave(formula, SF_CHAR_CR)
	lines = StringFromList(0, lines[p], SF_CHAR_COMMENT)
	formula = TextWaveToList(lines, SF_CHAR_CR)
	if(IsEmpty(formula))
		return ""
	endif

	if(!endsWithCR)
		formula = formula[0, strlen(formula) - 2]
	endif

	return formula
End

static Function SF_SetStatusDisplay(string bsPanel, string errMsg, variable errState)

	ASSERT(errState == SF_MSG_ERROR || errState == SF_MSG_OK || errState == SF_MSG_WARN, "Unknown error state for SF status")
	SetValDisplay(bsPanel, "status_sweepFormula_parser", var=errState)
	SetSetVariableString(bsPanel, "setvar_sweepFormula_parseResult", errMsg, setHelp = 1)
End

Function SF_button_sweepFormula_check(STRUCT WMButtonAction &ba) : ButtonControl

	string mainPanel, bsPanel, formula_nb, json_nb, formula, errMsg, text
	variable jsonId, errState

	switch(ba.eventCode)
		case 2: // mouse up
			mainPanel = GetMainWindow(ba.win)
			bsPanel = BSP_GetPanel(mainPanel)

			if(!BSP_HasBoundDevice(bsPanel))
				DebugPrint("Unbound device in DataBrowser")
				break
			endif

			DFREF dfr = BSP_GetFolder(mainPanel, MIES_BSP_PANEL_FOLDER)

			formula_nb = BSP_GetSFFormula(ba.win)
			formula = GetNotebookText(formula_nb, mode=2)

			SF_CheckInputCode(formula, dfr)

			errMsg = ROStr(GetSweepFormulaParseErrorMessage())
			errState = IsEmpty(errMsg) ? SF_MSG_OK : SF_MSG_ERROR
			SF_SetStatusDisplay(bsPanel, errMsg, errState)

			json_nb = BSP_GetSFJSON(mainPanel)
			jsonID = ROVar(GetSweepFormulaJSONid(dfr))
			text = JSON_Dump(jsonID, indent = 2, ignoreErr = 1)
			text = NormalizeToEOL(text, "\r")
			ReplaceNotebookText(json_nb, text)

			break
	endswitch

	return 0
End

/// @brief Checks input code, sets globals for jsonId and error string
static Function SF_CheckInputCode(string code, DFREF dfr)

	variable i, numFormulae, numGraphs, jsonIDy, jsonIDx
	string jsonPath, tmpStr, xFormula

	SVAR errMsg = $GetSweepFormulaParseErrorMessage()
	errMsg = ""

	NVAR jsonID = $GetSweepFormulaJSONid(dfr)
	JSON_Release(jsonID, ignoreErr = 1)
	jsonID = JSON_New()
	JSON_AddObjects(jsonID, "")

	WAVE/T graphCode = SF_SplitCodeToGraphs(SF_PreprocessInput(code))
	WAVE/T/Z formulaPairs = SF_SplitGraphsToFormulas(graphCode)
	if(!WaveExists(formulaPairs))
		errMsg = "Could not determine y [vs x] formula pair."
		return NaN
	endif

	numGraphs = DimSize(formulaPairs, ROWS)
	for(i = 0; i < numGraphs; i += 1)
		jsonPath = "/Formula_" + num2istr(i)
		JSON_AddObjects(jsonID, jsonPath)

		// catch Abort from SF_Assert called from SF_FormulaParser
		try
			jsonIDy = SF_FormulaParser(SF_FormulaPreParser(formulaPairs[i][%FORMULA_Y]))
		catch
			JSON_Release(jsonID, ignoreErr = 1)
			return NaN
		endtry
		JSON_AddJSON(jsonID, jsonPath + "/y", jsonIDy)
		JSON_Release(jsonIDy)

		xFormula = formulaPairs[i][%FORMULA_X]
		if(!IsEmpty(xFormula))
			// catch Abort from SF_Assert called from SF_FormulaParser
			try
				jsonIDx = SF_FormulaParser(SF_FormulaPreParser(xFormula))
			catch
				JSON_Release(jsonID, ignoreErr = 1)
				return NaN
			endtry
			JSON_AddJSON(jsonID, jsonPath + "/x", jsonIDx)
			JSON_Release(jsonIDx)
		endif
	endfor
End

Function SF_Update(string graph)
	string bsPanel = BSP_GetPanel(graph)

	if(!SF_IsActive(bsPanel))
		return NaN
	endif

	PGC_SetAndActivateControl(bsPanel, "button_sweepFormula_display")
End

/// @brief checks if SweepFormula (SF) is active.
Function SF_IsActive(string win)

	return BSP_IsActive(win, MIES_BSP_SF)
End

/// @brief Return the sweep formula code in raw and with all necessary preprocesssing
Function [string raw, string preProc] SF_GetCode(string win)
	string formula_nb, code

	formula_nb = BSP_GetSFFormula(win)
	code = GetNotebookText(formula_nb,mode=2)

	return [code, SF_PreprocessInput(code)]
End

Function SF_button_sweepFormula_display(STRUCT WMButtonAction &ba) : ButtonControl

	string mainPanel, rawCode, bsPanel, preProcCode

	switch(ba.eventCode)
		case 2: // mouse up
			mainPanel = GetMainWindow(ba.win)
			bsPanel = BSP_GetPanel(mainPanel)

			[rawCode, preProcCode] = SF_GetCode(mainPanel)

			if(IsEmpty(preProcCode))
				break
			endif

			if(!BSP_HasBoundDevice(bsPanel))
				DebugPrint("Databrowser has unbound device")
				break
			endif

			DFREF dfr = BSP_GetFolder(mainPanel, MIES_BSP_PANEL_FOLDER)

			SVAR result = $GetSweepFormulaParseErrorMessage()
			result = ""

			SF_SetStatusDisplay(bsPanel, "", SF_MSG_OK)

			// catch Abort from SF_ASSERT
			try
				SF_FormulaPlotter(mainPanel, preProcCode, dfr = dfr)

				SVAR lastCode = $GetLastSweepFormulaCode(dfr)
				lastCode = preProcCode

				[WAVE/T keys, WAVE/T values] = SF_CreateResultsWaveWithCode(mainPanel, rawCode)

				ED_AddEntriesToResults(values, keys, UNKNOWN_MODE)
			catch
				SF_SetStatusDisplay(bsPanel, result, SF_MSG_ERROR)
			endtry

			break
	endswitch

	return 0
End

static Function/S SF_PrepareDataForResultsWave(WAVE data)
	variable numEntries, maxEntries

	if(IsNumericWave(data))
		Make/T/FREE/N=(DimSize(data, ROWS), DimSize(data, COLS), DimSize(data, LAYERS), DimSize(data, CHUNKS)) dataTxT
		MultiThread dataTxT[][][][] = num2strHighPrec(data[p][q][r][s], precision = MAX_DOUBLE_PRECISION, shorten = 1)
	else
		WAVE/T dataTxT = data
	endif

	// assuming 100 sweeps on average
	maxEntries = 100 * NUM_HEADSTAGES * 10 // NOLINT
	numEntries = numpnts(dataTxT)

	if(numpnts(dataTxT) > maxEntries)
		printf "The store operation received too much data to store, it will only store the first %d entries\r.", maxEntries
		ControlWindowToFront()
		numEntries = maxEntries
	endif

	return TextWaveToList(dataTxT, ";", maxElements = numEntries)
End

static Function [WAVE/T keys, WAVE/T values] SF_CreateResultsWaveWithCode(string graph, string code, [WAVE data, string name])
	variable numEntries, numOptParams, hasStoreEntry, numCursors, numBasicEntries
	string shPanel, dataFolder, device

	numOptParams = ParamIsDefault(data) + ParamIsDefault(name)
	ASSERT(numOptParams == 0 || numOptParams == 2, "Invalid optional parameters")
	hasStoreEntry = (numOptParams == 0)

	ASSERT(!IsEmpty(code), "Unexpected empty code")
	numCursors = ItemsInList(CURSOR_NAMES)
	numBasicEntries = 4
	numEntries = numBasicEntries + numCursors + hasStoreEntry

	Make/T/FREE/N=(1, numEntries) keys
	Make/T/FREE/N=(1, numEntries, LABNOTEBOOK_LAYER_COUNT) values

	keys[0][0]                                                 = "Sweep Formula code"
	keys[0][1]                                                 = "Sweep Formula sweeps/channels"
	keys[0][2]                                                 = "Sweep Formula experiment"
	keys[0][3]                                                 = "Sweep Formula device"
	keys[0][numBasicEntries, numBasicEntries + numCursors - 1] = "Sweep Formula cursor " + StringFromList(q - numBasicEntries, CURSOR_NAMES)

	if(hasStoreEntry)
		SF_ASSERT(IsValidLiberalObjectName(name[0]), "Can not use the given name for the labnotebook key")
		keys[0][numEntries - 1] = "Sweep Formula store [" + name + "]"
	endif

	LBN_SetDimensionLabels(keys, values)

	values[0][%$"Sweep Formula code"][INDEP_HEADSTAGE] = NormalizeToEOL(TrimString(code), "\n")

	WAVE/T/Z cursorInfos = GetCursorInfos(graph)

	WAVE/Z selectData = SF_ExecuteFormula("select()", graph, singleResult=1)
	if(WaveExists(selectData))
		values[0][%$"Sweep Formula sweeps/channels"][INDEP_HEADSTAGE] = NumericWaveToList(selectData, ";")
	endif

	shPanel = LBV_GetSettingsHistoryPanel(graph)

	dataFolder = GetPopupMenuString(shPanel, "popup_experiment")
	values[0][%$"Sweep Formula experiment"][INDEP_HEADSTAGE] = dataFolder

	device = GetPopupMenuString(shPanel, "popup_Device")
	values[0][%$"Sweep Formula device"][INDEP_HEADSTAGE] = device

	if(WaveExists(cursorInfos))
		values[0][numBasicEntries, numBasicEntries + numCursors - 1][INDEP_HEADSTAGE] = cursorInfos[q - numBasicEntries]
	endif

	if(hasStoreEntry)
		values[0][numEntries - 1][INDEP_HEADSTAGE] = SF_PrepareDataForResultsWave(data)
	endif

	return [keys, values]
End

Function SF_TabProc_Formula(STRUCT WMTabControlAction &tca) : TabControl

	string mainPanel, bsPanel, json_nb, text
	variable jsonID

	switch( tca.eventCode )
		case 2: // mouse up
			mainPanel = GetMainWindow(tca.win)
			bsPanel = BSP_GetPanel(mainPanel)
			if(tca.tab == 1)
				PGC_SetAndActivateControl(bsPanel, "button_sweepFormula_check")
			elseif(tca.tab == 2)
				BSP_UpdateHelpNotebook(mainPanel)
			endif

			if(!BSP_HasBoundDevice(bsPanel))
				DebugPrint("Databrowser has unbound device")
				break
			endif

			break
	endswitch

	return 0
End

static Function/WAVE SF_FilterEpochs(WAVE/Z epochs, WAVE/Z ignoreTPs)
	variable i, numEntries, index

	if(!WaveExists(epochs))
		return $""
	elseif(!WaveExists(ignoreTPs))
		return epochs
	endif

	// descending sort
	SortColumns/KNDX={0}/R sortWaves={ignoreTPs}

	numEntries = DimSize(ignoreTPs, ROWS)
	for(i = 0; i < numEntries; i += 1)
		index = ignoreTPs[i]
		SF_ASSERT(IsFinite(index), "ignored TP index is non-finite")
		SF_ASSERT(index >=0 && index < DimSize(epochs, ROWS), "ignored TP index is out of range")
		DeletePoints/M=(ROWS) index, 1, epochs
	endfor

	if(DimSize(epochs, ROWS) == 0)
		return $""
	endif

	return epochs
End

// tpss()
static Function/WAVE SF_OperationTPSS(variable jsonId, string jsonPath, string graph)

	variable numArgs, outType
	string opShort = SF_OP_TPSS

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs == 0, "tpss has no arguments")

	WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, 0)
	JWN_SetStringInWaveNote(output, SF_META_DATATYPE, SF_DATATYPE_TPSS)

	return SF_GetOutputForExecutor(output, graph, opShort)
End

// tpinst()
static Function/WAVE SF_OperationTPInst(variable jsonId, string jsonPath, string graph)

	variable numArgs, outType
	string opShort = SF_OP_TPINST

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs == 0, "tpinst has no arguments")

	WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, 0)
	JWN_SetStringInWaveNote(output, SF_META_DATATYPE, SF_DATATYPE_TPINST)

	return SF_GetOutputForExecutor(output, graph, opShort)
End

// tpbase()
static Function/WAVE SF_OperationTPBase(variable jsonId, string jsonPath, string graph)

	variable numArgs, outType
	string opShort = SF_OP_TPBASE

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs == 0, "tpbase has no arguments")

	WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, 0)
	JWN_SetStringInWaveNote(output, SF_META_DATATYPE, SF_DATATYPE_TPBASE)

	return SF_GetOutputForExecutor(output, graph, opShort)
End

// tpfit()
static Function/WAVE SF_OperationTPFit(variable jsonId, string jsonPath, string graph)

	variable numArgs, outType
	string func, retVal
	variable maxTrailLength = 250 // ms
	string opShort = SF_OP_TPFIT

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs >= 2 && numArgs <= 3, "tpfit has two or three arguments")

	WAVE/T wFitType = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_TPFIT, 0, checkExist=1)
	SF_ASSERT(IsTextWave(wFitType), "TPFit function argument must be textual.")
	SF_ASSERT(DimSize(wFitType, ROWS) == 1, "TPFit function argument must be a single string.")
	func = wFitType[0]
	SF_ASSERT(!CmpStr(func, SF_OP_TPFIT_FUNC_EXP) || !CmpStr(func, SF_OP_TPFIT_FUNC_DEXP), "Fit function must be exp or doubleexp")

	WAVE/T wReturn = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_TPFIT, 1, checkExist=1)
	SF_ASSERT(IsTextWave(wReturn), "TPFit return what argument must be textual.")
	SF_ASSERT(DimSize(wReturn, ROWS) == 1, "TPFit return what argument must be a single string.")
	retVal = wReturn[0]
	SF_ASSERT(!CmpStr(retVal, SF_OP_TPFIT_RET_TAULARGE) || !CmpStr(retVal, SF_OP_TPFIT_RET_TAUSMALL) || !CmpStr(retVal, SF_OP_TPFIT_RET_AMP) || !CmpStr(retVal, SF_OP_TPFIT_RET_MINAMP) || !CmpStr(retVal, SF_OP_TPFIT_RET_FITQUALITY), "TP fit result must be tau, tausmall, amp, minabsamp, fitq")

	if(numArgs == 3)
		WAVE wTrailLength = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_TPFIT, 2, checkExist=1)
		SF_ASSERT(IsNumericWave(wTrailLength), "TPFit maxTrailLength what argument must be a number.")
		SF_ASSERT(DimSize(wTrailLength, ROWS) == 1, "TPFit maxTrailLength argument must be a single number.")
		SF_ASSERT(wTrailLength[0] > 0, "TPFit maxTrailLength must be > 0.")
		maxTrailLength = wTrailLength[0]
	endif

	Make/FREE/T fitSettingsT = {func, retVal}
	SetDimLabel ROWS, 0, FITFUNCTION, fitSettingsT
	SetDimLabel ROWS, 1, RETURNWHAT, fitSettingsT
	Make/FREE/D fitSettings = {maxTrailLength}
	SetDimLabel ROWS, 0, MAXTRAILLENGTH, fitSettings

	WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, 2)
	JWN_SetStringInWaveNote(output, SF_META_DATATYPE, SF_DATATYPE_TPFIT)

	output[0] = fitSettingsT
	output[1] = fitSettings

	return SF_GetOutputForExecutor(output, graph, opShort)
End

// tp(string type[, array selectData[, array ignoreTPs]])
static Function/WAVE SF_OperationTP(variable jsonId, string jsonPath, string graph)

	variable numArgs, outType
	string dataType, allowedTypes

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs >= 1 || numArgs <= 3, "tp requires 1 to 3 arguments")

	if(numArgs == 3)
		WAVE ignoreTPs = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_TP, 2, checkExist=1)
		SF_ASSERT(WaveDims(ignoreTPs) == 1, "ignoreTPs must be one-dimensional.")
		SF_ASSERT(IsNumericWave(ignoreTPs), "ignoreTPs parameter must be numeric")
	else
		WAVE/Z ignoreTPs
	endif

	if(numArgs >= 2)
		WAVE/Z selectData = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_TP, 1)
	else
		WAVE/Z selectData = SF_ExecuteFormula("select()", graph, singleResult=1)
	endif
	if(WaveExists(selectData))
		SF_ASSERT(DimSize(selectData, COLS) == 3, "A select input has 3 columns.")
		SF_ASSERT(IsNumericWave(selectData), "select parameter must be numeric")
	endif

	WAVE/WAVE wMode = SF_GetArgument(jsonID, jsonPath, graph, SF_OP_TP, 0)
	dataType = JWN_GetStringFromWaveNote(wMode, SF_META_DATATYPE)

	allowedTypes = AddListItem(SF_DATATYPE_TPSS, "")
	allowedTypes = AddListItem(SF_DATATYPE_TPINST, allowedTypes)
	allowedTypes = AddListItem(SF_DATATYPE_TPBASE, allowedTypes)
	allowedTypes = AddListItem(SF_DATATYPE_TPFIT, allowedTypes)
	SF_ASSERT(WhichListItem(dataType, allowedTypes) >= 0, "Unknown TP mode.")

	WAVE/WAVE output = SF_OperationTPImpl(graph, wMode, selectData, ignoreTPs, SF_OP_TP)

	JWN_SetStringInWaveNote(output, SF_META_DATATYPE, SF_DATATYPE_TP)
	JWN_SetStringInWaveNote(output, SF_META_OPSTACK, AddListItem(SF_OP_TP, ""))

	return SF_GetOutputForExecutor(output, graph, SF_OP_TP)
End

static Function SF_GetTPFitQuality(WAVE residuals, WAVE sweepData, variable beginTrail, variable endTrail)

	variable beginTrailIndex
	variable endTrailIndex

	beginTrailIndex = ScaleToIndex(sweepData, beginTrail, ROWS)
	endTrailIndex = ScaleToIndex(sweepData, endTrail, ROWS)
	Multithread residuals = residuals[p]^2

	return sum(residuals, beginTrail, endTrail) / (endTrailIndex - beginTrailIndex)
End

static Function/WAVE SF_OperationTPImpl(string graph, WAVE/WAVE mode, WAVE/Z selectData, WAVE/Z ignoreTPs, string opShort)

	variable i, j, numSelected, sweepNo, chanNr, chanType, dacChannelNr, settingsIndex, headstage, tpBaseLinePoints, index, err, maxTrailLength
	string unitKey, epShortName, baselineUnit, xAxisLabel, yAxisLabel, debugGraph, dataType
	string fitFunc, retWhat, epBaselineTrail, allowedReturns

	variable numTPs, beginTrail, endTrail, endTrailIndex, beginTrailIndex, fitResult
	variable debugMode

	STRUCT TPAnalysisInput tpInput
	string epochTPRegExp = "^(U_)?TP[[:digit:]]*$"

#ifdef DEBUGGING_ENABLED
	if(DP_DebuggingEnabledForCaller())
		debugMode = 1
	endif
#endif

	if(!WaveExists(selectData))
		WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, 0)
		return output
	endif

	dataType = JWN_GetStringFromWaveNote(mode, SF_META_DATATYPE)
	if(!CmpStr(dataType, SF_DATATYPE_TPFIT))
		WAVE/T fitSettingsT = mode[0]
		fitFunc = fitSettingsT[%FITFUNCTION]
		retWhat = fitSettingsT[%RETURNWHAT]
		WAVE fitSettings = mode[1]
		maxTrailLength = fitSettings[%MAXTRAILLENGTH]

		allowedReturns = AddListItem(SF_OP_TPFIT_RET_TAULARGE, "")
		allowedReturns = AddListItem(SF_OP_TPFIT_RET_TAUSMALL, allowedReturns)
		allowedReturns = AddListItem(SF_OP_TPFIT_RET_AMP, allowedReturns)
		allowedReturns = AddListItem(SF_OP_TPFIT_RET_MINAMP, allowedReturns)
		allowedReturns = AddListItem(SF_OP_TPFIT_RET_FITQUALITY, allowedReturns)
		SF_ASSERT(WhichListItem(retWhat, allowedReturns) >= 0, "Unknown return value requested.")
	endif

	numSelected = DimSize(selectData, ROWS)
	WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, numSelected)

	WAVE singleSelect = SF_NewSelectDataWave(1, 1)

	WAVE/Z settings
	for(i = 0; i < numSelected; i += 1)

		sweepNo = selectData[i][%SWEEP]
		chanNr = selectData[i][%CHANNELNUMBER]
		chanType = selectData[i][%CHANNELTYPE]

		if(!IsValidSweepNumber(sweepNo))
			continue
		endif

		WAVE/Z numericalValues = BSP_GetLogbookWave(graph, LBT_LABNOTEBOOK, LBN_NUMERICAL_VALUES, sweepNumber = sweepNo)
		WAVE/Z textualValues = BSP_GetLogbookWave(graph, LBT_LABNOTEBOOK, LBN_TEXTUAL_VALUES, sweepNumber = sweepNo)
		if(!WaveExists(numericalValues) || !WaveExists(textualValues))
			continue
		endif

		singleSelect[0][%SWEEP] = sweepNo
		singleSelect[0][%CHANNELTYPE] = chanType
		singleSelect[0][%CHANNELNUMBER] = chanNr

		WAVE/WAVE sweepDataRef = SF_GetSweepsForFormula(graph, {-Inf, Inf}, singleSelect, SF_OP_TP)
		SF_ASSERT(DimSize(sweepDataRef, ROWS) == 1, "Could not retrieve sweep data for " + num2istr(sweepNo))
		WAVE/Z sweepData = sweepDataRef[0]
		SF_ASSERT(WaveExists(sweepData), "No sweep data for " + num2istr(sweepNo) + " found.")

		unitKey = ""
		baselineUnit = ""
		if(chanType == XOP_CHANNEL_TYPE_DAC)
			unitKey = "DA unit"
		elseif(chanType == XOP_CHANNEL_TYPE_ADC)
			unitKey = "AD unit"
		endif
		if(!IsEmpty(unitKey))
			[WAVE settings, settingsIndex] = GetLastSettingChannel(numericalValues, textualValues, sweepNo, unitKey, chanNr, chanType, DATA_ACQUISITION_MODE)
			SF_ASSERT(WaveExists(settings), "Failed to retrieve channel unit from LBN")
			WAVE/T settingsT = settings
			baselineUnit = settingsT[settingsIndex]
		endif

		headstage = GetHeadstageForChannel(numericalValues, sweepNo, chanType, chanNr, DATA_ACQUISITION_MODE)
		SF_ASSERT(IsFinite(headstage), "Associated headstage must not be NaN")
		[WAVE settings, settingsIndex] = GetLastSettingChannel(numericalValues, textualValues, sweepNo, "DAC", chanNr, chanType, DATA_ACQUISITION_MODE)
		SF_ASSERT(WaveExists(settings), "Failed to retrieve DAC channels from LBN")
		dacChannelNr = settings[headstage]
		SF_ASSERT(IsFinite(dacChannelNr), "DAC channel number must be finite")

		WAVE/Z epochMatchesAll = EP_GetEpochs(numericalValues, textualValues, sweepNo, XOP_CHANNEL_TYPE_DAC, dacChannelNr, epochTPRegExp)

		// drop TPs which should be ignored
		// relies on ascending sorting of start times in epochMatches
		WAVE/T/Z epochMatches = SF_FilterEpochs(epochMatchesAll, ignoreTPs)

		if(!WaveExists(epochMatches))
			continue
		endif

		if(!CmpStr(dataType, SF_DATATYPE_TPFIT))

			if(debugMode)
				JWN_SetNumberInWaveNote(sweepData, SF_META_SWEEPNO, sweepNo)
				JWN_SetNumberInWaveNote(sweepData, SF_META_CHANNELTYPE, chanType)
				JWN_SetNumberInWaveNote(sweepData, SF_META_CHANNELNUMBER, chanNr)
				output[index] = sweepData
				index += 1
			endif

			numTPs = DimSize(epochMatches, ROWS)
			Make/FREE/D/N=(numTPs) fitResults

#ifdef AUTOMATED_TESTING
			Make/FREE/D/N=(numTPs) beginTrails, endTrails
			beginTrails = NaN
			endTrails = NaN
#endif
			for(j = 0; j < numTPs; j += 1)

				epBaselineTrail = EP_GetShortName(epochMatches[j][EPOCH_COL_TAGS]) + "_B1"
				WAVE/Z/T epochTPBaselineTrail = EP_GetEpochs(numericalValues, textualValues, sweepNo, XOP_CHANNEL_TYPE_DAC, dacChannelNr, epBaselineTrail)
				SF_ASSERT(WaveExists(epochTPBaselineTrail) && DimSize(epochTPBaselineTrail, ROWS) == 1, "No TP trailing baseline epoch found for TP epoch")
				WAVE/Z/T nextEpoch = EP_GetNextEpoch(numericalValues, textualValues, sweepNo, XOP_CHANNEL_TYPE_DAC, dacChannelNr, epBaselineTrail, 1)

				beginTrail = str2numSafe(epochTPBaselineTrail[0][EPOCH_COL_STARTTIME]) * ONE_TO_MILLI
				if(WaveExists(nextEpoch) && EP_GetEpochAmplitude(nextEpoch[0][EPOCH_COL_TAGS]) == 0)
					endTrail = str2numSafe(nextEpoch[0][EPOCH_COL_ENDTIME]) * ONE_TO_MILLI
				else
					endTrail = str2numSafe(epochTPBaselineTrail[0][EPOCH_COL_ENDTIME]) * ONE_TO_MILLI
				endif
				endTrail = min(endTrail, beginTrail + maxTrailLength)

#ifdef AUTOMATED_TESTING
				beginTrails[j] = beginTrail
				endTrails[j] = endTrail
#endif

				if(!CmpStr(retWhat, SF_OP_TPFIT_RET_FITQUALITY))
					Duplicate/FREE sweepData, residuals
				endif

				if(debugMode)
					Duplicate/FREE sweepData, wFitResult
					FastOp wFitResult = (NaN)
					Note/K wFitResult
				endif

				if(!CmpStr(fitFunc, SF_OP_TPFIT_FUNC_EXP))
					Make/FREE/D/N=3 coefWave

					if(debugMode)
						CurveFit/Q/K={beginTrail} exp_XOffset, kwCWave=coefWave, sweepData(beginTrail, endTrail)/D=wFitResult; err = getRTError(1)
						if(!err)
							EnsureLargeEnoughWave(output, minimumSize=index)
							output[index] = wFitResult
							index += 1
							continue
						endif
					else
						fitResult = NaN
						if(!CmpStr(retWhat, SF_OP_TPFIT_RET_FITQUALITY))
							CurveFit/Q/K={beginTrail} exp_XOffset, kwCWave=coefWave, sweepData(beginTrail, endTrail)/R=residuals; err = getRTError(1)
							if(!err)
								fitResult = SF_GetTPFitQuality(residuals, sweepData, beginTrail, endTrail)
							endif
						else
							CurveFit/Q/K={beginTrail} exp_XOffset, kwCWave=coefWave, sweepData(beginTrail, endTrail); err = getRTError(1)
						endif
						if(!err)
							if(!CmpStr(retWhat, SF_OP_TPFIT_RET_TAULARGE) || !CmpStr(retWhat, SF_OP_TPFIT_RET_TAUSMALL))
								fitResult = coefWave[2]
							elseif(!CmpStr(retWhat, SF_OP_TPFIT_RET_AMP) || !CmpStr(retWhat, SF_OP_TPFIT_RET_MINAMP))
								fitResult = coefWave[1]
							endif
						endif
					endif
				elseif(!CmpStr(fitFunc, SF_OP_TPFIT_FUNC_DEXP))
					Make/FREE/D/N=5 coefWave

					if(debugMode)
						CurveFit/Q/K={beginTrail} dblexp_XOffset, kwCWave=coefWave, sweepData(beginTrail, endTrail)/D=wFitResult; err = getRTError(1)
						if(!err)
							EnsureLargeEnoughWave(output, minimumSize=index)
							output[index] = wFitResult
							index += 1
							continue
						endif
					else
						if(!CmpStr(retWhat, SF_OP_TPFIT_RET_FITQUALITY))
							CurveFit/Q/K={beginTrail} dblexp_XOffset, kwCWave=coefWave, sweepData(beginTrail, endTrail)/R=residuals; err = getRTError(1)
							if(!err)
								fitResult = SF_GetTPFitQuality(residuals, sweepData, beginTrail, endTrail)
							endif
						else
							CurveFit/Q/K={beginTrail} dblexp_XOffset, kwCWave=coefWave, sweepData(beginTrail, endTrail); err = getRTError(1)
						endif
						if(!err)
							if(!CmpStr(retWhat, SF_OP_TPFIT_RET_TAULARGE))
								fitResult = max(coefWave[2], coefWave[4])
							elseif(!CmpStr(retWhat, SF_OP_TPFIT_RET_TAUSMALL))
								fitResult = min(coefWave[2], coefWave[4])
							elseif(!CmpStr(retWhat, SF_OP_TPFIT_RET_AMP))
								fitResult = max(abs(coefWave[1]), abs(coefWave[3])) == abs(coefWave[1]) ? coefWave[1] : coefWave[3]
							elseif(!CmpStr(retWhat, SF_OP_TPFIT_RET_MINAMP))
								fitResult = min(abs(coefWave[1]), abs(coefWave[3])) == abs(coefWave[1]) ? coefWave[1] : coefWave[3]
							endif
						endif
					endif
				endif
				fitResults[j] = fitResult
			endfor

#ifdef AUTOMATED_TESTING
			JWN_SetWaveInWaveNote(fitResults, "/begintrails", beginTrails)
			JWN_SetWaveInWaveNote(fitResults, "/endtrails", endTrails)
#endif

			if(!debugMode)
				WAVE/D out = fitResults
				if(!CmpStr(retWhat, SF_OP_TPFIT_RET_AMP) || !CmpStr(retWhat, SF_OP_TPFIT_RET_MINAMP))
					SetScale d, 0, 0, WaveUnits(sweepData, -1), out
				elseif(!CmpStr(retWhat, SF_OP_TPFIT_RET_TAULARGE) || !CmpStr(retWhat, SF_OP_TPFIT_RET_TAUSMALL))
					SetScale d, 0, 0, WaveUnits(sweepData, ROWS), out
				elseif(!CmpStr(retWhat, SF_OP_TPFIT_RET_FITQUALITY))
					SetScale d, 0, 0, "", out
				endif
			endif

		else
			// Use first TP as reference for pulse length and baseline
			epShortName = EP_GetShortName(epochMatches[0][EPOCH_COL_TAGS])
			WAVE/Z/T epochTPPulse = EP_GetEpochs(numericalValues, textualValues, sweepNo, XOP_CHANNEL_TYPE_DAC, dacChannelNr, epShortName + "_P")
			SF_ASSERT(WaveExists(epochTPPulse) && DimSize(epochTPPulse, ROWS) == 1, "No TP Pulse epoch found for TP epoch")
			WAVE/Z/T epochTPBaseline = EP_GetEpochs(numericalValues, textualValues, sweepNo, XOP_CHANNEL_TYPE_DAC, dacChannelNr, epShortName + "_B0")
			SF_ASSERT(WaveExists(epochTPBaseline) && DimSize(epochTPBaseline, ROWS) == 1, "No TP Baseline epoch found for TP epoch")
			tpBaseLinePoints = (str2num(epochTPBaseline[0][EPOCH_COL_ENDTIME]) - str2num(epochTPBaseline[0][EPOCH_COL_STARTTIME])) * ONE_TO_MILLI / DimDelta(sweepData, ROWS)

			// Assemble TP data
			WAVE tpInput.data = SF_AverageTPFromSweep(epochMatches, sweepData)
			tpInput.tpLengthPoints = DimSize(tpInput.data, ROWS)
			tpInput.duration = (str2num(epochTPPulse[0][EPOCH_COL_ENDTIME]) - str2num(epochTPPulse[0][EPOCH_COL_STARTTIME])) * ONE_TO_MILLI / DimDelta(sweepData, ROWS)
			tpInput.baselineFrac =  TP_CalculateBaselineFraction(tpInput.duration, tpInput.duration + 2 * tpBaseLinePoints)

			[WAVE settings, settingsIndex] = GetLastSettingChannel(numericalValues, textualValues, sweepNo, CLAMPMODE_ENTRY_KEY, dacChannelNr, XOP_CHANNEL_TYPE_DAC, DATA_ACQUISITION_MODE)
			SF_ASSERT(WaveExists(settings), "Failed to retrieve TP Clamp Mode from LBN")
			tpInput.clampMode = settings[settingsIndex]

			tpInput.clampAmp = NumberByKey("Amplitude", epochTPPulse[0][EPOCH_COL_TAGS], "=")
			SF_ASSERT(IsFinite(tpInput.clampAmp), "Could not find amplitude entry in epoch tags")

			// values not required for calculation result
			tpInput.device = graph

			DFREF dfrTPAnalysis = TP_PrepareAnalysisDF(graph, tpInput)
			DFREF dfrTPAnalysisInput = dfrTPAnalysis:input
			DFREF dfr = TP_TSAnalysis(dfrTPAnalysisInput)
			WAVE tpOutData = dfr:outData

			// handle waves sent out when TP_ANALYSIS_DEBUGGING is defined
			if(WaveExists(dfr:data) && WaveExists(dfr:colors))
				Duplicate/O dfr:data, root:data/WAVE=data
				Duplicate/O dfr:colors, root:colors/WAVE=colors

				debugGraph = "DebugTPRanges"
				if(!WindowExists(debugGraph))
					Display/N=$debugGraph/K=1
					AppendToGraph/W=$debugGraph data
					ModifyGraph/W=$debugGraph zColor(data)={colors,*,*,Rainbow,1}
				endif
			endif

			strswitch(dataType)
				case SF_DATATYPE_TPSS:
					Make/FREE/D out = {tpOutData[%STEADYSTATERES]}
					SetScale d, 0, 0, "MΩ", out
					break
				case SF_DATATYPE_TPINST:
					Make/FREE/D out = {tpOutData[%INSTANTRES]}
					SetScale d, 0, 0, "MΩ", out
					break
				case SF_DATATYPE_TPBASE:
					Make/FREE/D out = {tpOutData[%BASELINE]}
					SetScale d, 0, 0, baselineUnit, out
					break
				default:
					SF_ASSERT(0, "tp: Unknown type.")
					break
			endswitch

			JWN_SetWaveInWaveNote(out, SF_META_XVALUES, {sweepNo})
		endif

		if(!debugMode)
			JWN_SetNumberInWaveNote(out, SF_META_SWEEPNO, sweepNo)
			JWN_SetNumberInWaveNote(out, SF_META_CHANNELTYPE, chanType)
			JWN_SetNumberInWaveNote(out, SF_META_CHANNELNUMBER, chanNr)

			output[index] = out
			index += 1
		endif
	endfor
	Redimension/N=(index) output

	if(debugMode)
		return output
	endif

	strswitch(dataType)
		case SF_DATATYPE_TPSS:
			yAxisLabel = "steady state resistance"
			xAxisLabel = "Sweeps"
			break
		case SF_DATATYPE_TPINST:
			yAxisLabel = "instantaneous resistance"
			xAxisLabel = "Sweeps"
			break
		case SF_DATATYPE_TPBASE:
			yAxisLabel = "baseline level"
			xAxisLabel = "Sweeps"
			break
		case SF_DATATYPE_TPFIT:
			if(!CmpStr(retWhat, SF_OP_TPFIT_RET_TAULARGE) || !CmpStr(retWhat, SF_OP_TPFIT_RET_TAUSMALL))
				yAxisLabel = "tau"
			elseif(!CmpStr(retWhat, SF_OP_TPFIT_RET_AMP) || !CmpStr(retWhat, SF_OP_TPFIT_RET_MINAMP))
				yAxisLabel = ""
			elseif(!CmpStr(retWhat, SF_OP_TPFIT_RET_FITQUALITY))
				yAxisLabel = "fitQuality"
			endif
			xAxisLabel = "TPs"
			break
		default:
			SF_ASSERT(0, "tp: Unknown mode.")
			break
	endswitch

	JWN_SetStringInWaveNote(output, SF_META_XAXISLABEL, xAxisLabel)
	JWN_SetStringInWaveNote(output, SF_META_YAXISLABEL, yAxisLabel)

	return output
End

// epochs(string shortName[, array selectData, [string type]])
// returns 2xN wave for type = range except for a single range result
static Function/WAVE SF_OperationEpochs(variable jsonId, string jsonPath, string graph)

	variable numArgs, epType

	numArgs = SF_GetNumberOfArguments(jsonID, jsonPath)
	SF_ASSERT(numArgs >= 1 && numArgs <= 3, "epochs requires at least 1 and at most 3 arguments")

	if(numArgs == 3)
		WAVE/T epochType = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_EPOCHS, 2, checkExist=1)
		SF_ASSERT(DimSize(epochType, ROWS) == 1, "Epoch type must be a single value.")
		SF_ASSERT(IsTextWave(epochType), "Epoch type argument must be textual")
		strswitch(epochType[0])
			case SF_OP_EPOCHS_TYPE_RANGE:
				epType = EPOCHS_TYPE_RANGE
				break
			case SF_OP_EPOCHS_TYPE_NAME:
				epType = EPOCHS_TYPE_NAME
				break
			case SF_OP_EPOCHS_TYPE_TREELEVEL:
				epType = EPOCHS_TYPE_TREELEVEL
				break
			default:
				epType = EPOCHS_TYPE_INVALID
				break
		endswitch

		SF_ASSERT(epType != EPOCHS_TYPE_INVALID, "Epoch type must be either " + SF_OP_EPOCHS_TYPE_RANGE + ", " + SF_OP_EPOCHS_TYPE_NAME + " or " + SF_OP_EPOCHS_TYPE_TREELEVEL)
	else
		epType = EPOCHS_TYPE_RANGE
	endif

	if(numArgs >= 2)
		WAVE/Z selectData = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_EPOCHS, 1)
	else
		WAVE/Z selectData = SF_ExecuteFormula("select()", graph, singleResult=1)
	endif
	if(WaveExists(selectData))
		SF_ASSERT(DimSize(selectData, COLS) == 3, "A select input has 3 columns.")
		SF_ASSERT(IsNumericWave(selectData), "select parameter must be numeric")
	endif

	WAVE/T epochName = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_EPOCHS, 0, checkExist=1)
	SF_ASSERT(DimSize(epochName, ROWS) == 1, "Epoch name must be a single string.")
	SF_ASSERT(IsTextWave(epochName), "Epoch name argument must be textual")

	WAVE/WAVE output = SF_OperationEpochsImpl(graph, epochName[0], selectData, epType, SF_OP_EPOCHS)

	return SF_GetOutputForExecutor(output, graph, SF_OP_EPOCHS)
End

Static Function/WAVE SF_OperationEpochsImpl(string graph, string epochName, WAVE/Z selectData, variable epType, string opShort)

	variable i, j, numSelected, sweepNo, chanNr, chanType, index, numEpochs, epIndex, settingsIndex
	string epName, epShortName, epEntry, yAxisLabel

	ASSERT(WindowExists(graph), "graph window does not exist")

	if(!WaveExists(selectData))
		WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, 0)
		JWN_SetStringInWaveNote(output, SF_META_DATATYPE, SF_DATATYPE_EPOCHS)
		return output
	endif

	numSelected = DimSize(selectData, ROWS)
	WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, numSelected)

	if(epType == EPOCHS_TYPE_NAME)
		yAxisLabel = "epoch " + epochName + " name"
	elseif(epType == EPOCHS_TYPE_TREELEVEL)
		yAxisLabel = "epoch " + epochName + " tree level"
	else
		yAxisLabel = "epoch " + epochName + " range"
	endif

	for(i = 0; i < numSelected; i += 1)

		sweepNo = selectData[i][%SWEEP]
		chanNr = selectData[i][%CHANNELNUMBER]
		chanType = selectData[i][%CHANNELTYPE]

		if(!IsValidSweepNumber(sweepNo))
			continue
		endif

		WAVE/Z numericalValues = BSP_GetLogbookWave(graph, LBT_LABNOTEBOOK, LBN_NUMERICAL_VALUES, sweepNumber = sweepNo)
		WAVE/Z textualValues = BSP_GetLogbookWave(graph, LBT_LABNOTEBOOK, LBN_TEXTUAL_VALUES, sweepNumber = sweepNo)
		if(!WaveExists(numericalValues) || !WaveExists(textualValues))
			continue
		endif

		[WAVE settings, settingsIndex] = GetLastSettingChannel(numericalValues, textualValues, sweepNo, EPOCHS_ENTRY_KEY, chanNr, chanType, DATA_ACQUISITION_MODE)
		if(!WaveExists(settings))
			continue
		endif

		WAVE/T settingsT = settings
		epEntry = settingsT[settingsIndex]
		SF_ASSERT(!IsEmpty(epEntry), "Encountered sweep/channel without epoch information.")
		WAVE/T epochInfo = EP_EpochStrToWave(epEntry)
		numEpochs = DimSize(epochInfo, ROWS)
		Make/FREE/T/N=(numEpochs) epNames
		for(j = 0; j < numEpochs; j += 1)
			epName = epochInfo[j][EPOCH_COL_TAGS]
			epShortName = EP_GetShortName(epName)
			epNames[j] = SelectString(IsEmpty(epShortName), epShortName, epName)
		endfor

		FindValue/TXOP=4/TEXT=epochName epNames
		if(V_Row == -1)
			continue
		endif
		epIndex = V_Row

		if(epType == EPOCHS_TYPE_NAME)
			Make/FREE/T wt = {epochInfo[epIndex][EPOCH_COL_TAGS]}
			WAVE out = wt
		elseif(epType == EPOCHS_TYPE_TREELEVEL)
			Make/FREE wv = {str2num(epochInfo[epIndex][EPOCH_COL_TREELEVEL])}
			WAVE out = wv
		else
			Make/FREE wv = {str2num(epochInfo[epIndex][EPOCH_COL_STARTTIME]) * ONE_TO_MILLI, str2num(epochInfo[epIndex][EPOCH_COL_ENDTIME]) * ONE_TO_MILLI}
			WAVE out = wv
		endif

		JWN_SetNumberInWaveNote(out, SF_META_SWEEPNO, sweepNo)
		JWN_SetNumberInWaveNote(out, SF_META_CHANNELTYPE, chanType)
		JWN_SetNumberInWaveNote(out, SF_META_CHANNELNUMBER, chanNr)
		JWN_SetWaveInWaveNote(out, SF_META_XVALUES, {sweepNo})

		output[index] = out
		index +=1
	endfor
	Redimension/N=(index) output

	JWN_SetStringInWaveNote(output, SF_META_DATATYPE, SF_DATATYPE_EPOCHS)
	JWN_SetStringInWaveNote(output, SF_META_XAXISLABEL, "Sweeps")
	JWN_SetStringInWaveNote(output, SF_META_YAXISLABEL, yAxisLabel)

	return output
End

static Function/WAVE SF_OperationMinus(variable jsonId, string jsonPath, string graph)

	WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OPSHORT_MINUS)
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OPSHORT_MINUS, DimSize(input, ROWS))

	output[] = SF_OperationMinusImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OPSHORT_MINUS, "")

	return SF_GetOutputForExecutor(output, graph, SF_OPSHORT_MINUS, clear=input)
End

static Function/WAVE SF_OperationMinusImpl(WAVE/Z wv)

	if(!WaveExists(wv))
		return $""
	endif
	SF_ASSERT(DimSize(wv, ROWS), "Operand for - is empty.")
	SF_ASSERT(IsNumericWave(wv), "Operand for - must be numeric.")
	if(DimSize(wv, ROWS) == 1)
		MatrixOP/FREE out = sumCols((-1) * wv)^t
	else
		MatrixOP/FREE out = (row(wv, 0) + sumCols((-1) * subRange(wv, 1, numRows(wv) - 1, 0, numCols(wv) - 1)))^t
	endif
	SF_FormulaWaveScaleTransfer(wv, out, SF_TRANSFER_ALL_DIMS, NaN)
	SF_FormulaWaveScaleTransfer(wv, out, COLS, ROWS)
	SF_FormulaWaveScaleTransfer(wv, out, LAYERS, COLS)
	SF_FormulaWaveScaleTransfer(wv, out, CHUNKS, LAYERS)
	Redimension/N=(-1, DimSize(out, LAYERS), DimSize(out, CHUNKS), 0)/E=1 out

	return out
End

static Function/WAVE SF_OperationPlus(variable jsonId, string jsonPath, string graph)

	WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OPSHORT_PLUS)
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OPSHORT_PLUS, DimSize(input, ROWS))

	output[] = SF_OperationPlusImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OPSHORT_PLUS, "")

	return SF_GetOutputForExecutor(output, graph, SF_OPSHORT_PLUS, clear=input)
End

static Function/WAVE SF_OperationPlusImpl(WAVE/Z wv)

	if(!WaveExists(wv))
		return $""
	endif
	SF_ASSERT(DimSize(wv, ROWS), "Operand for + is empty.")
	SF_ASSERT(IsNumericWave(wv), "Operand for + must be numeric.")
	MatrixOP/FREE out = sumCols(wv)^t
	SF_FormulaWaveScaleTransfer(wv, out, SF_TRANSFER_ALL_DIMS, NaN)
	SF_FormulaWaveScaleTransfer(wv, out, COLS, ROWS)
	SF_FormulaWaveScaleTransfer(wv, out, LAYERS, COLS)
	SF_FormulaWaveScaleTransfer(wv, out, CHUNKS, LAYERS)
	Redimension/N=(-1, DimSize(out, LAYERS), DimSize(out, CHUNKS), 0)/E=1 out

	return out
End

static Function/WAVE SF_OperationDiv(variable jsonId, string jsonPath, string graph)

	WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OPSHORT_DIV)
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OPSHORT_DIV, DimSize(input, ROWS))

	output[] = SF_OperationDivImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OPSHORT_DIV, "")

	return SF_GetOutputForExecutor(output, graph, SF_OPSHORT_DIV, clear=input)
End

static Function/WAVE SF_OperationDivImpl(WAVE/Z wv)

	if(!WaveExists(wv))
		return $""
	endif
	SF_ASSERT(IsNumericWave(wv), "Operand for / must be numeric.")
	SF_ASSERT(DimSize(wv, ROWS) >= 2, "At least two operands are required")
	MatrixOP/FREE out = (row(wv, 0) / productCols(subRange(wv, 1, numRows(wv) - 1, 0, numCols(wv) - 1)))^t
	SF_FormulaWaveScaleTransfer(wv, out, SF_TRANSFER_ALL_DIMS, NaN)
	SF_FormulaWaveScaleTransfer(wv, out, COLS, ROWS)
	SF_FormulaWaveScaleTransfer(wv, out, LAYERS, COLS)
	SF_FormulaWaveScaleTransfer(wv, out, CHUNKS, LAYERS)
	Redimension/N=(-1, DimSize(out, LAYERS), DimSize(out, CHUNKS), 0)/E=1 out

	return out
End

static Function/WAVE SF_OperationMult(variable jsonId, string jsonPath, string graph)

	WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OPSHORT_MULT)
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OPSHORT_MULT, DimSize(input, ROWS))

	output[] = SF_OperationMultImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OPSHORT_MULT, "")

	return SF_GetOutputForExecutor(output, graph, SF_OPSHORT_MULT, clear=input)
End

static Function/WAVE SF_OperationMultImpl(WAVE/Z wv)

	if(!WaveExists(wv))
		return $""
	endif
	SF_ASSERT(DimSize(wv, ROWS), "Operand for * is empty.")
	SF_ASSERT(IsNumericWave(wv), "Operand for * must be numeric.")
	MatrixOP/FREE out = productCols(wv)^t
	SF_FormulaWaveScaleTransfer(wv, out, SF_TRANSFER_ALL_DIMS, NaN)
	SF_FormulaWaveScaleTransfer(wv, out, COLS, ROWS)
	SF_FormulaWaveScaleTransfer(wv, out, LAYERS, COLS)
	SF_FormulaWaveScaleTransfer(wv, out, CHUNKS, LAYERS)
	Redimension/N=(-1, DimSize(out, LAYERS), DimSize(out, CHUNKS), 0)/E=1 out

	return out
End

/// range (start[, stop[, step]])
static Function/WAVE SF_OperationRange(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_RANGE)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_RANGE, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_RANGE, DimSize(input, ROWS))

	output[] = SF_OperationRangeImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_RANGE, SF_DATATYPE_RANGE)

	return SF_GetOutputForExecutor(output, graph, SF_OP_RANGE, clear=input)
End

static Function/WAVE SF_OperationRangeImpl(WAVE/Z input)

	variable numArgs

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "range requires numeric data as input")
	SF_ASSERT(WaveDims(input) == 1, "range requires 1d data input.")
	numArgs = DimSize(input, ROWS)
	if(numArgs == 3)
		Make/N=(ceil(abs((input[0] - input[1]) / input[2])))/FREE range
		Multithread range[] = input[0] + p * input[2]
	elseif(numArgs == 2)
		Make/N=(abs(trunc(input[0])-trunc(input[1])))/FREE range
		Multithread range[] = input[0] + p
	elseif(numArgs == 1)
		Make/N=(abs(trunc(input[0])))/FREE range
		Multithread range[] = p
	else
		SF_ASSERT(0, "range accepts 1-3 args per specification")
	endif

	return range
End

static Function/WAVE SF_OperationMin(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs > 0, "min requires at least one argument")
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_MIN)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_MIN, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_MIN, DimSize(input, ROWS))

	output[] = SF_OperationMinImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_MIN, SF_DATATYPE_MIN)

	return SF_GetOutputForExecutor(output, graph, SF_OP_MIN, clear=input)
End

static Function/WAVE SF_OperationMinImpl(WAVE/Z input)

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "min requires numeric data as input")
	SF_ASSERT(WaveDims(input) <= 2, "min accepts only upto 2d data")
	SF_ASSERT(DimSize(input, ROWS) > 0, "min requires at least one data point")
	MatrixOP/FREE out = minCols(input)^t
	CopyScales input, out
	SetScale/P x, DimOffset(out, ROWS), DimDelta(out, ROWS), "", out

	SF_FormulaWaveScaleTransfer(input, out, COLS, ROWS)

	return out
End

static Function/WAVE SF_OperationMax(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs > 0, "max requires at least one argument")
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_MAX)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_MAX, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_MAX, DimSize(input, ROWS))

	output[] = SF_OperationMaxImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_MAX, SF_DATATYPE_MAX)

	return SF_GetOutputForExecutor(output, graph, SF_OP_MAX, clear=input)
End

static Function/WAVE SF_OperationMaxImpl(WAVE/Z input)

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "max requires numeric data as input")
	SF_ASSERT(WaveDims(input) <= 2, "max accepts only upto 2d data")
	SF_ASSERT(DimSize(input, ROWS) > 0, "max requires at least one data point")
	MatrixOP/FREE out = maxCols(input)^t
	CopyScales input, out
	SetScale/P x, DimOffset(out, ROWS), DimDelta(out, ROWS), "", out
	SF_FormulaWaveScaleTransfer(input, out, COLS, ROWS)

	return out
End

static Function/WAVE SF_OperationAvg(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs > 0, "avg requires at least one argument")
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_AVG)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_AVG, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_AVG, DimSize(input, ROWS))

	output[] = SF_OperationAvgImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_AVG, SF_DATATYPE_AVG)

	return SF_GetOutputForExecutor(output, graph, SF_OP_AVG, clear=input)
End

// averages each column, 1d waves are treated like 1 column (n,1)
static Function/WAVE SF_OperationAvgImpl(WAVE/Z input)

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "avg requires numeric data as input")
	SF_ASSERT(WaveDims(input) <= 2, "avg accepts only upto 2d data")
	SF_ASSERT(DimSize(input, ROWS) > 0, "avg requires at least one data point")
	MatrixOP/FREE out = averageCols(input)^t
	CopyScales input, out
	SetScale/P x, DimOffset(out, ROWS), DimDelta(out, ROWS), "", out
	SF_FormulaWaveScaleTransfer(input, out, COLS, ROWS)

	return out
End

static Function/WAVE SF_OperationRMS(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs > 0, "rms requires at least one argument")
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_RMS)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_RMS, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_RMS, DimSize(input, ROWS))

	output[] = SF_OperationRMSImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_RMS, SF_DATATYPE_RMS)

	return SF_GetOutputForExecutor(output, graph, SF_OP_RMS, clear=input)
End

static Function/WAVE SF_OperationRMSImpl(WAVE/Z input)

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "rms requires numeric data as input")
	SF_ASSERT(WaveDims(input) <= 2, "rms accepts only upto 2d data")
	SF_ASSERT(DimSize(input, ROWS) > 0, "rms requires at least one data point")
	MatrixOP/FREE out = sqrt(averageCols(magsqr(input)))^t
	SF_FormulaWaveScaleTransfer(input, out, COLS, ROWS)

	return out
End

static Function/WAVE SF_OperationVariance(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs > 0, "variance requires at least one argument")
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_VARIANCE)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_VARIANCE, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_VARIANCE, DimSize(input, ROWS))

	output[] = SF_OperationVarianceImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_VARIANCE, SF_DATATYPE_VARIANCE)

	return SF_GetOutputForExecutor(output, graph, SF_OP_VARIANCE, clear=input)
End

static Function/WAVE SF_OperationVarianceImpl(WAVE/Z input)

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "variance requires numeric data as input")
	SF_ASSERT(WaveDims(input) <= 2, "variance accepts only upto 2d data")
	SF_ASSERT(DimSize(input, ROWS) > 0, "variance requires at least one data point")
	MatrixOP/FREE out = (sumCols(magSqr(input - rowRepeat(averageCols(input), numRows(input))))/(numRows(input) - 1))^t
	SF_FormulaWaveScaleTransfer(input, out, COLS, ROWS)

	return out
End

static Function/WAVE SF_OperationStdev(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs > 0, "stdev requires at least one argument")
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_STDEV)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_STDEV, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_STDEV, DimSize(input, ROWS))

	output[] = SF_OperationStdevImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_STDEV, SF_DATATYPE_STDEV)

	return SF_GetOutputForExecutor(output, graph, SF_OP_STDEV, clear=input)
End

static Function/WAVE SF_OperationStdevImpl(WAVE/Z input)

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "stdev requires numeric data as input")
	SF_ASSERT(WaveDims(input) <= 2, "stdev accepts only upto 2d data")
	SF_ASSERT(DimSize(input, ROWS) > 0, "stdev requires at least one data point")
	MatrixOP/FREE out = (sqrt(sumCols(powR(input - rowRepeat(averageCols(input), numRows(input)), 2))/(numRows(input) - 1)))^t
	SF_FormulaWaveScaleTransfer(input, out, COLS, ROWS)

	return out
End

static Function/WAVE SF_OperationDerivative(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_DERIVATIVE)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_DERIVATIVE, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_DERIVATIVE, DimSize(input, ROWS))

	output[] = SF_OperationDerivativeImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_DERIVATIVE, SF_DATATYPE_DERIVATIVE)

	return SF_GetOutputForExecutor(output, graph, SF_OP_DERIVATIVE, clear=input)
End

static Function/WAVE SF_OperationDerivativeImpl(WAVE/Z input)

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "derivative requires numeric input data.")
	SF_ASSERT(DimSize(input, ROWS) > 1, "Can not differentiate single point waves")
	WAVE out = NewFreeWave(IGOR_TYPE_64BIT_FLOAT, 0)
	Differentiate/DIM=(ROWS) input/D=out
	CopyScales input, out
	SetScale/P x, DimOffset(out, ROWS), DimDelta(out, ROWS), "d/dx", out

	return out
End

static Function/WAVE SF_OperationIntegrate(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_INTEGRATE)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_INTEGRATE, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_INTEGRATE, DimSize(input, ROWS))

	output[] = SF_OperationIntegrateImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_INTEGRATE, SF_DATATYPE_INTEGRATE)

	return SF_GetOutputForExecutor(output, graph, SF_OP_INTEGRATE, clear=input)
End

static Function/WAVE SF_OperationIntegrateImpl(WAVE/Z input)

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "integrate requires numeric input data.")
	SF_ASSERT(DimSize(input, ROWS) > 0, "integrate input must have at least one data point")
	WAVE out = NewFreeWave(IGOR_TYPE_64BIT_FLOAT, 0)
	Integrate/METH=1/DIM=(ROWS) input/D=out
	CopyScales input, out
	SetScale/P x, DimOffset(out, ROWS), DimDelta(out, ROWS), "dx", out

	return out
End

static Function/WAVE SF_OperationArea(variable jsonId, string jsonPath, string graph)

	variable zero, numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs >= 1, "area requires at least one argument.")
	SF_ASSERT(numArgs <= 2, "area requires at most two arguments.")

	WAVE/WAVE input = SF_GetArgument(jsonID, jsonPath, graph, SF_OP_AREA, 0)

	zero = 1
	if(numArgs == 2)
		WAVE zeroWave = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_AREA, 1, checkExist=1)
		SF_ASSERT(DimSize(zeroWave, ROWS) == 1, "Too many input values for parameter zero")
		SF_ASSERT(IsNumericWave(zeroWave), "zero parameter must be numeric")
		zero = !!zeroWave[0]
	endif

	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_AREA, DimSize(input, ROWS))

	output[] = SF_OperationAreaImpl(input[p], zero)

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_AREA, SF_DATATYPE_AREA)

	return SF_GetOutputForExecutor(output, graph, SF_OP_AREA, clear=input)
End

static Function/WAVE SF_OperationAreaImpl(WAVE/Z input, variable zero)

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "area requires numeric input data.")
	if(zero)
		SF_ASSERT(DimSize(input, ROWS) >= 3, "Requires at least three points of data.")
		Differentiate/DIM=(ROWS)/EP=1 input
		Integrate/DIM=(ROWS) input
	endif
	SF_ASSERT(DimSize(input, ROWS) >= 1, "integrate requires at least one data point.")

	WAVE out_integrate = NewFreeWave(IGOR_TYPE_64BIT_FLOAT, 0)
	Integrate/METH=1/DIM=(ROWS) input/D=out_integrate
	Make/FREE/N=(max(1, DimSize(out_integrate, COLS)), DimSize(out_integrate, LAYERS)) out
	Multithread out = out_integrate[DimSize(input, ROWS) - 1][p][q]

	return out
End

/// `butterworth(data, lowPassCutoff, highPassCutoff, order)`
static Function/WAVE SF_OperationButterworth(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs == 4, "The butterworth filter requires 4 arguments")

	WAVE/WAVE input = SF_GetArgument(jsonID, jsonPath, graph, SF_OP_BUTTERWORTH, 0)
	WAVE lowPassCutoff = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_BUTTERWORTH, 1, checkExist=1)
	SF_ASSERT(DimSize(lowPassCutoff, ROWS) == 1, "Too many input values for parameter lowPassCutoff")
	SF_ASSERT(IsNumericWave(lowPassCutoff), "lowPassCutoff parameter must be numeric")
	WAVE highPassCutoff = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_BUTTERWORTH, 2, checkExist=1)
	SF_ASSERT(DimSize(highPassCutoff, ROWS) == 1, "Too many input values for parameter highPassCutoff")
	SF_ASSERT(IsNumericWave(highPassCutoff), "highPassCutoff parameter must be numeric")
	WAVE order = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_BUTTERWORTH, 3, checkExist=1)
	SF_ASSERT(DimSize(order, ROWS) == 1, "Too many input values for parameter order")
	SF_ASSERT(IsNumericWave(order), "order parameter must be numeric")

	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_BUTTERWORTH, DimSize(input, ROWS))

	output[] = SF_OperationButterworthImpl(input[p], lowPassCutoff[0], highPassCutoff[0], order[0])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_BUTTERWORTH, SF_DATATYPE_BUTTERWORTH)

	return SF_GetOutputForExecutor(output, graph, SF_OP_BUTTERWORTH, clear=input)
End

static Function/WAVE SF_OperationButterworthImpl(WAVE/Z input, variable lowPassCutoff, variable highPassCutoff, variable order)

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "butterworth requires numeric input data.")
	FilterIIR/HI=(highPassCutoff / WAVEBUILDER_MIN_SAMPINT_HZ)/LO=(lowPassCutoff / WAVEBUILDER_MIN_SAMPINT_HZ)/ORD=(order)/DIM=(ROWS) input
	SF_ASSERT(V_flag == 0, "FilterIIR returned error")

	return input
End

static Function/WAVE SF_OperationXValues(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs > 0, "xvalues requires at least one argument.")
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_XVALUES)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_XVALUES, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_XVALUES, DimSize(input, ROWS))

	output[] = SF_OperationXValuesImpl(input[p])

	return SF_GetOutputForExecutor(output, graph, SF_OP_XVALUES, clear=input)
End

static Function/WAVE SF_OperationXValuesImpl(WAVE/Z input)

	variable offset, delta

	if(!WaveExists(input))
		return $""
	endif

	Make/FREE/D/N=(DimSize(input, ROWS), DimSize(input, COLS), DimSize(input, LAYERS), DimSize(input, CHUNKS)) output
	offset =DimOffset(input, ROWS)
	delta = DimDelta(input, ROWS)
	Multithread output = offset + p * delta

	return output
End

static Function/WAVE SF_OperationText(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs > 0, "text requires at least one argument.")
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_TEXT)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_TEXT, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_TEXT, DimSize(input, ROWS))

	output[] = SF_OperationTextImpl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_TEXT, JWN_GetStringFromWaveNote(input, SF_META_DATATYPE))

	return SF_GetOutputForExecutor(output, graph, SF_OP_TEXT, clear=input)
End

static Function/WAVE SF_OperationTextImpl(WAVE/Z input)

	if(!WaveExists(input))
		return $""
	endif

	SF_ASSERT(IsNumericWave(input), "text requires numeric input data.")
	Make/FREE/T/N=(DimSize(input, ROWS), DimSize(input, COLS), DimSize(input, LAYERS), DimSize(input, CHUNKS)) output
	Multithread output = num2strHighPrec(input[p][q][r][s], precision=7)
	CopyScales input, output

	return output
End

/// `setscale(data, dim, [dimOffset, [dimDelta[, unit]]])`
static Function/WAVE SF_OperationSetScale(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs < 6, "Maximum number of arguments exceeded.")
	SF_ASSERT(numArgs > 1, "At least two arguments.")
	WAVE/WAVE dataRef = SF_GetArgument(jsonID, jsonPath, graph, SF_OP_SETSCALE, 0)
	WAVE/T dimension = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_SETSCALE, 1, checkExist=1)
	SF_ASSERT(IsTextWave(dimension), "Expected d, x, y, z or t as dimension.")
	SF_ASSERT(DimSize(dimension, ROWS) == 1 && GrepString(dimension[0], "[d,x,y,z,t]") , "undefined input for dimension")

	if(numArgs >= 3)
		WAVE offset = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_SETSCALE, 2, checkExist=1)
		SF_ASSERT(IsNumericWave(offset) && DimSize(offset, ROWS) == 1, "Expected a number as offset.")
	else
		Make/FREE/N=1 offset  = {0}
	endif
	if(numArgs >= 4)
		WAVE delta = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_SETSCALE, 3, checkExist=1)
		SF_ASSERT(IsNumericWave(delta) && DimSize(delta, ROWS) == 1, "Expected a number as delta.")
	else
		Make/FREE/N=1 delta = {1}
	endif
	if(numArgs == 5)
		WAVE/T unit = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_SETSCALE, 4, checkExist=1)
		SF_ASSERT(IsTextWave(unit) && DimSize(unit, ROWS) == 1, "Expected a string as unit.")
	else
		Make/FREE/N=1/T unit = {""}
	endif

	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_SETSCALE, DimSize(dataRef, ROWS))

	output[] = SF_OperationSetScaleImpl(dataRef[p], dimension[0], offset[0], delta[0], unit[0])

	return SF_GetOutputForExecutor(output, graph, SF_OP_SETSCALE, clear=dataRef)
End

static Function/WAVE SF_OperationSetScaleImpl(WAVE/Z input, string dim, variable offset, variable delta, string unit)

	if(!WaveExists(input))
		return $""
	endif

	if(CmpStr(dim, "d") && delta == 0)
		delta = 1
	endif

	strswitch(dim)
		case "d":
			SetScale d, offset, delta, unit, input
			break
		case "x":
			SetScale/P x, offset, delta, unit, input
			ASSERT(DimDelta(input, ROWS) == delta, "Encountered Igor Bug.")
			break
		case "y":
			SetScale/P y, offset, delta, unit, input
			ASSERT(DimDelta(input, COLS) == delta, "Encountered Igor Bug.")
			break
		case "z":
			SetScale/P z, offset, delta, unit, input
			ASSERT(DimDelta(input, LAYERS) == delta, "Encountered Igor Bug.")
			break
		case "t":
			SetScale/P t, offset, delta, unit, input
			ASSERT(DimDelta(input, CHUNKS) == delta, "Encountered Igor Bug.")
			break
	endswitch

	return input
End

static Function/WAVE SF_OperationWave(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs == 1, "wave expects exactly one argument.")
	WAVE/T wavelocation = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_WAVE, 0, checkExist=1)
	SF_ASSERT(IsTextWave(waveLocation), "First argument must be textual.")

	WAVE/Z output = $(wavelocation[0])

	return SF_GetOutputForExecutorSingle(output, graph, SF_OP_WAVE, opStack="")
End

/// `channels([str name]+)` converts a named channel from string to numbers.
///
/// returns [[channelName, channelNumber]+]
static Function/WAVE SF_OperationChannels(variable jsonId, string jsonPath, string graph)

	variable numArgs, i, channelType
	string channelName, channelNumber
	string regExp = "^(?i)(" + ReplaceString(";", XOP_CHANNEL_NAMES, "|") + ")([0-9]+)?$"

	SF_ASSERT(!IsEmpty(graph), "Graph not specified.")
	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	WAVE channels = SF_NewChannelsWave(numArgs ? numArgs : 1)
	for(i = 0; i < numArgs; i += 1)
		WAVE chanSpec = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_CHANNELS, i, checkExist=1)
		channelName = ""
		if(IsNumericWave(chanSpec))
			channels[i][%channelNumber] = chanSpec[0]
		elseif(IsTextWave(chanSpec))
			WAVE/T chanSpecT = chanSpec
			SplitString/E=regExp chanSpecT[0], channelName, channelNumber
			if(V_flag == 0)
				SF_ASSERT(0, "Unknown channel: " + chanSpecT[0])
			endif
			channels[i][%channelNumber] = str2num(channelNumber)
		else
			SF_ASSERT(0, "Unsupported arg type for channels.")
		endif
		SF_ASSERT(!isFinite(channels[i][%channelNumber]) || channels[i][%channelNumber] < NUM_MAX_CHANNELS, "Maximum Number Of Channels exceeded.")
		if(!IsEmpty(channelName))
			channelType = WhichListItem(channelName, XOP_CHANNEL_NAMES, ";", 0, 0)
			if(channelType >= 0)
				channels[i][%channelType] = channelType
			endif
		endif
	endfor

	return SF_GetOutputForExecutorSingle(channels, graph, SF_OP_CHANNELS, opStack="")
End

/// `sweeps()`
/// returns all possible sweeps as 1d array
static Function/WAVE SF_OperationSweeps(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs == 0, "Sweep function takes no arguments.")
	SF_ASSERT(!IsEmpty(graph), "Graph not specified.")

	WAVE/Z sweeps = OVS_GetSelectedSweeps(graph, OVS_SWEEP_ALL_SWEEPNO)

	return SF_GetOutputForExecutorSingle(sweeps, graph, SF_OP_SWEEPS, opStack="")
End

static Function/WAVE SF_OperationPowerSpectrum(variable jsonId, string jsonPath, string graph)

	variable i, numArgs, doAvg, debugVal
	string errMsg
	string avg = SF_POWERSPECTRUM_AVG_OFF
	string unit = SF_POWERSPECTRUM_UNIT_DEFAULT
	string winFunc = FFT_WINF_DEFAULT
	variable cutoff = 1000
	variable ratioFreq

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	SF_ASSERT(numArgs >= 1 && numArgs <= 6, "The powerspectrum operation requires 1 to 6 arguments")

	WAVE/WAVE input = SF_GetArgument(jsonID, jsonPath, graph, SF_OP_POWERSPECTRUM, 0)
	if(numArgs > 1)
		WAVE/T wUnit = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_POWERSPECTRUM, 1, checkExist=1)
		sprintf errMsg, "Second argument (unit) can not be a number. Use %s, %s or %s.", SF_POWERSPECTRUM_UNIT_DEFAULT, SF_POWERSPECTRUM_UNIT_DB, SF_POWERSPECTRUM_UNIT_NORMALIZED
		SF_ASSERT(IsTextWave(wUnit), errMsg)
		SF_ASSERT(!DimSize(wUnit, COLS) && DimSize(wUnit, ROWS) == 1, "Second argument (unit) must not be an array with multiple options.")
		unit = wUnit[0]
		sprintf errMsg, "Second argument (unit) must be %s, %s or %s.", SF_POWERSPECTRUM_UNIT_DEFAULT, SF_POWERSPECTRUM_UNIT_DB, SF_POWERSPECTRUM_UNIT_NORMALIZED
		SF_ASSERT(!CmpStr(unit, SF_POWERSPECTRUM_UNIT_DEFAULT) || !CmpStr(unit, SF_POWERSPECTRUM_UNIT_DB) || !CmpStr(unit, SF_POWERSPECTRUM_UNIT_NORMALIZED), errMsg)
	endif
	if(numArgs > 2)
		WAVE/T wAvg = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_POWERSPECTRUM, 2, checkExist=1)
		sprintf errMsg, "Third argument (avg) can not be a number. Use %s or %s.", SF_POWERSPECTRUM_AVG_ON, SF_POWERSPECTRUM_AVG_OFF
		SF_ASSERT(IsTextWave(wAvg), errMsg)
		SF_ASSERT(!DimSize(wAvg, COLS) && DimSize(wAvg, ROWS) == 1, "Third argument (avg) must not be an array with multiple options.")
		avg = wAvg[0]
		sprintf errMsg, "Third argument (avg) must be %s or %s.", SF_POWERSPECTRUM_AVG_ON, SF_POWERSPECTRUM_AVG_OFF
		SF_ASSERT(!CmpStr(avg, SF_POWERSPECTRUM_AVG_ON) || !CmpStr(avg, SF_POWERSPECTRUM_AVG_OFF), errMsg)
	endif
	if(numArgs > 3)
		WAVE wRatioFreq = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_POWERSPECTRUM, 3, checkExist=1)
		SF_ASSERT(IsNumericWave(wRatioFreq), "Fourth argument (frequency for ratio) must be a number.")
		SF_ASSERT(!DimSize(wRatioFreq, COLS) && DimSize(wRatioFreq, ROWS) == 1, "Fourth argument (frequency for ratio) must not be an array with multiple options.")
		ratioFreq = wRatioFreq[0]
		sprintf errMsg, "Fourth argument (Frequency for ratio) must >= %f.", 0
		SF_ASSERT(ratioFreq >= 0, errMsg)
	endif
	if(numArgs > 4)
		WAVE wCutoff = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_POWERSPECTRUM, 4, checkExist=1)
		SF_ASSERT(IsNumericWave(wCutoff), "Fifth argument (cutoff frequency) must be a number.")
		SF_ASSERT(!DimSize(wCutoff, COLS) && DimSize(wCutoff, ROWS) == 1, "Fifth argument (cutoff frequency) must not be an array with multiple options.")
		cutoff = wCutoff[0]
		SF_ASSERT(cutoff > 0, "Fifth argument (cutoff frequency) must be > 0.")
	endif
	if(numArgs > 5)
		WAVE/T wWinf = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_POWERSPECTRUM, 5, checkExist=1)
		SF_ASSERT(IsTextWave(wWinf), "Sixth argument (window function) can not be a number.")
		SF_ASSERT(!DimSize(wWinf, COLS) && DimSize(wWinf, ROWS) == 1, "Sixth argument (window function) must not be an array with multiple options.")
		winFunc = wWinf[0]
		SF_ASSERT(WhichListItem(winFunc, FFT_WINF) >= 0 || !CmpStr(winFunc, SF_POWERSPECTRUM_WINFUNC_NONE), "Sixth argument (window function) is invalid.")
		if(!CmpStr(winFunc, SF_POWERSPECTRUM_WINFUNC_NONE))
			winFunc = ""
		endif
	endif

	for(data : input)
		if(!WaveExists(data))
			continue
		endif
		SF_ASSERT(IsNumericWave(data), "powerspectrum requires numeric input data.")
	endfor
	Make/FREE/N=(DimSize(input, ROWS)) indexHelper
	MultiThread indexHelper[] = SF_RemoveEndOfSweepNaNs(input[p])

	doAvg = !CmpStr(avg, "avg")
	cutOff = ratioFreq == 0 ? cutOff : NaN

	if(doAvg)
		Make/FREE/WAVE/N=(DimSize(input, ROWS)) output
	else
		WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_POWERSPECTRUM, DimSize(input, ROWS))
	endif

	MultiThread output[] = SF_OperationPowerSpectrumImpl(input[p], unit, cutoff, winFunc)

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_POWERSPECTRUM, SF_DATATYPE_POWERSPECTRUM)

	if(doAvg)
		WAVE/WAVE outputAvg = SF_AverageDataOverSweeps(output)
		WAVE/WAVE outputAvgPS = SF_CreateSFRefWave(graph, SF_OP_POWERSPECTRUM, DimSize(outputAvg, ROWS))
		JWN_SetStringInWaveNote(outputAvgPS, SF_META_DATATYPE, SF_DATATYPE_POWERSPECTRUM)
		JWN_SetStringInWaveNote(outputAvgPS, SF_META_OPSTACK, JWN_GetStringFromWaveNote(output, SF_META_OPSTACK))
		outputAvgPS[] = outputAvg[p]
		WAVE/WAVE output = outputAvgPS
	endif

	if(ratioFreq)
		Duplicate/FREE/WAVE output, inputRatio
#ifdef DEBUGGING_ENABLED
		if(DP_DebuggingEnabledForCaller())
			debugVal = DimSize(output, ROWS)
			Redimension/N=(debugVal * 2) output, inputRatio
			for(i = 0; i < debugVal; i += 1)
				Duplicate/FREE inputRatio[i], wv
				inputRatio[debugVal + i] = wv
			endfor
			output[0, debugVal - 1] = SF_PowerSpectrumRatio(inputRatio[p], ratioFreq, SF_POWERSPECTRUM_RATIO_DELTAHZ, fitData=inputRatio[p + debugVal])
			output[debugVal,] = inputRatio[p]
		endif
#else
		output[] = SF_PowerSpectrumRatio(inputRatio[p], ratioFreq, SF_POWERSPECTRUM_RATIO_DELTAHZ)
#endif
	endif

	return SF_GetOutputForExecutor(output, graph, SF_OP_POWERSPECTRUM, clear=input)
End

static Function/WAVE SF_PowerSpectrumRatio(WAVE/Z input, variable ratioFreq, variable deltaHz[, WAVE fitData])

	string sLeft, sRight, maxSigma, minAmp
	variable err, left, right, minFreq, maxFreq, endFreq, base

	if(!WaveExists(input))
		return $""
	endif

	endFreq = IndexToScale(input, DimSize(input, ROWS) - SF_POWERSPECTRUM_RATIO_GAUSS_NUMCOEFS - 1, ROWS)
	ratioFreq = limit(ratioFreq, 0, endFreq)
	minFreq = limit(ratioFreq - deltaHz, 0, endFreq)
	maxFreq = limit(ratioFreq + deltaHz, 0, endFreq)

	Make/FREE/D wCoef = {0, 0, 1, ratioFreq, SF_POWERSPECTRUM_RATIO_MAXFWHM * SF_POWERSPECTRUM_RATIO_GAUSS_SIGMA2FWHM}

	left = ratioFreq - SF_POWERSPECTRUM_RATIO_EPSILONHZ
	right = ratioFreq + SF_POWERSPECTRUM_RATIO_EPSILONHZ
	sLeft = "K3 > " + num2str(left, "%.2f")
	sRight = "K3 < " + num2str(right, "%.2f")
	maxSigma = "K4 < " + num2str(SF_POWERSPECTRUM_RATIO_MAXFWHM / SF_POWERSPECTRUM_RATIO_GAUSS_SIGMA2FWHM, "%f")
	minAmp = "K2 >= 0"
	Make/FREE/T wConstraints = {minAmp, sLeft, sRight, maxSigma}

	AssertOnAndClearRTError()
#ifdef DEBUGGING_ENABLED
	if(DP_DebuggingEnabledForCaller())
		FuncFit/Q SF_LineNoiseFit, kwCWave=wCoef, input(minFreq, maxFreq)/C=wConstraints/D=fitData; err = GetRTError(1)
		Duplicate/FREE/R=(minFreq, maxFreq) fitData, fitDataRanged
		Redimension/N=(DimSize(fitDataRanged, ROWS)) fitData
		CopyScales/P fitDataRanged, fitData
		if(err)
			FastOp fitData = (NaN)
		else
			fitData[] = fitDataRanged[p]
		endif
	endif
#else
	FuncFit/Q SF_LineNoiseFit, kwCWave=wCoef, input(minFreq, maxFreq)/C=wConstraints; err = GetRTError(1)
#endif
	Redimension/N=1 input
	input[0] = 0
#ifdef DEBUGGING_ENABLED
	if(DP_DebuggingEnabledForCaller())
		SetScale/P x, ratioFreq, 1, WaveUnits(input, ROWS), input
	endif
#else
	SetScale/P x, wCoef[3], 1, WaveUnits(input, ROWS), input
#endif
	SetScale/P d, 0, 1, "power ratio", input

	if(err)
		return input
	endif

	base = wCoef[0] + wCoef[1] * wCoef[3]
	left -= SF_POWERSPECTRUM_RATIO_EPSILONPOSFIT
	right += SF_POWERSPECTRUM_RATIO_EPSILONPOSFIT
	if(base <= 0 || wCoef[3] < left || wCoef[3] > right || wCoef[2] < 0)
		return input
	endif

	input[0] = (wCoef[2] + base) / base
#ifdef DEBUGGING_ENABLED
	if(DP_DebuggingEnabledForCaller())
		printf "PS ratio, peak position, baseline, peak amplitude : %f %f %f %f\r", input[0], wCoef[3], base, wCoef[2]
	endif
#endif
	return input
End

Function SF_LineNoiseFit(WAVE w, variable x) : FitFunc
	// Formula: linear + gauss fit
	// y0 + m * x + A * exp(-((x - x0) / sigma)^2)
	// Coefficients:
	// 0: offset, y0
	// 1: slope, m
	// 2: amplitude, A
	// 3: peak position, x0
	// 4: sigma, sigma
	return w[0] + w[1] * x + w[2] * exp(-((x - w[3]) / w[4])^2)
End

threadsafe static Function/WAVE SF_OperationPowerSpectrumImpl(WAVE/Z input, string unit, variable cutoff, string winFunc)

	variable size, m

	if(!WaveExists(input))
		return $""
	endif

	if(!IsFloatingPointWave(input))
		Redimension/D input
	endif

	ZeroWaveImpl(input)

	if(!CmpStr(WaveUnits(input, ROWS), "ms"))
		SetScale/P x, DimOffset(input, ROWS) * MILLI_TO_ONE, DimDelta(input, ROWS) * MILLI_TO_ONE, "s", input
	endif

	if(IsEmpty(winFunc))
		WAVE wFFT = DoFFT(input)
	else
		WAVE wFFT = DoFFT(input, winFunc=winFunc)
	endif
	size = IsNaN(cutOff) ? DimSize(wFFT, ROWS) : min(ScaleToIndex(wFFT, cutoff, ROWS), DimSize(wFFT, ROWS))

	Make/FREE/N=(size) output
	CopyScales/P wFFT, output
	if(!CmpStr(unit, SF_POWERSPECTRUM_UNIT_DEFAULT))
		MultiThread output[] = magsqr(wFFT[p])
		SetScale/I y, 0, 1, WaveUnits(input, -1) + "^2", output
	elseif(!CmpStr(unit, SF_POWERSPECTRUM_UNIT_DB))
		MultiThread output[] = 10 * log(magsqr(wFFT[p]))
		SetScale/I y, 0, 1, "dB", output
	elseif(!CmpStr(unit, SF_POWERSPECTRUM_UNIT_NORMALIZED))
		MultiThread output[] = magsqr(wFFT[p])
		m = mean(output)
		MultiThread output[] = output[p] / m
		SetScale/I y, 0, 1, "mean(" + WaveUnits(input, -1) + "^2)", output
	endif

	return output
End

/// `select([array channels, array sweeps, [string mode, [string clamp]]])`
///
/// returns n x 3 with columns [sweepNr][channelType][channelNr]
static Function/WAVE SF_OperationSelect(variable jsonId, string jsonPath, string graph)

	variable numArgs
	string clamp
	string mode = "displayed"
	variable clampMode = SF_OP_SELECT_CLAMPCODE_ALL

	SF_ASSERT(!IsEmpty(graph), "Graph for extracting sweeps not specified.")

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	if(!numArgs)
		WAVE channels = SF_ExecuteFormula("channels()", graph, singleResult=1, checkExist=1)
		WAVE/Z sweeps = SF_ExecuteFormula("sweeps()", graph, singleResult=1)
	else
		SF_ASSERT(numArgs >= 2 && numArgs <= 4, "Function requires None, 2 or 3 arguments.")
		WAVE channels = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_SELECT, 0, checkExist=1)
		SF_ASSERT(DimSize(channels, COLS) == 2, "A channel input consists of [[channelType, channelNumber]+].")

		WAVE/Z sweeps = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_SELECT, 1)
		if(WaveExists(sweeps))
			SF_ASSERT(DimSize(sweeps, COLS) < 2, "Sweeps are one-dimensional.")
		endif

		if(numArgs > 2)
			WAVE/T wMode = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_SELECT, 2, checkExist=1)
			SF_ASSERT(IsTextWave(wMode), "mode parameter can not be a number. Use \"all\" or \"displayed\".")
			SF_ASSERT(!DimSize(wMode, COLS) && DimSize(wMode, ROWS) == 1, "mode must not be an array with multiple options.")
			mode = wMode[0]
			SF_ASSERT(!CmpStr(mode, "displayed") || !CmpStr(mode, "all"), "mode must be \"all\" or \"displayed\".")
		endif

		if(numArgs > 3)
			WAVE/T wClamp = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_SELECT, 3, checkExist=1)
			SF_ASSERT(IsTextWave(wClamp), "clamp parameter can not be a number. Use \"all\",  \"ic\" or \"vc\".")
			SF_ASSERT(!DimSize(wClamp, COLS) && DimSize(wClamp, ROWS) == 1, "clamp must not be an array with multiple options.")
			clamp = wClamp[0]
			if(!CmpStr(clamp, SF_OP_SELECT_CLAMPMODE_VC))
				clampMode = V_CLAMP_MODE
			elseif(!CmpStr(clamp, SF_OP_SELECT_CLAMPMODE_IC))
				clampMode = I_CLAMP_MODE
			elseif(!CmpStr(clamp, SF_OP_SELECT_CLAMPMODE_IZERO))
				clampMode = I_EQUAL_ZERO_MODE
			elseif(CmpStr(clamp, SF_OP_SELECT_CLAMPMODE_ALL))
				SF_ASSERT(0, "clamp must be \"all\", \"vc\", \"ic\" or \"izero\".")
			endif
		endif
	endif

	WAVE/Z selectData = SF_GetActiveChannelNumbersForSweeps(graph, channels, sweeps, !CmpStr(mode, "displayed"), clampMode)

	return SF_GetOutputForExecutorSingle(selectData, graph, SF_OP_SELECT, opStack="")
End

/// `data(array range[, array selectData])`
///
/// returns [sweepData][sweeps][channelTypeNumber] for all sweeps selected by selectData
static Function/WAVE SF_OperationData(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonID, jsonPath)

	SF_ASSERT(!IsEmpty(graph), "Graph for extracting sweeps not specified.")
	SF_ASSERT(numArgs >= 1, "data function requires at least 1 argument.")
	SF_ASSERT(numArgs <= 2, "data function has maximal 2 arguments.")

	WAVE range = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_DATA, 0, checkExist=1)
	SF_ASSERT(DimSize(range, COLS) == 0, "Range must be a 1d wave.")
	if(IsTextWave(range))
		SF_ASSERT(DimSize(range, ROWS) == 1, "For range from epoch only a single name is supported.")
	else
		SF_ASSERT(DimSize(range, ROWS) == 2, "A numerical range is of the form [rangeStart, rangeEnd].")
		range[] = !IsNaN(range[p]) ? range[p] : (p == 0 ? -1 : 1) * inf
	endif

	if(numArgs == 2)
		WAVE/Z selectData = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_DATA, 1)
	else
		WAVE/Z selectData = SF_ExecuteFormula("select()", graph, singleResult=1)
	endif
	if(WaveExists(selectData))
		SF_ASSERT(DimSize(selectData, COLS) == 3, "A select input has 3 columns.")
		SF_ASSERT(IsNumericWave(selectData), "select parameter must be numeric")
	endif

	WAVE/WAVE output = SF_GetSweepsForFormula(graph, range, selectData, SF_OP_DATA)
	if(!DimSize(output, ROWS))
		DebugPrint("Call to SF_GetSweepsForFormula returned no results")
	endif

	JWN_SetStringInWaveNote(output, SF_META_OPSTACK, AddListItem(SF_OP_DATA, ""))

	return SF_GetOutputForExecutor(output, graph, SF_OP_DATA)
End

/// `labnotebook(string key[, array selectData [, string entrySourceType]])`
///
/// return lab notebook @p key for all @p sweeps that belong to the channels @p channels
static Function/WAVE SF_OperationLabnotebook(variable jsonId, string jsonPath, string graph)

	variable numArgs, mode
	string lbnKey

	SF_ASSERT(!IsEmpty(graph), "Graph not specified.")

	numArgs = SF_GetNumberOfArguments(jsonID, jsonPath)
	SF_ASSERT(numArgs <= 3, "Maximum number of three arguments exceeded.")
	SF_ASSERT(numArgs >= 1, "At least one argument is required.")

	if(numArgs == 3)
		WAVE/T wMode = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_LABNOTEBOOK, 2, checkExist=1)
		SF_ASSERT(IsTextWave(wMode) && DimSize(wMode, ROWS) == 1 && !DimSize(wMode, COLS), "Last parameter needs to be a string.")
		strswitch(wMode[0])
			case "UNKNOWN_MODE":
				mode = UNKNOWN_MODE
				break
			case "DATA_ACQUISITION_MODE":
				mode = DATA_ACQUISITION_MODE
				break
			case "TEST_PULSE_MODE":
				mode = TEST_PULSE_MODE
				break
			case "NUMBER_OF_LBN_DAQ_MODES":
				mode = NUMBER_OF_LBN_DAQ_MODES
				break
			default:
				SF_ASSERT(0, "Undefined labnotebook mode. Use one in group DataAcqModes")
		endswitch
	else
		mode = DATA_ACQUISITION_MODE
	endif

	if(numArgs >= 2)
		WAVE/Z selectData = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_LABNOTEBOOK, 1)
	else
		WAVE/Z selectData = SF_ExecuteFormula("select()", graph, singleResult=1)
	endif
	if(WaveExists(selectData))
		SF_ASSERT(DimSize(selectData, COLS) == 3, "A select input has 3 columns.")
		SF_ASSERT(IsNumericWave(selectData), "select parameter must be numeric")
	endif

	WAVE/T wLbnKey = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_LABNOTEBOOK, 0, checkExist=1)
	SF_ASSERT(IsTextWave(wLbnKey) && DimSize(wLbnKey, ROWS) == 1 && !DimSize(wLbnKey, COLS), "First parameter needs to be a string labnotebook key.")
	lbnKey = wLbnKey[0]

	WAVE/WAVE output = SF_OperationLabnotebookImpl(graph, lbnKey, selectData, mode, SF_OP_LABNOTEBOOK)

	JWN_SetStringInWaveNote(output, SF_META_OPSTACK, AddListItem(SF_OP_LABNOTEBOOK, ""))

	return SF_GetOutputForExecutor(output, graph, SF_OP_LABNOTEBOOK)
End

static Function/WAVE SF_OperationLabnotebookImpl(string graph, string lbnKey, WAVE/Z selectData, variable mode, string opShort)

	variable i, numSelected, index, settingsIndex
	variable sweepNo, chanNr, chanType

	if(!WaveExists(selectData))
		WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, 0)
		JWN_SetStringInWaveNote(output, SF_META_DATATYPE, SF_DATATYPE_LABNOTEBOOK)
		return output
	endif

	numSelected = DimSize(selectData, ROWS)
	WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, numSelected)

	for(i = 0; i < numSelected; i += 1)

		sweepNo = selectData[i][%SWEEP]
		chanNr = selectData[i][%CHANNELNUMBER]
		chanType = selectData[i][%CHANNELTYPE]

		if(!IsValidSweepNumber(sweepNo))
			continue
		endif

		WAVE/Z numericalValues = BSP_GetLogbookWave(graph, LBT_LABNOTEBOOK, LBN_NUMERICAL_VALUES, sweepNumber = sweepNo)
		WAVE/Z textualValues = BSP_GetLogbookWave(graph, LBT_LABNOTEBOOK, LBN_TEXTUAL_VALUES, sweepNumber = sweepNo)
		if(!WaveExists(numericalValues) || !WaveExists(textualValues))
			continue
		endif

		[WAVE settings, settingsIndex] = GetLastSettingChannel(numericalValues, textualValues, sweepNo, lbnKey, chanNr, chanType, mode)
		if(!WaveExists(settings))
			continue
		endif
		if(IsNumericWave(settings))
			Make/FREE/D outD = {settings[settingsIndex]}
			WAVE out = outD
		elseif(IsTextWave(settings))
			WAVE/T settingsT = settings
			Make/FREE/T outT = {settingsT[settingsIndex]}
			WAVE out = outT
		endif

		JWN_SetNumberInWaveNote(out, SF_META_SWEEPNO, sweepNo)
		JWN_SetNumberInWaveNote(out, SF_META_CHANNELTYPE, chanType)
		JWN_SetNumberInWaveNote(out, SF_META_CHANNELNUMBER, chanNr)
		JWN_SetWaveInWaveNote(out, SF_META_XVALUES, {sweepNo})

		output[index] = out
		index += 1
	endfor
	Redimension/N=(index) output

	JWN_SetStringInWaveNote(output, SF_META_DATATYPE, SF_DATATYPE_LABNOTEBOOK)
	JWN_SetStringInWaveNote(output, SF_META_XAXISLABEL, "Sweeps")
	JWN_SetStringInWaveNote(output, SF_META_YAXISLABEL, lbnKey)
	return output
End

static Function/WAVE SF_OperationLog(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_LOG)
	elseif(numArgs == 1)
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_LOG, 0)
	else
		WAVE/WAVE input = SF_CreateSFRefWave(graph, SF_OP_LOG, 0)
	endif

	for(w : input)
		SF_OperationLogImpl(w)
	endfor

	SF_TransferFormulaDataWaveNoteAndMeta(input, input, SF_OP_LOG, JWN_GetStringFromWaveNote(input, SF_META_DATATYPE))

	return SF_GetOutputForExecutor(input, graph, SF_OP_LOG)
End

static Function SF_OperationLogImpl(WAVE/Z input)

	if(!WaveExists(input))
		return NaN
	endif

	if(!DimSize(input, ROWS))
		return NaN
	endif

	if(IsTextWave(input))
		WAVE/T wt = input
		print wt[0]
	else
		print input[0]
	endif
End

static Function/WAVE SF_OperationLog10(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonId, jsonPath)
	if(numArgs > 1)
		WAVE/WAVE input = SF_GetArgumentTop(jsonId, jsonPath, graph, SF_OP_LOG10)
	else
		WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, SF_OP_LOG10, 0)
	endif
	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_LOG10, DimSize(input, ROWS))

	output[] = SF_OperationLog10Impl(input[p])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_LOG10, JWN_GetStringFromWaveNote(input, SF_META_DATATYPE))

	return SF_GetOutputForExecutor(output, graph, SF_OP_LOG10, clear=input)
End

static Function/WAVE SF_OperationLog10Impl(WAVE/Z input)

	if(!WaveExists(input))
		return $""
	endif
	SF_ASSERT(IsNumericWave(input), "log10 requires numeric input data.")
	MatrixOP/FREE output = log(input)
	SF_FormulaWaveScaleTransfer(input, output, SF_TRANSFER_ALL_DIMS, NaN)

	return output
End

static Function/WAVE SF_OperationCursors(variable jsonId, string jsonPath, string graph)

	variable i
	string info
	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonID, jsonPath)
	if(!numArgs)
		Make/FREE/T wvT = {"A", "B"}
		numArgs = 2
	else
		Make/FREE/T/N=(numArgs) wvT
		for(i = 0; i < numArgs; i += 1)
			WAVE/T csrName = SF_GetArgumentSingle(jsonId, jsonPath, graph, SF_OP_CURSORS, i, checkExist=1)
			SF_ASSERT(IsTextWave(csrName), "cursors argument at " + num2istr(i) + " must be textual.")
			wvT[i] = csrName[0]
		endfor
	endif
	Make/FREE/N=(numArgs) out = NaN
	for(i = 0; i < numArgs; i += 1)
		SF_ASSERT(GrepString(wvT[i], "^(?i)[A-J]$"), "Invalid Cursor Name")
		if(IsEmpty(graph))
			out[i] = xcsr($wvT[i])
		else
			info = CsrInfo($wvT[i], graph)
			if(IsEmpty(info))
				continue
			endif
			out[i] = xcsr($wvT[i], graph)
		endif
	endfor

	return SF_GetOutputForExecutorSingle(out, graph, SF_OP_CURSORS, opStack="")
End

// findlevel(data, level, [edge])
static Function/WAVE SF_OperationFindLevel(variable jsonId, string jsonPath, string graph)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonID, jsonPath)
	SF_ASSERT(numArgs <=3, "Findlevel has 3 arguments at most.")
	SF_ASSERT(numArgs > 1, "Findlevel needs at least two arguments.")
	WAVE/WAVE input = SF_GetArgument(jsonID, jsonPath, graph, SF_OP_FINDLEVEL, 0)
	WAVE level = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_FINDLEVEL, 1, checkExist=1)
	SF_ASSERT(DimSize(level, ROWS) == 1, "Too many input values for parameter level")
	SF_ASSERT(IsNumericWave(level), "level parameter must be numeric")
	if(numArgs == 3)
		WAVE edge = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_FINDLEVEL, 2, checkExist=1)
		SF_ASSERT(DimSize(edge, ROWS) == 1, "Too many input values for parameter edge")
		SF_ASSERT(IsNumericWave(edge), "edge parameter must be numeric")
		SF_ASSERT(edge[0] == FINDLEVEL_EDGE_BOTH || edge[0] == FINDLEVEL_EDGE_INCREASING ||  edge[0] == FINDLEVEL_EDGE_DECREASING, "edge parameter is invalid")
	else
		Make/FREE edge = {FINDLEVEL_EDGE_BOTH}
	endif

	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_FINDLEVEL, DimSize(input, ROWS))
	output = FindLevelWrapper(input[p], level[0], edge[0], FINDLEVEL_MODE_SINGLE)

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_FINDLEVEL, SF_DATATYPE_FINDLEVEL)

	return SF_GetOutputForExecutor(output, graph, SF_OP_FINDLEVEL)
End

// apfrequency(data, [frequency calculation method], [spike detection crossing level])
static Function/WAVE SF_OperationApFrequency(variable jsonId, string jsonPath, string graph)

	variable numArgs, i

	numArgs = SF_GetNumberOfArguments(jsonID, jsonPath)
	SF_ASSERT(numArgs <=3, "ApFrequency has 3 arguments at most.")
	SF_ASSERT(numArgs >= 1, "ApFrequency needs at least one argument.")

	WAVE/WAVE input = SF_GetArgument(jsonID, jsonPath, graph, SF_OP_APFREQUENCY, 0)
	if(numArgs == 3)
		WAVE level = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_APFREQUENCY, 2, checkExist=1)
		SF_ASSERT(DimSize(level, ROWS) == 1, "Too many input values for parameter level")
		SF_ASSERT(IsNumericWave(level), "level parameter must be numeric")
	else
		Make/FREE level = {0}
	endif

	if(numArgs >= 2)
		WAVE method = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_APFREQUENCY, 1, checkExist=1)
		SF_ASSERT(DimSize(method, ROWS) == 1, "Too many input values for parameter method")
		SF_ASSERT(IsNumericWave(method), "method parameter must be numeric.")
		SF_ASSERT(method[0] == SF_APFREQUENCY_FULL || method[0] == SF_APFREQUENCY_INSTANTANEOUS ||  method[0] == SF_APFREQUENCY_APCOUNT, "method parameter is invalid")
	else
		Make/FREE method = {SF_APFREQUENCY_FULL}
	endif

	WAVE/WAVE output = SF_CreateSFRefWave(graph, SF_OP_APFREQUENCY, DimSize(input, ROWS))
	output = SF_OperationApFrequencyImpl(input[p], level[0], method[0])

	SF_TransferFormulaDataWaveNoteAndMeta(input, output, SF_OP_APFREQUENCY, SF_DATATYPE_APFREQUENCY)

	return SF_GetOutputForExecutor(output, graph, SF_OP_APFREQUENCY)
End

static Function/WAVE SF_OperationApFrequencyImpl(WAVE data, variable level, variable method)

	variable numSets, i

	WAVE levels = FindLevelWrapper(data, level, FINDLEVEL_EDGE_INCREASING, FINDLEVEL_MODE_MULTI)
	numSets = DimSize(levels, ROWS)
	Make/FREE/N=(numSets) levelPerSet = str2num(GetDimLabel(levels, ROWS, p))

	// @todo we assume that the x-axis of data has a ms scale for FULL/INSTANTANEOUS
	switch(method)
		case SF_APFREQUENCY_FULL:
			Make/N=(numSets)/D/FREE outD = levelPerSet[p] / (DimDelta(data, ROWS) * DimSize(data, ROWS) * MILLI_TO_ONE)
			break
		case SF_APFREQUENCY_INSTANTANEOUS:
			Make/N=(numSets)/D/FREE outD

			for(i = 0; i < numSets; i += 1)
				if(levelPerSet[i] <= 1)
					outD[i] = 0
				else
					Make/FREE/D/N=(levelPerSet[i] - 1) distances
					distances[0, levelPerSet[i] - 2] = levels[i][p + 1] - levels[i][p]
					outD[i] = 1.0 / (Mean(distances) * MILLI_TO_ONE)
				endif
			endfor
			break
		case SF_APFREQUENCY_APCOUNT:
			Make/N=(numSets)/D/FREE outD = levelPerSet[p]
			break
	endswitch

	return outD
End

// `store(name, ...)`
static Function/WAVE SF_OperationStore(variable jsonId, string jsonPath, string graph)

	string rawCode, preProcCode
	variable maxEntries, numEntries

	SF_ASSERT(SF_GetNumberOfArguments(jsonID, jsonPath) == 2, "Function accepts only two arguments")

	WAVE/T name = SF_GetArgumentSingle(jsonID, jsonPath, graph, SF_OP_STORE, 0)
	SF_ASSERT(IsTextWave(name), "name parameter must be textual")
	SF_ASSERT(DimSize(name, ROWS) == 1, "name parameter must be a plain string")

	WAVE/WAVE dataRef = SF_GetArgument(jsonID, jsonPath, graph, SF_OP_STORE, 1)
	SF_ASSERT(DimSize(dataRef, ROWS) == 1, "Multiple dataSets not supported yet for store().")
	WAVE/Z out = dataRef[0]
	SF_ASSERT(WaveExists(out), "No data retrieved for store().")

	[rawCode, preProcCode] = SF_GetCode(graph)

	[WAVE/T keys, WAVE/T values] = SF_CreateResultsWaveWithCode(graph, rawCode, data = out, name = name[0])

	ED_AddEntriesToResults(values, keys, SWEEP_FORMULA_RESULT)

	// return second argument unmodified
	return SF_GetOutputForExecutor(dataRef, graph, SF_OP_STORE)
End

static Function/WAVE SF_SplitCodeToGraphs(string code)

	string group0, group1
	variable graphCount, size

	WAVE/T graphCode = GetYvsXFormulas()

	do
		SplitString/E=SF_SWEEPFORMULA_GRAPHS_REGEXP code, group0, group1
		if(!IsEmpty(group0))
			EnsureLargeEnoughWave(graphCode, dimension = ROWS, minimumSize = graphCount + 1)
			graphCode[graphCount] = group0
			graphCount += 1
			code = group1
		endif
	while(!IsEmpty(group1))
	Redimension/N=(graphCount) graphCode

	return graphCode
End

static Function/WAVE SF_SplitGraphsToFormulas(WAVE/T graphCode)

	variable i, numGraphs, numFormulae
	string yFormula, xFormula

	WAVE/T wFormulas = GetYandXFormulas()

	numGraphs = DimSize(graphCode, ROWS)
	Redimension/N=(numGraphs, -1) wFormulas
	for(i = 0; i < numGraphs; i += 1)
		SplitString/E=SF_SWEEPFORMULA_REGEXP graphCode[i], yFormula, xFormula
		numFormulae = V_Flag
		if(numFormulae != 1 && numFormulae != 2)
			return $""
		endif
		wFormulas[i][%FORMULA_X] = SelectString(numFormulae == 2, "", xFormula)
		wFormulas[i][%FORMULA_Y] = yFormula
	endfor

	return wFormulas
End

static Function/S SF_GetFormulaWinNameTemplate(string mainWindow)

	return BSP_GetFormulaGraph(mainWindow) + "_"
End

Function SF_button_sweepFormula_tofront(STRUCT WMButtonAction &ba) : ButtonControl

	string winNameTemplate, wList, wName
	variable numWins, i

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			winNameTemplate = SF_GetFormulaWinNameTemplate(GetMainWindow(ba.win))
			wList = WinList(winNameTemplate + "*", ";", "WIN:65")
			numWins = ItemsInList(wList)
			for(i = 0; i < numWins; i += 1)
				wName = StringFromList(i, wList)
				DoWindow/F $wName
			endfor

			break
	endswitch

	return 0
End

static Function/WAVE SF_NewChannelsWave(variable size)

	ASSERT(size >= 0, "Invalid wave size specified")

	Make/N=(size, 2)/FREE out = NaN
	SetDimLabel COLS, 0, channelType, out
	SetDimLabel COLS, 1, channelNumber, out

	return out
End

/// @brief Create a new selectData wave
///        The row counts the selected combinations of sweep, channel type, channel number
///        The three columns per row store the sweep number, channel type, channel number
static Function/WAVE SF_NewSelectDataWave(variable numSweeps, variable numChannels)

	ASSERT(numSweeps >= 0 && numChannels >= 0, "Invalid wave size specified")

	Make/FREE/D/N=(numSweeps * numChannels, 3) selectData
	SetDimLabel COLS, 0, SWEEP, selectData
	SetDimLabel COLS, 1, CHANNELTYPE, selectData
	SetDimLabel COLS, 2, CHANNELNUMBER, selectData

	return selectData
End

static Function/WAVE SF_AverageTPFromSweep(WAVE/T epochMatches, WAVE sweepData)

	variable numTPEpochs, tpDataSizeMin, tpDataSizeMax, sweepDelta

	numTPEpochs = DimSize(epochMatches, ROWS)
	sweepDelta = DimDelta(sweepData, ROWS)
	Make/FREE/D/N=(numTPEpochs) tpStart = trunc(str2num(epochMatches[p][EPOCH_COL_STARTTIME]) * ONE_TO_MILLI / sweepDelta)
	Make/FREE/D/N=(numTPEpochs) tpDelta = trunc(str2num(epochMatches[p][EPOCH_COL_ENDTIME]) * ONE_TO_MILLI / sweepDelta) - tpStart[p]
	[tpDataSizeMin, tpDataSizeMax] = WaveMinAndMaxWrapper(tpDelta)
	SF_ASSERT(tpDataSizeMax - tpDataSizeMin <= 1, "TP data size from TP epochs mismatch within sweep.")

	Make/FREE/D/N=(tpDataSizeMin) tpData
	CopyScales/P sweepData, tpData
	tpDelta = SF_AverageTPFromSweepImpl(tpData, tpStart, sweepData, p)
	if(numTPEpochs > 1)
		MultiThread tpData /= numTPEpochs
	endif

	return tpData
End

static Function SF_AverageTPFromSweepImpl(WAVE tpData, WAVE tpStart, WAVE sweepData, variable i)

	MultiThread tpData += sweepData[tpStart[i] + p]
End

Function/WAVE SF_GetAllOldCodeForGUI(string win) // parameter required for popup menu ext
	WAVE/T/Z entries = SF_GetAllOldCode()

	if(!WaveExists(entries))
		return $""
	endif

	entries[] = num2str(p) + ": " + ElideText(ReplaceString("\n", entries[p], " "), 60)

	WAVE/T/Z splittedMenu = PEXT_SplitToSubMenus(entries, method = PEXT_SUBSPLIT_ALPHA)

	PEXT_GenerateSubMenuNames(splittedMenu)

	return splittedMenu
End

static Function/WAVE SF_GetAllOldCode()
	string entry

	WAVE/T textualResultsValues = GetLogbookWaves(LBT_RESULTS, LBN_TEXTUAL_VALUES)

	entry = "Sweep Formula code"
	WAVE/Z indizes = GetNonEmptyLBNRows(textualResultsValues, entry)

	if(!WaveExists(indizes))
		return $""
	endif

	Make/FREE/T/N=(DimSize(indizes, ROWS)) entries = textualResultsValues[indizes[p]][%$entry][INDEP_HEADSTAGE]

	return GetUniqueEntries(entries)
End

Function SF_PopMenuProc_OldCode(STRUCT WMPopupAction &pa) : PopupMenuControl

	string sweepFormulaNB, bsPanel, code
	variable index

	switch(pa.eventCode)
		case 2: // mouse up
			if(!cmpstr(pa.popStr, NONE))
				break
			endif

			bsPanel = BSP_GetPanel(pa.win)
			sweepFormulaNB = BSP_GetSFFormula(bsPanel)
			WAVE/T/Z entries = SF_GetAllOldCode()
			// -2 as we have NONE
			index = str2num(pa.popStr)
			code = entries[index]

			// translate back from \n to \r
			code = ReplaceString("\n", code, "\r")

			ReplaceNotebookText(sweepFormulaNB, code)
			PGC_SetAndActivateControl(bsPanel, "button_sweepFormula_display", val = CHECKBOX_SELECTED)
			break
	endswitch

	return 0
End

// Sets a formula in the SweepFormula notebook of the given data/sweepbrowser
Function SF_SetFormula(string databrowser, string formula)

	string nb = BSP_GetSFFormula(databrowser)
	ReplaceNotebookText(nb, formula)
End

/// @brief Executes a given formula without changing the current SweepFormula notebook
/// @param formula formula string to execute
/// @param databrowser name of databrowser window
/// @param singleResult [optional, default 0], if set then the first dataSet is retrieved from the waveRef wave and returned, the waveRef wave is disposed
/// @param checkExist [optional, default 0], only valid if singleResult=1, if set then the data wave in the single dataSet retrieved must exist
Function/WAVE SF_ExecuteFormula(string formula, string databrowser[, variable singleResult, variable checkExist])

	variable jsonId

	singleResult = ParamIsDefault(singleResult) ? 0 : !!singleResult
	checkExist = ParamIsDefault(checkExist) ? 0 : !!checkExist

	formula = SF_PreprocessInput(formula)
	formula = SF_FormulaPreParser(formula)
	jsonId = SF_FormulaParser(formula)
	WAVE/Z result = SF_FormulaExecutor(databrowser, jsonId)
	JSON_Release(jsonId, ignoreErr=1)

	WAVE/WAVE out = SF_ParseArgument(databrowser, result, "FormulaExecution")
	if(singleResult)
		SF_ASSERT(DimSize(out, ROWS) == 1, "Expected only a single dataSet")
		WAVE/Z data = out[0]
		SF_ASSERT(!(checkExist && !WaveExists(data)), "No data in dataSet returned from executed formula.")
		SF_CleanUpInput(out)
		return data
	endif

	return out
End

// returns number of operation arguments
static Function SF_GetNumberOfArguments(variable jsonId, string jsonPath)

	variable size

	size = JSON_GetArraySize(jsonID, jsonPath)
	if(!size)
		return size
	endif

	return JSON_GetType(jsonId, jsonPath + "/0") == JSON_NULL ? 0 : size
End

static Function/DF SF_GetWorkingDF(string win)

	DFREF dfr = BSP_GetFolder(GetMainWindow(win), MIES_BSP_PANEL_FOLDER)

	return createDFWithAllParents(GetDataFolder(1, dfr) + SF_WORKING_DF)
End

static Function/WAVE SF_CreateSFRefWave(string win, string opShort, variable size)

	string wName

	DFREF dfrWork = SF_GetWorkingDF(win)
	wName = UniqueWaveName(dfrWork, opShort + "_output_")

	Make/WAVE/N=(size) dfrWork:$wName/WAVE=wv

	return wv
End

static Function/WAVE SF_ParseArgument(string win, WAVE input, string opShort)

	string wName, tmpStr

	ASSERT(IsTextWave(input) && DimSize(input, ROWS) == 1 && DimSize(input, COLS) == 0, "Unknown SF argument input format")

	WAVE/T wvt = input
	ASSERT(strsearch(wvt[0], SF_WREF_MARKER, 0) == 0, "Marker not found in SF argument")

	tmpStr = wvt[0]
	wName = tmpStr[strlen(SF_WREF_MARKER), Inf]
	WAVE/Z out = $wName
	ASSERT(WaveExists(out), "Referenced wave not found: " + wName)

	return out
End

static Function SF_CleanUpInput(WAVE input)

#ifndef SWEEPFORMULA_DEBUG
	KillOrMoveToTrash(wv = input)
#endif
End

static Function SF_ConvertAllReturnDataToPermanent(WAVE/WAVE output, string win, string opShort)

	string wName
	variable i

	for(data : output)
		if(WaveExists(data) && IsFreeWave(data))
			DFREF dfrWork = SF_GetWorkingDF(win)
			wName = UniqueWaveName(dfrWork, opShort + "_return_arg" + num2istr(i) + "_")
			MoveWave data, dfrWork:$wName
		endif
		i += 1
	endfor
End

static Function/WAVE SF_GetOutputForExecutorSingle(WAVE/Z data, string graph, string opShort[, string opStack, WAVE clear])

	if(!ParamIsDefault(clear))
		SF_CleanUpInput(clear)
	endif

	WAVE/WAVE output = SF_CreateSFRefWave(graph, opShort, 1)
	if(WaveExists(data))
		output[0] = data
	endif

	if(!ParamIsDefault(opStack))
		SF_AddOpToOpStack(output, opStack, opShort)
	endif

	return SF_GetOutputForExecutor(output, graph, opShort)
End

static Function/WAVE SF_GetOutputForExecutor(WAVE output, string win, string opShort[, WAVE clear])

	if(!ParamIsDefault(clear))
		SF_CleanUpInput(clear)
	endif
	Make/FREE/T wRefPath = {SF_WREF_MARKER + GetWavesDataFolder(output, 2)}

#ifdef SWEEPFORMULA_DEBUG
	SF_ConvertAllReturnDataToPermanent(output, win, opShort)
#endif

	return wRefPath
End

/// @brief Executes the complete arguments of the JSON and parses the resulting data to a waveRef type
///        @deprecated: executing all arguments e.g. as array in the executor poses issues as soon as data types get mixed.
///                    e.g. operation(0, A, [1, 2, 3]) fails as [0, A, [1, 2, 3]] can not be converted to an Igor wave.
///                    Thus, it is strongly recommended to parse each argument separately.
static Function/WAVE SF_GetArgumentTop(variable jsonId, string jsonPath, string graph, string opShort)

	variable numArgs

	numArgs = SF_GetNumberOfArguments(jsonID, jsonPath)
	if(numArgs > 0)
		WAVE wv = SF_FormulaExecutor(graph, jsonID, jsonPath = jsonPath)
	else
		Make/FREE/N=0 data
		WAVE wv = SF_GetOutputForExecutorSingle(data, graph, opShort + "_zeroSizedInput")
	endif

	WAVE/WAVE input = SF_ParseArgument(graph, wv, opShort + "_argTop")

	return input
End

/// @brief Executes the part of the argument part of the JSON and parses the resulting data to a waveRef type
static Function/WAVE SF_GetArgument(variable jsonId, string jsonPath, string graph, string opShort, variable argNum)

	string opSpec, argStr

	argStr = num2istr(argNum)
	WAVE wv = SF_FormulaExecutor(graph, jsonID, jsonPath = jsonPath + "/" + argStr)
	opSpec = "_arg" + argStr
	WAVE/WAVE input = SF_ParseArgument(graph, wv, opShort + opSpec)

	return input
End

/// @brief Retrieves from an argument the first dataset and disposes the argument
static Function/WAVE SF_GetArgumentSingle(variable jsonId, string jsonPath, string graph, string opShort, variable argNum[, variable checkExist])

	checkExist = ParamIsDefault(checkExist) ? 0 : !!checkExist

	WAVE/WAVE input = SF_GetArgument(jsonId, jsonPath, graph, opShort, argNum)
	SF_ASSERT(DimSize(input, ROWS) == 1, "Expected only a single dataSet")
	WAVE/Z data = input[0]
	SF_ASSERT(!(checkExist && !WaveExists(data)), "No data in dataSet at operation " + opShort + " arg num " + num2istr(argNum))
	SF_CleanUpInput(input)

	return data
End

static Function SF_AddOpToOpStack(WAVE w, string oldStack, string opShort)

	JWN_SetStringInWaveNote(w, SF_META_OPSTACK, AddListItem(opShort, oldStack))
End

/// @brief Transfer wavenote from input data sets to output data sets
///        set a label for a x-axis and x-value(s) for data waves
static Function SF_TransferFormulaDataWaveNoteAndMeta(WAVE/WAVE input, WAVE/WAVE output, string opShort, string newDataType)

	variable sweepNo, numResults, i, setXLabel
	string opStack, inDataType, xLabel

	numResults = DimSize(input, ROWS)
	ASSERT(numResults == DimSize(output, ROWS), "Input and output must have the same size.")

	JWN_SetStringInWaveNote(output, SF_META_DATATYPE, newDataType)

	opStack = JWN_GetStringFromWaveNote(input, SF_META_OPSTACK)
	SF_AddOpToOpStack(output, opStack, opShort)

	inDataType = JWN_GetStringFromWaveNote(input, SF_META_DATATYPE)

	setXLabel = 1
	for(i = 0; i < numResults; i += 1)
		WAVE/Z inData = input[i]
		WAVE/Z outData = output[i]
		if(!WaveExists(inData) || !WaveExists(outData))
			continue
		endif

		Note/K outData, note(inData)

		strswitch(inDataType)
			case SF_DATATYPE_SWEEP:
				if(numpnts(outData) == 1 && IsEmpty(WaveUnits(outData, ROWS)))
					sweepNo = JWN_GetNumberFromWaveNote(outData, SF_META_SWEEPNO)
					JWN_SetWaveInWaveNote(outData, SF_META_XVALUES, {sweepNo})
				else
					setXLabel = 0
				endif
				break
			default:
				sweepNo = JWN_GetNumberFromWaveNote(outData, SF_META_SWEEPNO)
				if(numpnts(outData) == 1 && IsEmpty(WaveUnits(outData, ROWS)) && !IsNaN(sweepNo))
					JWN_SetWaveInWaveNote(outData, SF_META_XVALUES, {sweepNo})
				else
					setXLabel = 0
				endif
				break
		endswitch

	endfor

	xLabel = ""
	if(setXLabel)
		strswitch(inDataType)
			case SF_DATATYPE_SWEEP:
				xLabel = "Sweeps"
				break
			default:
				xLabel = "Sweeps"
				break
		endswitch
	endif

	JWN_SetStringInWaveNote(output, SF_META_XAXISLABEL, xLabel)
End

static Function/WAVE SF_AverageDataOverSweeps(WAVE/WAVE input)

	variable i, channelNumber, channelType, sweepNo, pos, size, numGroups, numInputs
	variable isSweepData
	string lbl

	numInputs = DimSize(input, ROWS)
	Make/FREE/N=(numInputs) groupIndexCount
	Make/FREE/WAVE/N=(MINIMUM_WAVE_SIZE) groupWaves
	for(data : input)
		if(!WaveExists(data))
			continue
		endif

		channelNumber = JWN_GetNumberFromWaveNote(data, SF_META_CHANNELNUMBER)
		channelType = JWN_GetNumberFromWaveNote(data, SF_META_CHANNELTYPE)
		sweepNo = JWN_GetNumberFromWaveNote(data, SF_META_SWEEPNO)

		isSweepData = !IsNaN(channelNumber) && !IsNaN(channelType) && !IsNaN(sweepNo)
		if(isSweepData)
			lbl = num2istr(channelType) + "_" + num2istr(channelNumber)
		else
			lbl = SF_AVERAGING_NONSWEEPDATA_LBL
		endif

		pos = FindDimLabel(groupWaves, ROWS, lbl)
		if(pos == -2)
			size = DimSize(groupWaves, ROWS)
			if(size == numGroups)
				Redimension/N=(size + MINIMUM_WAVE_SIZE) groupWaves
			endif
			SetDimLabel ROWS, numGroups, $lbl, groupWaves
			pos = numGroups

			Make/FREE/WAVE/N=(numInputs) group
			if(isSweepData)
				JWN_SetNumberInWaveNote(group, SF_META_CHANNELNUMBER, channelNumber)
				JWN_SetNumberInWaveNote(group, SF_META_CHANNELTYPE, channelType)
				JWN_SetNumberInWaveNote(group, SF_META_AVERAGED_FIRST_SWEEP, sweepNo)
			endif
			groupWaves[pos] = group

			numGroups += 1
		endif

		WAVE group = groupWaves[pos]
		size = groupIndexCount[pos]
		group[size] = data
		groupIndexCount[pos] +=1
	endfor
	Redimension/N=(numGroups) groupWaves
	for(i = 0; i < numGroups; i += 1)
		WAVE group = groupWaves[i]
		Redimension/N=(groupIndexCount[i]) group
	endfor

	numGroups = DimSize(groupWaves, ROWS)
	Make/FREE/WAVE/N=(numGroups) output
	MultiThread output[] = SF_SweepAverageHelper(groupWaves[p])
	for(i = 0; i < numGroups; i += 1)
		WAVE wData = output[i]
		JWN_SetNumberInWaveNote(wData, SF_META_ISAVERAGED, 1)
		if(CmpStr(GetDimLabel(groupWaves, ROWS, i), SF_AVERAGING_NONSWEEPDATA_LBL))
			WAVE group = groupWaves[i]
			JWN_SetNumberInWaveNote(wData, SF_META_CHANNELNUMBER, JWN_GetNumberFromWaveNote(group, SF_META_CHANNELNUMBER))
			JWN_SetNumberInWaveNote(wData, SF_META_CHANNELTYPE, JWN_GetNumberFromWaveNote(group, SF_META_CHANNELTYPE))
			JWN_SetNumberInWaveNote(wData, SF_META_AVERAGED_FIRST_SWEEP, JWN_GetNumberFromWaveNote(group, SF_META_AVERAGED_FIRST_SWEEP))
		endif
	endfor

	return output
End

threadsafe static Function/WAVE SF_SweepAverageHelper(WAVE/WAVE group)

	WAVE/WAVE avgResult = MIES_fWaveAverage(group, 0, IGOR_TYPE_32BIT_FLOAT)

	return avgResult[0]
End

threadsafe static Function SF_RemoveEndOfSweepNaNs(WAVE/Z input)

	if(!WaveExists(input))
		return NaN
	endif

	FindValue/Z/FNAN input
	if(V_Value >= 0)
		Redimension/N=(V_Value) input
	endif
End
