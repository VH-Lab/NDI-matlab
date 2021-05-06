# ndi.example.tutorial.plottreeshrewdata

  ndi.example.tutorial.plottreeshrewdata - plot tree shrew data from Van Hooser et al. 2014
 
  ndi.example.tutorial.plottreeshrewdata(filename)
 
  
  This function also accepts additional arguments in the form of name/value pairs
  (see help NAMEVALUEPAIR)
  -------------------------------------------------------------------------------
  | Property (default)       | Description                                      |
  | ------------------------ | ------------------------------------------------ |
  | electrodeChannel (11)    | Channel with the electrode recording             |
  | stimTriggerChannel (2)   | Channel with the stimulus trigger record         |
  | syncChannel (4)          | Channel with the synchronizing information       |
  | stimCodeMarkChannel (32) | Channel with stimulus code mark information      |
  | timeWindow ([0 100])     | Time window to show initially in graph           |
  | ePhysYRange ([-11 11])   | ePhys Y range                                    |
  | ePhysYStimLabel (7)      | Y location for stimulus code type plot           |
  | syncYRange ([0 8])       | stimSync Y range                                 |
  | syncYStimLabel (7)       | Y location for stimulus code type plot           |
  | stimDuration (2))        | Stimulus duration in seconds                     |
  | fig ([])                 | The figure to use. If empty, make a new one      |
  | verbose (1)              | Should we print status messages?                 |
  | plotit (1)               | Plot the data                                    |
  | plotstimsync (0)         | Plot a graph of the stimSync data                |
  | title_string ('')        | Plot title string                                |
  |-----------------------------------------------------------------------------|
