# ndi.test.daq.sg_flat

  ndi.test.daq.sg_flat - Test the functionality of the SpikeGadgets driver and a filenavigator with a flat organization
 
  ndi.test.daq.sg_flat([DIRNAME])
 
  Given a directory with .rec data inside, this function loads the
  first tetrode and plots the first second of data in all four channels.
 
  If DIRNAME is not provided, the default directory
  [NDIPATH]/example_sessions/exp1_eg is used.
 
  Developer note: function can be expanded to take in a specific tetrode to plot
  from specific epoch n, along with sample0 and sample1.
