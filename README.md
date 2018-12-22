# NSD
NeuroScience Data framework - A means of specifying and accessing neuroscience data

Available at https://github.com/VH-Lab/NSD-matlab

Depends on functions in vhlab-toolbox-matlab, available at https://github.com/VH-Lab/vhlab-toolbox-matlab
Depends on functions in vhlab-thirdparty-matlab, available at https://github.com/VH-Lab/vhlab-thirdparty-matlab
It is recommended that the developer also install vhlab_vhtools, available at https://github.com/VH-Lab/vhlab_vhtools

It is assumed that the function `nsd_Init.m` is run at startup. Please add this to your `startup.m` file. (If you use the http://github.com/VH-Lab/vhlab_vhtools distribution, it will be run automatically.)


Still in early development

## Description of key terms:

- **experiment**: A collection of measurements and analysis that are associated with one experimental session. A "study" usually consists of several experiments.

- **probe**: An instrument that makes a measurement or provides stimulation. Examples include an electrode, a camera, a 2-photon microscope, a visual stimulus monitor, a nose-poke, a feeder.

- **iodvice**: An instrument that digitally acquires and stores measurement values or controls a stimulator.

- **epoch**: An episode of time during which data from an iodevice is acquired. Each epoch consists of an interval of time between when a data acquisition device was switched on to acquire data and when it was switched off. An epoch on one device may or may not correspond to epochs from other devices, and synchronization can be managed by NSD_SYNCGRAPH.


## Description of software objects that impliment the framework:

- `nsd_experiment`: The class that implements the basic structure of an experiment, including an iodevice list, synggraph, cache, reference, and a unique reference string.

- `nsd_experiment_dir`: An experiment that uses the file system for storage of its parameters and database. This is presently used for all experiments.

- `nsd_iodevice`: A software object that reads data from files created by hardware data acquisition devices

- `nsd_filetree`: A file organizing class that traverses any file structure to identify the data files associated with each epoch

- Required device metadata: Classes (consisting of `nsd_iodevicestring` and `nsd_epochcontents`) that describe the probes and channel mappings between the probes and the iodevice objects.

- Database objects:
   - `nsd_database`: A (mostly) abstract database object that specifies the API for storing and searching documents
   - `nsd_document`: An extensible database document object class that has a name, a unique identifier, and fields that are described in .JSON files.
   - `nsd_binarydoc`: An abstract class that allows binary reading/writing from files associated with `nsd_document`. Specific implementations can write to a local file system, or a remote file system such as GRID-FS, etc. 
   - Implementations: Because `nsd_database` lacks specific implementation of key methods, one needs to use an implementation. Right now we have the following:
      - `nsd_matlabdumbjsondb`: A Matlab implementation of a very simple database (`dumbjsondb` in https://github.com/VH-Lab/vhlab-toolbox-matlab)
      - `nsd_binarydoc_matfid`: A Matlab implementation for reading/writing files that are on the machine's filesystem

## Conventions

- Channels, samples, and other quantities are numbered from 1..N

## Development conventions

- Documentation of classes should follow the Matlab standard: https://www.mathworks.com/help/matlab/matlab_prog/create-help-for-classes.html

- In input arguments and documentation, we'll use "indexes" instead of "indices" and try to keep other English language exceptions to a minimum

- All error messages should be informative and give specific information about the problem, not just say 'an error occurred.'

- Most of the time, class names should include the full parentage of the object, starting with the basic classes for NSD: nsd_experiment, nsd_iodevice, nsd_probe. For example, a class implementing device drivers for a multifunction data aquisition board from mycompany should be called `nsd_iodevice_mfdaq_mycompany` to indicate that the object is descended from the `nsd_iodevice` and `nsd_iodevice_mfdaq` objects. Let's make exceptions if putting the full parentage gets cumbersome without adding clarity. Most users and programmers don't need to think about those classes (but will need to think about the basic classes `nsd_experiment`, `nsd_database`, and `nsd_iodevice`).

## Test code

There is a set of test code that one can run all at once using the function `nsd_testsuite.m`. The directory `test` contains a number of subdirectories with test code. The file `nsd_testsuite_list.txt` has an up-to-date list of the test functions that are current.
