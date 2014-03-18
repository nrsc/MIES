#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function IM_InitiateMIES()
	// Create MIES data folder architecture
	NewDataFolder /o root:MIES
	NewDataFolder /o root:MIES:Amplifiers
	NewDataFolder /o root:MIES:ITCDevices
	NewDataFolder /o root:MIES:ITCDevices:ActiveITCDevices // stores lists of data related to ITC devices actively acquiring data
	NewDataFolder /o root:MIES:ITCDevices:ActiveITCDevices:TestPulse // stores lists of data related to ITC devices actively running a test pulse
	NewDataFolder /o root:MIES:ITCDevices:ActiveITCDevices:Timer // stores lists of data that the background timer uses
	// Initiate wave builder - includes making wave builder panel
	WB_InitiateWaveBuilder()
	// make ephys panel
	execute "DA_Ephys()"
	// make data browser panel
	execute "DataBrowser()"
End
//=========================================================================================

Function IM_MakeGlobalsAndWaves(panelTitle)// makes the necessary parameters for the locked device to function.
	string panelTitle
	string WavePath = HSU_DataFullFolderPathString(PanelTitle)
	//string ChanAmpAssignPath = WavePath + ":ChanAmpAssign"
	//make /o /n = (12,8) $ChanAmpAssignPath = nan
	HSU_UpdateChanAmpAssignStorWv(panelTitle)
	DAP_FindConnectedAmps("button_Settings_UpdateAmpStatus")
	make /o /n= (1,8) $WavePath + ":ITCDataWave"
	make /o /n= (2,4) $WavePath + ":ITCChanConfigWave"
	make /o /n= (2,4) $WavePath + ":ITCFIFOAvailAllConfigWave"
	make /o /n= (2,4) $WavePath + ":ITCFIFOPositionAllConfigWave"
	make /o /i /n = 4 $WavePath + ":ResultsWave" 
	make /o /n= (1,8) $WavePath + ":TestPulse:" + "TestPulseITC"
	make /o /n= (1,8) $WavePath + ":TestPulse:" + "InstResistance"
	make /o /n= (1,8) $WavePath + ":TestPulse:" + "Resistance"
	make /o /n= (1,8) $WavePath + ":TestPulse:" + "SSResistance"
	
End

//=========================================================================================

Function Folder_ActiveITCfolder(panelTitle)
	string panelTitle
	
End
//=========================================================================================
Function Folder_ActiveITCTPfolder(panelTitle)
	string panelTitle
	
End
//=========================================================================================
Function Folder_ActiveTimerfolder(panelTitle)
	string panelTitle
	
End
//=========================================================================================
Function Folder_WBData(panelTitle)
	string panelTitle
	
End
//=========================================================================================
Function Folder_StimSetParam(panelTitle, DAorTTL)
	string panelTitle
	variable DAorTTL
	
End
//=========================================================================================
Function Folder_StimSets(panelTitle, DAorTTL)
	string panelTitle
	variable DAorTTL
	
End
//=========================================================================================
