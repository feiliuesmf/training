program helloworld

      use ESMF

      implicit none

      integer            :: rc
      type(ESMF_VM)      :: vm

      call ESMF_Initialize (defaultCalKind=ESMF_CALKIND_GREGORIAN, &
        logkindflag=ESMF_LOGKIND_MULTI, rc=rc)
      if (rc /= ESMF_SUCCESS) call ESMF_Finalize()

      print *, "Hello, world!"

      call ESMF_Finalize()
      stop
end program
