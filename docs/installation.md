# Installation:

1. Make sure `git` is installed on your machine. If it is not, on Windows, go [here](https://git-scm.com/download/win). On Mac, open a terminal, and type xcode-select --install . Accept the license and wait for install. On Linux, consult your Linux distribution's package manager.

2. Download the file [ndi_install.m](https://raw.githubusercontent.com/VH-Lab/NDI-matlab/master/ndi_install.m) to your Desktop.
 
3. Type the following in the Matlab command window: 

    `cd ~/Desktop`

    `ndi_install`

## Required Matlab toolboxes

To use all of the NDI tools, the following Matlab toolboxes are required:

| Toolbox | Toolbox | Toolbox |
| -- | -- | -- |
| MATLAB | Simulink | Control System Toolbox |
| Curve Fitting Toolbox | Image Processing Toolbox | Optimization Toolbox |
| Signal Processing Toolbox | Simscape | Statistics and Machine Learning Toolbox |

You can use the `ver` command in Matlab to see which toolboxes you have installed.

## Notes for newbies

1. To find the program Terminal on a Mac, use the Mac search menu to find it and run it.

2. To download the [ndi_install.m](https://raw.githubusercontent.com/VH-Lab/NDI-matlab/master/ndi_install.m) file, right click in your browser and choose "Save as". Be sure to save the file with a '.m' extension; your browser may try to add '.txt' to the end of the file, but you'll need to remove it for the program to run.

3. If you lack particular Matlab Toolboxes, you can add them by clicking on the Add-On box in Matlab and choose "Get Add-ons".
