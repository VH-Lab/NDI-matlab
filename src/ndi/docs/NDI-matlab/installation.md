# Installation:

1. Make sure `git` is installed on your machine. If it is not, on Windows, go [here](https://git-scm.com/download/win). On Mac, open a terminal, and type xcode-select --install . Accept the license and wait for install. On Linux, consult your Linux distribution's package manager.

2. Download the file [ndi_install.m](https://raw.githubusercontent.com/VH-Lab/NDI-matlab/main/ndi_install.m) to your Desktop.
 
3. Type the following in the Matlab command window: 

    `cd ~/Desktop`

    `ndi_install`

## Checking for updates and updating

NDI-matlab can check for a newer version and update itself, whichever way you installed it:

    ndi.update.check()      % report whether an update is available
    ndi.update.install()    % update, after asking for confirmation

* **Installed with `ndi_install` (git):** your copy is compared with the latest commit on the `main` branch on GitHub, and the dependency repositories `ndi_install` placed next to NDI-matlab are compared with their own upstream branches. Updating runs `ndi_install` again, which pulls the changes. Your NDI-matlab clone must be on the `main` branch. If you have changed code in NDI-matlab or one of those repositories (edited tracked files, or made local commits), the updater lists the changes and asks whether to update anyway, with No as the default. If you go ahead, edited files are stashed (get them back with `git stash pop` in that folder) and local commits are merged with the update. Untracked files of your own (scripts, notes, data) are left alone and need no answer, unless one sits where the update adds a file of the same name: git will not overwrite it, so the updater stops before starting and asks you to move it.
* **Installed as a toolbox (Add-On Explorer or `.mltbx`):** your installed version is compared with the latest [GitHub release](https://github.com/VH-Lab/NDI-matlab/releases). Updating downloads that release's `.mltbx` and installs it over the current one, so any files you changed or added inside the installed toolbox folder are lost; restart MATLAB afterwards. You can also update from the Add-On Manager.

If NDI-python is installed (for the napari viewers, see `ndi.python.install`), it is checked too, against the latest commit on its `main` branch, and `ndi.update.install()` and the navigator's **Update** button offer to update it by running its installer again.

NDI also checks once a day when it starts and prints one line if an update is available. To turn this off:

    ndi.preferences.set('Update.CheckOnStartup', false)

## Required Matlab toolboxes

To use all of the NDI tools, the following Matlab toolboxes are required:

| Toolbox | Toolbox | Toolbox |
| -- | -- | -- |
| MATLAB | Control System Toolbox | Curve Fitting Toolbox |
| Image Processing Toolbox | Optimization Toolbox | Signal Processing Toolbox |
| Statistics and Machine Learning Toolbox | | | 

You can use the `ver` command in Matlab to see which toolboxes you have installed.

## Notes for newbies

1. To find the program Terminal on a Mac, use the Mac search menu to find it and run it.

2. To download the [ndi_install.m](https://raw.githubusercontent.com/VH-Lab/NDI-matlab/main/ndi_install.m) file, right click in your browser and choose "Save as". Be sure to save the file with a '.m' extension; your browser may try to add '.txt' to the end of the file, but you'll need to remove it for the program to run.

3. If you lack particular Matlab Toolboxes, you can add them by clicking on the Add-On box in Matlab and choose "Get Add-ons".
