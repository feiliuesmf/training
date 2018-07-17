program helloworld

      use ESMF

      implicit none

      integer                :: rc
      type(ESMF_GRID)        :: grid, grid1
      type(ESMF_Field)       :: field, field1
      type(ESMF_RouteHandle) :: rh

      call ESMF_Initialize (&
        defaultCalKind=ESMF_CALKIND_GREGORIAN, &
        logkindflag=ESMF_LOGKIND_MULTI, rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()

      print *, "Hello, world!"
      grid=ESMF_GridCreate1PeriDimUfrm( &
        minIndex=(/1,1/), &
        maxIndex=(/180,90/),&
        minCornerCoord=(/0._ESMF_KIND_R8,-85._ESMF_KIND_R8/), &
        maxCornerCoord=(/360._ESMF_KIND_R8,85._ESMF_KIND_R8/), &
        staggerLocList=(/ESMF_STAGGERLOC_CORNER, &
                         ESMF_STAGGERLOC_CENTER/), &
        rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()

      grid1=ESMF_GridCreate1PeriDimUfrm( &
        minIndex=(/1,1/), &
        maxIndex=(/90,45/),&
        minCornerCoord=(/0._ESMF_KIND_R8,-85._ESMF_KIND_R8/), &
        maxCornerCoord=(/360._ESMF_KIND_R8,85._ESMF_KIND_R8/), &
        staggerLocList=(/ESMF_STAGGERLOC_CORNER, &
                         ESMF_STAGGERLOC_CENTER/), &
        rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()

      field = ESMF_FieldCreate(grid, typekind=ESMF_TYPEKIND_R8,&
        rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()
      field1 = ESMF_FieldCreate(grid1, typekind=ESMF_TYPEKIND_R8,&
        rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()

      call ESMF_FieldRegridStore(field, field1, &
        regridMethod=ESMF_REGRIDMETHOD_CONSERVE, &
        routehandle=rh, &
        rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()

      call ESMF_FieldFill(field, dataFillScheme="sincos", rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()
      call ESMF_FieldFill(field1, dataFillScheme="one", rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()

      call ESMF_FieldWrite(field1, filename="before", rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()
      call ESMF_FieldRegrid(field, field1, &
        routehandle=rh, &
        rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()
      call ESMF_FieldWrite(field1, filename="after", rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()

!      call ESMF_GridWriteVTK(grid, staggerloc=ESMF_STAGGERLOC_CORNER, filename='grid', rc=rc)
!      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()

      call ESMF_Finalize()
      stop
end program
