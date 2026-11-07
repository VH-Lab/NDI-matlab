# Installation:

1. Make sure `git` is installed on your machine. If it is not, on Windows, go [here](https://git-scm.com/download/win). On Mac, open a terminal, and type xcode-select --install . Accept the license and wait for install. On Linux, consult your Linux distribution's package manager.

2. Download the file [ndi_install.m](https://raw.githubusercontent.com/VH-Lab/NDI-matlab/main/ndi_install.m) to your Desktop.
 
3. Type the following in the Matlab command window: 

    `cd ~/Desktop`

    `ndi_install`

## Choosing where the tools are installed

By default, `ndi_install` puts NDI-matlab and the tools it depends on in a folder called `tools` inside your MATLAB `userpath` (for example, `~/Documents/MATLAB/tools` on a Mac, or `Documents\MATLAB\tools` on Windows). To install them somewhere else, give `ndi_install` the full path of the folder you want:

    ndi_install('/Users/myname/code/ndi-tools')        % Mac / Linux
    ndi_install('C:\code\ndi-tools')                   % Windows

A few things to know:

* Type the full path. Shortcuts such as `~` are not expanded, so write `/Users/myname/...` rather than `~/...`.
* The folder is created if it does not exist.
* `ndi_install` still adds one line to the `startup.m` file in your `userpath`, so that MATLAB finds the tools when it starts. This line points to the folder you chose. Only that one small file stays in your `userpath`. To move the `userpath` itself, see `help userpath`.
* Updates (`ndi.update.install()`, the navigator's **Update** button, or running `ndi_install` again with no path) use the folder NDI-matlab is already in, so they keep using the folder you chose.

### Moving an existing installation

If NDI is already installed and you want the tools somewhere else:

1. Type `ndi` to open the NDI navigator and click **Prefs**.
2. Click **Tools folder...** at the bottom left. It shows where the tools are now.
3. Click **Choose new folder...** and pick where they should go. If you pick an empty folder, the tools go straight into it. Otherwise they go into a new `tools` folder inside it.
4. Click **Move**, then restart MATLAB.

This copies the tools to the new folder and checks the copy. Then it points `startup.m` at the new folder (the old `startup.m` is kept as `startup.m.bak`) and deletes the old folder. If something goes wrong before `startup.m` is changed, nothing is changed. On Windows, MATLAB may still have some files in the old folder open. If so, you are told to delete the old folder yourself after restarting MATLAB.

From the command line, the same thing is:

    ndi.update.toolsFolder()                                % where the tools are now
    ndi.update.moveToolsFolder('/Users/myname/code/ndi-tools')

## Checking for updates and updating

### The easy way: the NDI navigator

Type `ndi` in the MATLAB command window to open the NDI navigator, and click **Update** at the top of the window. You will see a list of NDI-matlab and the packages it uses, with the version you have, the latest version, and a tick box. Packages that need updating are ticked for you; click **Update** to update them. Select a row to read any notes about it, for example that MATLAB must be restarted afterwards, or that the package has changes of your own (see below).

### From the command line

    ndi.update.check()      % report whether an update is available
    ndi.update.install()    % update everything, after asking for confirmation
    ndi.update.install(Packages=["DID-matlab"])   % update only the named packages

### What gets updated

* **If you installed with `ndi_install`:** NDI-matlab and its dependencies are updated from GitHub with `git pull`. NDI-matlab must be on the `main` branch. If you have edited files in any of them, you are asked first; your edits are set aside during the update and put back afterwards. Files of your own that git does not track are left alone.
* **If you installed the toolbox (Add-On Explorer or `.mltbx`):** the latest [release](https://github.com/VH-Lab/NDI-matlab/releases) is installed over your copy, so changes you made inside the toolbox folder are lost. Restart MATLAB afterwards.

Calculator packages (`NDIcalc-*-matlab`) and NDI-python, if you have them, are checked and updated too.

NDI checks for updates once a day when it starts and prints a line if one is available. To turn this off:

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
