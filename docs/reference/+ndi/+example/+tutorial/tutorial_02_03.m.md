# ndi.example.tutorial.tutorial_02_03

```
  ndi.example.tutorials.tutorial_02_03 - runs the code in Tutorial 2.3
 
  out = ndi.example.tutorials.tutorial_02_03(PREFIX, [TESTING])
 
  Runs (and tests) the code for 
 
  NDI Tutorial 2: Analzying your first electrophysiology experiment with NDI
     Tutorial 2.3: Using apps to analyze data (example - spike sorting)
  The tutorial is available at 
      https://vh-lab.github.io/NDI-matlab/tutorials/analyzing_first_physiology_experiment/3_spikesorting/
 
  PREFIX should be the directory that contains the directory 'ts_exper2'. If it is not
  provided or is empty, the default is [userpath filesep 'Documents' filesep 'NDI'].
 
  If TESTING is 1, then the files are examined in the temporary directory ndi_globals.path.temppath (use
  ndi.globals() to make this variable available for inspection). It is assumed that
  ndi.example.tutorial.tutorial_t02_02([],1) has been run (with TESTING set to 1).
 
  Note: a little manual intervention is needed in this tutorial.

```
