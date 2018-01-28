# NSD
NeuroScience Data framework - A means of specifying and accessing neuroscience data

Available at https://github.com/VH-Lab/NSD

Depends on functions in vhlab_mltbx_toolbox, available at https://github.com/VH-Lab/vhlab_mltbx_toolbox
Depends on functions in vhlab_thirdparty, available at https://github.com/VH-Lab/vhlab_thirdparty
It is recommended that the developer also install vhlab_vhtools, available at https://github.com/VH-Lab/vhlab_vhtools

It is assumed that the function `nsd_Init.m` is run at startup. Please add this to your `startup.m` file. (If you use the http://github.com/VH-Lab/vhlab_vhtools distribution, it will be run automatically.)



Still in early development

## Description of terms:

- Experiment: A collection of measurements and analysis that are associated with one experimental session. A "study" usually consists of several experiments.

- Epoch: An episode of time during which data from a device is acquired. Each epoch consists of an interval of time when a data acquisition device was acquiring data and when it was switched off. An epoch on one device may or may not correspond to epochs from other devices, and synchronization can be managed by NSD_CLOCK.

## Description of software objects that impliment the framework:

- nsd_device: A software object that reads data from files created by hardware data acquisition devices

- nsd_filetree: A file organizing class that traverses any file structure to identify the data files associated with each epoch

- device metadata: Classes (consisting of devicestring and epochrecord) that work between the device objects and the filetree objects.

- Database objects:
   - nsd_base: A database object that has a unique identifier and can be saved to disk
   - nsd_leaf: A database object that has a name, fields and values, and a unique identifier.
   - nsd_leaf_branch: A database object that can consist of a number of db_leaf objects or nsd_leaf_branch objects (a database tree, in other words)

## Conventions

- Channels, samples, and other quantities are numbered from 1..N

## Development conventions

- Documentation of classes should follow the Matlab standard: https://www.mathworks.com/help/matlab/matlab_prog/create-help-for-classes.html

- In input arguments and documentation, we'll use indexes instead of indices and try to keep other English language exceptions to a minimum

- All error messages should be informative and give specific information about the problem, not just say 'an error occurred.'

- In general, class names should include the full parentage of the object, starting with the basic classes for NSD: nsd_experiment, nsd_variable, nsd_device. For example, a class implementing device drivers for a multifunction data aquisition board from mycompany should be called 'nsd_device_mfdaq_mycompany' to indicate that the bject is descended from the nsd_device and nsd_device_mfdaq objects. It is not necessary to include the full parentage on nsd_base and nsd_dbleaf objects, as it would get too cumbersome without adding much clarity. Most users and programmers don't need to think about those classes (but will need to think about the basic classes nsd_experiment, nsd_variable, and nsd_device).

