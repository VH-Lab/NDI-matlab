# NSD
NeuroScience Data framework - A means of specifying and accessing neuroscience data

Available at https://github.com/VH-Lab/NSD

Depends on functions in vhlab_mltbx_toolbox, available at https://github.com/VH-Lab/vhlab_mltbx_toolbox
Depends on functions in vhlab_thirdparty, available at https://github.com/VH-Lab/vhlab_thirdparty
It is recommended that the developer also install vhlab_vhtools, available at https://github.com/VH-Lab/vhlab_vhtools

Still in early development

## Description:

- **device**: Any device that is used for a specific experiment.

- **datatree**: An file organizing class that create any file structure associated with a specific device.

    + flat:

    + epochdir:

- **record**: An data class (consist of devicestring and epochrecord) that work between the device objects and the datatree objects. Each epoch contains data for more than one files within the dataree for that device.

    + vhintan:


## Development conventions

- Channels, samples, and other quantities are numbered from 1..N

- Documentation of classes should follow the Matlab standard: https://www.mathworks.com/help/matlab/matlab_prog/create-help-for-classes.html

- In input arguments and documentation, we'll use indexes instead of indices and try to keep other English language exceptions to a minimum

- All error messages should be informative and give specific information about the problem, not just say 'an error occurred.'
