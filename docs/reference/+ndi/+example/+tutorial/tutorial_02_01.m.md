# ndi.example.tutorial.tutorial_02_01

```
  ndi.example.tutorials.tutorial_02_01 - runs the code in Tutorial 2.1
 
  out = ndi.example.tutorials.tutorial_02_01(PREFIX, [TESTING])
 
  Runs (and tests) the code for 
 
  NDI Tutorial 2: Analzying your first electrophysiology experiment with NDI
     Tutorial 2.1: Reading an example dataset
  The tutorial is available at 
      https://vh-lab.github.io/NDI-matlab/tutorials/analyzing_first_physiology_experiment/1_example_dataset.md
 
  PREFIX should be the directory that contains the directory 'ts_exper1'. If it is not
  provided or is empty, the default is [userpath filesep 'Documents' filesep 'NDI'].
 
  If TESTING is 1, then PREFIX is taken to be [userpath filesep 'Documents' filesep' NDI filesep 'Test'], 
  and the files are copied to the temporary directory before proceeding so that the files 
  in the directory called PREFIX are not touched.

```
