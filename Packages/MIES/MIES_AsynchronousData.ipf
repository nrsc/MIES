#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3 // Use modern global access method and strict wave access.
#pragma rtFunctionErrors=1

#ifdef AUTOMATED_TESTING
#pragma ModuleName=MIES_ASD
#endif

/// @file MIES_AsynchronousData.ipf
/// @brief __ASD__ Support functions for the asynchronous channels

/// @brief Check if the given asynchronous channel is in alarm state
Function ASD_CheckAsynAlarmState(variable value, variable minValue, variable maxValue)

	return value >= maxValue || value <= minValue
End

/// @brief Read the given asynchronous channel and return the scaled value
Function ASD_ReadChannel(device, channel)
	string device
	variable channel

	string ctrl
	variable gain, deviceChannelOffset, rawChannelValue

	NVAR deviceID = $GetDAQDeviceID(device)
	deviceChannelOffset = HW_ITC_CalculateDevChannelOff(device)

	rawChannelValue = HW_ReadADC(HARDWARE_ITC_DAC, deviceID, channel + deviceChannelOffset)

	ctrl = GetSpecialControlLabel(CHANNEL_TYPE_ASYNC, CHANNEL_CONTROL_GAIN)
	gain = DAG_GetNumericalValue(device, ctrl, index = channel)

	return rawChannelValue / gain
End
