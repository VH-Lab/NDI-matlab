# ndi.example.tutorial.tutorial_02_04

```
  ndi.example.tutorials.tutorial_02_04 - runs the code in Tutorial 2.4
 
  out = ndi.example.tutorials.tutorial_02_04(PREFIX, [TESTING])
 
  Runs (and tests) the code for 
 
  NDI Tutorial 2: Analzying your first electrophysiology experiment with NDI
     Tutorial 2.4: Analyzing stimulus responses
  The tutorial is available at 
      https://vh-lab.github.io/NDI-matlab/tutorials/analyzing_first_physiology_experiment/4_analyzing_tuning_curves/
 
  PREFIX should be the directory that contains the directory 'ts_exper2'. If it is not
  provided or is empty, the default is [userpath filesep 'Documents' filesep 'NDI'].
 
  If TESTING is 1, then the files are examined in the temporary directory ndi_globals.path.temppath (use
  ndi.globals() to make this variable available for inspection). It is assumed that
  ndi.example.tutorial.tutorial_t02_03([],1) has been run (with TESTING set to 1).

```
