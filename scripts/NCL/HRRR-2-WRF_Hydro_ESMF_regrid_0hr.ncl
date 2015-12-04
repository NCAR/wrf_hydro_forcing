;---------------------------------------------------------------------
; WRF_HYDRO_sub_domain_forcing_regridder_ESMFregrid.ncl
;
;
; Project : STEP
;
; Purpose : This is a ncl program to perform remapping of 00hr WRF-based 
;           short-term forecast simulation data to Dave's hydro simulation
;           domain. 
;
;           Before running this program, run ESMF_genWgts_WRF_HYDRO_forcing.ncl
;           ONCE to generate weights for conserve and bilinear interpolation to
;           regrid source data over destination domain.
;           Then this program reads wgtFileName_conserve and wgtFileName_bilinear
;           generated by ESMF_genWgts_WRF_HYDRO_forcing.ncl. 
;           (e.g., BASERUN_d03_to_WRF_HYDRO_weight_conserve.nc and BASERUN_d03_to_WRF_HYDRO_weight_bilinear.nc)
;
;           This program is invoked by the WRF Hydro forcing engine, WRF_Hydro_forcing.py and the input
;           values are all defined in the forcing engine's parm/config file: wrf_hydro_forcing.parm, in 
;           preparation for running at the National Water Center.
;
; Remarks : (1) Assumes that wrfout files are hourly output. (-- important for
;               computing rainrate.
;           (2) ESMF regridding performed with "conserve" option for precipitation
;               and SWE. All other variables use bilinear option for remapping. 
;
;
; Usage   : ncl 'srcfilename="wrfout_d03*"'  \
;                WRF_HYDRO_sub_domain_forcing_regridder_ESMFregrid.ncl\ ;
;           srcfilename = filename pattern of the souce wrfout files. Should have matching domain number.
;                         e.g., "wrfout_d01_2007-09-01_00_00_00.nc", "wrfout_d01_2007*.nc"
;                               "wrfout_d01_2007-09-0[1-3].nc"
; 
; Kyoko Ikeda 21 March 2013
; updated August 2015
;
;----------------------------------------------------------------------
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/ut_string.ncl"
;load "./ESMF_regridding.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

begin

;----------------------------------------------------------------------
; Source, destination , and weight filenames for generating 
; ESMF_regridding weights
;----------------------------------------------------------------------
    wgtFileName_conserve =  wgtFileName_in

  if ( .not.isfilepresent( dstGridName ) ) then
     print( " ... source grid file not found : "+ dstGridName )
     exit
  end if

;----------------------------------------------------------------------
; read in source and destination grid netCDF files
;----------------------------------------------------------------------

;---  destination grid data
  dstfile     = addfile( dstGridName ,"r")
  dlon3d=dstfile->XLONG_M   ;(USER'S NEED TO CONFIRM THIS VARIABLE IS WHAT IS IN THEIR DATA FILE)
  dlat3d=dstfile->XLAT_M   ;(USER'S NEED TO CONFIRM THIS VARIABLE IS WHAT IS IN THEIR DATA FILE)

  dlon2d=dlon3d(0,:,:)
  dlat2d=dlat3d(0,:,:)

  dims=dimsizes(dlat2d)

  ;Defined in forcing engine parm/config file
  ;outFile = getenv("outFile")

;
;dg NEED TO EDIT INPUT DATA TIME INTERVAL HERE...
;
  dt=3600.0   ;forcing data timestep in seconds... (USER'S MUST ENTER/CONFIRM THIS IS SET TO DATA TIMESTEP (or INTERVAL))
  flag=0    ;WRF - flag for removing accum precip... (DO NOT CHANGE THIS)

;----------------------------------------------------------------------
; Open source data files to be regridded...
;----------------------------------------------------------------------
;
;dg NEED TO EDIT INPUT AND OUTPUT DIRECTORIES HERE...
;

  ;Defined in forcing engine parm/config file
  ;outdir  = "./output_files/"      ; directory where output forcing data will be placed. set to dirm for overwriting the original file
  if(.not. isfilepresent(outdir)) then
     system("mkdir "+outdir)
  end if

  ;Defined in forcing engine parm/config file
  ;srcfilename = getenv ("srcFile")
  datfils = systemfunc ("/bin/ls -1 "+srcfilename)    ;list of file names
  num_datfils     = dimsizes(datfils)

   wgtFileName = wgtFileName_in

        opt                = True
        opt@WgtFileName    = wgtFileName
        opt@CopyVarAtts    = True
        opt@CopyVarCoords  = False

        opt@Debug          = True



  do ifil = 0,num_datfils-1,1   ; loop through datafiles one at a time
   
      datfile = addfile( datfils(ifil), "r")

      print( " ... Open input file : "+ datfils(ifil) )


; begin added by Wei Yu
      if(.not. isfilevar(datfile,"TMP_P0_L103_GLC0")) then
           exit()
      end if
      if(.not. isfilevar(datfile,"SPFH_P0_L103_GLC0")) then
           exit()
      end if
      if(.not. isfilevar(datfile,"UGRD_P0_L103_GLC0")) then
           exit()
      end if
      if(.not. isfilevar(datfile,"VGRD_P0_L103_GLC0")) then
           exit()
      end if
      if(.not. isfilevar(datfile,"PRES_P0_L1_GLC0")) then
           exit()
      end if
; end added by Wei Yu   


     names  = getfilevarnames(datfile) 
   
     ;----------------------------------------------------------------------
     ; Temporary output
     ;----------------------------------------------------------------------
      ncdf= addfile(outdir+"/"+outFile,"c")

   
     ;----------------------------------------------------------------------
     ;  Processing...no further mods should be required...
     ;----------------------------------------------------------------------
     ;do v=6,6
    
          x = datfile->TMP_P0_L103_GLC0
          delete_VarAtts(x, -1) 
           T2D = ESMF_regrid_with_weights(x , wgtFileName, opt)
       ; T2D!0 = "south_north"
       ; T2D!1 = "west_east"
           ncdf->T2D = T2D
           Q2D = ESMF_regrid_with_weights(datfile->SPFH_P0_L103_GLC0 , wgtFileName, opt)
           ncdf->Q2D = Q2D
;10 meter wind
           print("**************  start regrid U2D ************** ")
           U2D = ESMF_regrid_with_weights(datfile->UGRD_P0_L103_GLC0(0,:,:) , wgtFileName, opt)
           ncdf->U2D = U2D
           
           print("**************  start regrid V2D ************** ")
           V2D = ESMF_regrid_with_weights(datfile->VGRD_P0_L103_GLC0(0,:,:) , wgtFileName, opt)
           ncdf->V2D = V2D

           print("**************  start regrid PSFC ************** ")
           PSFC = ESMF_regrid_with_weights(datfile->PRES_P0_L1_GLC0 , wgtFileName, opt)
           ncdf->PSFC = PSFC

   end do   ; end do for file loop


end