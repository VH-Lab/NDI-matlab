# ndi.test.testsuite.ndi_testsuite

  NDI_TESTSUITE - run a suite of tests
 
  OUTPUT = ndi.test.testsuite
 
  Loads a set of test suite instructions in the file
  'ndi_testsuite_list.txt'. This file is a tab-delimited table
  that can be loaded with vlt.file.loadStructArray with fields
  Field name          | Description
  --------------------------------------------------------------------------
  code                | The code to be run (as a Matlab evaluation)
  runit               | Should we run it? 0/1
  comment             | A comment string describing the test
 
  OUTPUT is a structure of outcomes. It includes the following fields:
  Field name          | Descriptopn
  --------------------------------------------------------------------------
  outcome             | Success is 1, failure is 0. -1 means it was not run.
  errormsg            | Any error message
