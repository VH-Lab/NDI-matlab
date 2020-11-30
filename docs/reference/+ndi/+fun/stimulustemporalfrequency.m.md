# ndi.fun.stimulustemporalfrequency

  NDI_STIMULUSTEMPORALFREQUENCY - given a stimulus parameter set, return the temporal frequency
 
  [TF_VALUE, TF_NAME] = ndi.fun.stimulustemporalfrequency(STIMULUS_PARAMETERS)
 
  Given a set of STIMULUS_PARAMETERS (a structure array), this function will
  check to see if any names match those in ndi.fun.stimulustemporalfrequency.JSON.
  If so, the value for this stimulus is returned in TF_VALUE and the name of
  the parameter is returned in TF_NAME.
 
  If no temporal frequency can be determined, TF_VALUE and TF_NAME are blank.
