# ndi_install

  NDI_INSTALL - install the NDI distribution and its ancillary directories
 
      B = NDI_INSTALL
 
  Installs the GitHub distributions necessary to run NDI-matlab.
  These are installed at [USERPATH filesep 'tools']
     (for example, /Users/steve/Documents/MATLAB/tools/)
 
  The startup file is edited to add a startup procedure in VHTOOLS.
 
  One can also dictate a different install directory by passing a full pathname:
 
  B = NDI_INSTALL(PATHNAME)
 
  PATHNAME should not include any shell script shortcuts (like '~').
 
  Finally, one can also install either the minimal set of tools needed for NDI (DEPENDENCIES=1),
  or one can install the standard VHTOOLS suite (DEPENDENCIES=2):
 
  B = NDI_INSTALL(PATHNAME, DEPENDENCIES)
 
  If PATHNAME is blank, then the default pathway of [USERPATH filesep 'tools'] is used.
