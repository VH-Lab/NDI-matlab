# ndi.test.daq.build_intan_flat_exp

  BUILD_INTAN_FLAT_EXP - Create an Intan driver and save it to an session
 
   ndi.test.daq.build_intan_flat_exp([DIRNAME])
 
   Given a directory with RHD data inside, this function loads the
   channel information and then plots some data from channel 1,
   as an example of the Intan driver. It also leaves the driver saved
   in the session record.
 
   If DIRNAME is not provided, the default directory
   [NDIPATH]/example_sessions/exp1_eg_saved is used.
