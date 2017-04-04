# NSD
NeuroScience Data framework - A means of specifying and accessing neuroscience data

Available at https://github.com/VH-Lab/NSD

Depends on functions in vhlab_mltbx_toolbox, available at https://github.com/VH-Lab/vhlab_mltbx_toolbox

Still in early development

## Description:

-**device**: Any device that is used for a specific experiment.

-**datatree**: An file organizing class that create any file structure associated with a specific device.

...flat:

...epochdir:

-**record**: An data class (consist of devicestring and epochrecord) that work between the device objects and the datatree objects. Each epoch contains data for more than one files within the dataree for that device.

...vhintan:
