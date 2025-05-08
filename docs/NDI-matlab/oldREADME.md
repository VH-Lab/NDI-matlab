# NDI
Neuroscience Data Interface - A means of specifying and accessing neuroscience data

Available at https://github.com/VH-Lab/NDI-matlab

Installation instructions: https://vh-lab.github.io/NDI-matlab/NDI-matlab/installation/

Notes for manual installers: 

NDI depends on functions in vhlab-toolbox-matlab, available at https://github.com/VH-Lab/vhlab-toolbox-matlab
Depends on functions in vhlab-thirdparty-matlab, available at https://github.com/VH-Lab/vhlab-thirdparty-matlab
It is recommended that the developer also install vhlab_vhtools, available at https://github.com/VH-Lab/vhlab_vhtools

It is assumed that the function `ndi_Init.m` is run at startup. Please add this to your `startup.m` file. (If you use the http://github.com/VH-Lab/vhlab_vhtools distribution, it will be run automatically.)

Documentation is at https://vh-lab.github.io/NDI-matlab/NDI-matlab/

Still in early development

## Description of key terms:

- **session**: A collection of measurements and analysis that are associated with one experimental session. A "study" usually consists of several sessions.

- **probe**: An instrument that makes a measurement or provides stimulation. Examples include an electrode, a camera, a 2-photon microscope, a visual stimulus monitor, a nose-poke, a feeder.

- **iodvice**: An instrument that digitally acquires and stores measurement values or controls a stimulator.

- **epoch**: An episode of time during which data from an iodevice is acquired. Each epoch consists of an interval of time between when a data acquisition device was switched on to acquire data and when it was switched off. An epoch on one device may or may not correspond to epochs from other devices, and synchronization can be managed by NDI_SYNCGRAPH.


## Description of software objects that impliment the framework:

- `ndi_session`: The class that implements the basic structure of an experiment, including an iodevice list, synggraph, cache, reference, and a unique reference string.

- `ndi_session_dir`: A session that uses the file system for storage of its parameters and database. This is presently used for all experiments.

- `ndi_iodevice`: A software object that reads data from files created by hardware data acquisition devices

- `ndi_filetree`: A file organizing class that traverses any file structure to identify the data files associated with each epoch

- Required device metadata: Classes (consisting of `ndi_iodevicestring` and `ndi_epochcontents`) that describe the probes and channel mappings between the probes and the iodevice objects.

- Database objects:
   - `ndi_database`: A (mostly) abstract database object that specifies the API for storing and searching documents
   - `ndi_document`: An extensible database document object class that has a name, a unique identifier, and fields that are described in .JSON files.
   - `ndi_binarydoc`: An abstract class that allows binary reading/writing from files associated with `ndi_document`. Specific implementations can write to a local file system, or a remote file system such as GRID-FS, etc. 
   - Implementations: Because `ndi_database` lacks specific implementation of key methods, one needs to use an implementation. Right now we have the following:
      - `ndi_matlabdumbjsondb`: A Matlab implementation of a very simple database (`dumbjsondb` in https://github.com/VH-Lab/vhlab-toolbox-matlab)
      - `ndi_binarydoc_matfid`: A Matlab implementation for reading/writing files that are on the machine's filesystem

- Timing objects
   - `ndi_clocktype`: Types of clocks (such as UTC, local, global, global experiment)
   - `ndi_timemapping`: a mapping between epochs and iodevices
   - `ndi_syncgraph`: an object that finds mappings from one device and epoch to another using all known timing relationships among iodevices
   - `ndi_syncrule`: A rule for describing the relationship between data collected on different iodevices
   - `ndi_syncrule_filematch`: A rule that describes a timing relationship as "equal" if two epochs contain raw data files in common

## Tutorials

- For developers: A tour of ndi_documents and ndi_database: https://github.com/VH-Lab/NDI-matlab/blob/master/demo/documents_database/document_database_demo.ipynb
- For developers: A tour of epochs, daqsystems, probes, and things: https://github.com/VH-Lab/NDI-matlab/blob/master/demo/epochs_daqsystems_probes_things/epochdemo1.ipynb

## Conventions

- Channels, samples, and other quantities are numbered from 1..N

## Development conventions

- Documentation of classes should follow the Matlab standard: https://www.mathworks.com/help/matlab/matlab_prog/create-help-for-classes.html

- In input arguments and documentation, we'll use "indexes" instead of "indices" and try to keep other English language exceptions to a minimum

- All error messages should be informative and give specific information about the problem, not just say 'an error occurred.'

- Most of the time, class names should include the full parentage of the object, starting with the basic classes for NDI: ndi_session, ndi_iodevice, ndi_probe. For example, a class implementing device drivers for a multifunction data aquisition board from mycompany should be called `ndi_iodevice_mfdaq_mycompany` to indicate that the object is descended from the `ndi_iodevice` and `ndi_iodevice_mfdaq` objects. Let's make exceptions if putting the full parentage gets cumbersome without adding clarity. Most users and programmers don't need to think about those classes (but will need to think about the basic classes `ndi_session`, `ndi_database`, and `ndi_iodevice`).

## Test code

There is a set of test code that one can run all at once using the function `ndi_testsuite.m`. The directory `test` contains a number of subdirectories with test code. The file `ndi_testsuite_list.txt` has an up-to-date list of the test functions that are current.
