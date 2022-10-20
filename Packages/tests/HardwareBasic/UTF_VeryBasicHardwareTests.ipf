#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3 // Use modern global access method and strict wave access.
#pragma rtFunctionErrors=1
#pragma ModuleName=VeryBasicHardwareTesting

static Function CheckInstallation()

	CHECK_EQUAL_VAR(CHI_CheckInstallation(), 0)
End

static Function CheckTestingInstallation()

	string str

	// this function is present in our special UserAnalysisFunctions.ipf
	str = FunctionList("CorrectFileMarker", ";", "")
	REQUIRE_PROPER_STR(str)
End

// UTF_TD_GENERATOR DeviceNameGeneratorMD1
static Function TestLocking([str])
	string str

	try
		CreateLockedDAEphys(str)
		PASS()
	catch
		FAIL()
	endtry
End

// stop testing if the disc is running full
static Function EnsureEnoughDiscSpace()

	PathInfo home
	REQUIRE(V_flag)
	REQUIRE(HasEnoughDiskspaceFree(S_path, MINIMUM_FREE_DISK_SPACE))
End

static Function CheckThatZeroMQMessagingWorks()
	PrepareForPublishTest()
End
