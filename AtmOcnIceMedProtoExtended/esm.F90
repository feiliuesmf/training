!==============================================================================
! Earth System Modeling Framework
! Copyright 2002-2018, University Corporation for Atmospheric Research, 
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics 
! Laboratory, University of Michigan, National Centers for Environmental 
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory, 
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.
!==============================================================================

module ESM

  !-----------------------------------------------------------------------------
  ! Code that specializes generic ESM Component code.
  !-----------------------------------------------------------------------------

  use ESMF
  use NUOPC
  use NUOPC_Driver, &
    driver_routine_SS             => SetServices, &
    driver_label_SetModelServices => label_SetModelServices, &
    driver_label_SetRunSequence   => label_SetRunSequence
  
  use ATM, only: atmSS => SetServices
  use OCN, only: ocnSS => SetServices
  use ICE, only: iceSS => SetServices
  use MED, only: medSS => SetServices
  
  use NUOPC_Connector, only: cplSS => SetServices
  
  implicit none
  
  private
  
  public SetServices
  
  !-----------------------------------------------------------------------------
  contains
  !-----------------------------------------------------------------------------

  subroutine SetServices(driver, rc)
    type(ESMF_GridComp)  :: driver
    integer, intent(out) :: rc
    
    rc = ESMF_SUCCESS
    
    ! NUOPC_Driver registers the generic methods
    call NUOPC_CompDerive(driver, driver_routine_SS, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
      
    ! attach specializing method(s)
    call NUOPC_CompSpecialize(driver, specLabel=driver_label_SetModelServices, &
      specRoutine=SetModelServices, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call NUOPC_CompSpecialize(driver, specLabel=driver_label_SetRunSequence, &
      specRoutine=SetRunSequence, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    
  end subroutine

  subroutine SetRunSequence(driver, rc)
    type(ESMF_GridComp)  :: driver
    integer, intent(out) :: rc
    
    ! local variables
    character(ESMF_MAXSTR)              :: name
    type(ESMF_Config)                   :: config
    type(NUOPC_FreeFormat)              :: runSeqFF

    rc = ESMF_SUCCESS

    config = ESMF_ConfigCreate(rc=rc)
    call ESMF_ConfigLoadFile(config, "esmApp.runconfig",rc=rc)
    runSeqFF = NUOPC_FreeFormatCreate(config, label="runSeq::", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=trim(name)//":"//__FILE__)) return  ! bail out
    ! ingest FreeFormat run sequence
    call NUOPC_DriverIngestRunSequence(driver, runSeqFF, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=trim(name)//":"//__FILE__)) return  ! bail out
    ! clean-up
    call NUOPC_FreeFormatDestroy(runSeqFF, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, file=trim(name)//":"//__FILE__)) return  ! bail out
  end subroutine

  !-----------------------------------------------------------------------------

  subroutine SetModelServices(driver, rc)
    type(ESMF_GridComp)  :: driver
    integer, intent(out) :: rc
    
    ! local variables
    integer                       :: localrc
    type(ESMF_Grid)               :: grid
    type(ESMF_Field)              :: field
    type(ESMF_Time)               :: startTime
    type(ESMF_Time)               :: stopTime
    type(ESMF_TimeInterval)       :: timeStep
    type(ESMF_Clock)              :: internalClock
    type(ESMF_GridComp)           :: child
    type(ESMF_CplComp)            :: connector
    type(ESMF_VM)                 :: vm
    integer                       :: npets, i
    integer, allocatable          :: ice_pet(:)

    rc = ESMF_SUCCESS

    ! SetServices for MED
    call NUOPC_DriverAddComp(driver, "MED", medSS, comp=child, &
      petlist=(/0,3,5/), rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call NUOPC_CompAttributeSet(child, name="Verbosity", value="max", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    
    ! SetServices for ATM
    call NUOPC_DriverAddComp(driver, "ATM", atmSS, comp=child, &
      petlist=(/0,1/), rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call NUOPC_CompAttributeSet(child, name="Verbosity", value="max", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
      
    ! SetServices for OCN
    call NUOPC_DriverAddComp(driver, "OCN", ocnSS, comp=child, &
      petlist=(/2,3/), rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call NUOPC_CompAttributeSet(child, name="Verbosity", value="max", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! SetServices for ICE
    call ESMF_VMGetCurrent(vm=vm, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call ESMF_VMGet(vm, petCount=npets, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    !if(npets .le. 4) call ESMF_Finalize(rc)
    allocate(ice_pet(npets-4))
    do i = 4, npets-1
      ice_pet(i-4+1) = i
    enddo 
    call NUOPC_DriverAddComp(driver, "ICE", iceSS, comp=child, &
      petlist=ice_pet, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call NUOPC_CompAttributeSet(child, name="Verbosity", value="max", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
      
    ! Disabling the following macro, e.g. renaming to WITHCONNECTORS_disable,
    ! will result in a driver that does not call connectors between the model
    ! components. This mode can be used if all model components are driven 
    ! as independent models. However, even for independent models the
    ! connectors can be set here, but will turn into no-ops.
#define WITHCONNECTORS
#ifdef WITHCONNECTORS
    ! SetServices for atm2ocn
    call NUOPC_DriverAddComp(driver, srcCompLabel="ATM", dstCompLabel="OCN", &
      compSetServicesRoutine=cplSS, comp=connector, petlist=(/0,1,2,3/), rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call NUOPC_CompAttributeSet(connector, name="Verbosity", value="max", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
      
    ! SetServices for ocn2atm
    call NUOPC_DriverAddComp(driver, srcCompLabel="OCN", dstCompLabel="ATM", &
      compSetServicesRoutine=cplSS, comp=connector, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call NUOPC_CompAttributeSet(connector, name="Verbosity", value="max", &
      rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
      
#endif
      
    ! set the driver clock
    call ESMF_TimeIntervalSet(timeStep, m=15, rc=rc) ! 15 minute steps
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_TimeSet(startTime, yy=2010, mm=6, dd=1, h=0, m=0, &
      calkindflag=ESMF_CALKIND_GREGORIAN, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_TimeSet(stopTime, yy=2010, mm=6, dd=1, h=12, m=0, &
      calkindflag=ESMF_CALKIND_GREGORIAN, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    internalClock = ESMF_ClockCreate(name="Application Clock", &
      timeStep=timeStep, startTime=startTime, stopTime=stopTime, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
      
    call ESMF_GridCompSet(driver, clock=internalClock, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
      
  end subroutine

end module
