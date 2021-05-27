# Contributing

Anyone with a GitHub account can contribute. Please see the guidelines below!

# Tasks

## New file formats

If you want to contribute an ndi.daq.reader for a new file format, please see our new project Neuroscience Data Readers [NDR-matlab](http://ndr.vhlab.org). We have spun off the job of reading raw neuroscience data files into this project to make it easier to contribute file readers and because some users may want to just use the file reading code without installing all of NDI.

At the moment, NDI still uses its native `ndi.daq.reader` objects but soon it will be able to use any `ndr.reader` object, which will streamline the addition of new file formats.

## Apps

There are 2 ways to contribute applications. 

### ndi.app applications

We have plans to shortly create a developer's guide to creating ndi.app applications that are tightly integrated with NDI's core features. Stay tuned! 

### Other applications

External applications can use NDI right now. For an example, see our changes to JRClust to make it support NDI: [https://github.com/VH-Lab/JRCLUST](https://github.com/VH-Lab/JRCLUST). Feel free to [post an issue](https://github.com/VH-Lab/NDI-matlab/issues) to ask questions.

# How to contribute

If you have code that you would like to write, do the following.

1. Press the Fork button in the upper-right corner of the [NDI-matlab](https://github.com/VH-Lab/NDI-matlab/) GitHub repository to make a copy of NDR in your own GitHub space.

2. Make your changes to NDI-matlab.

3. Commit your changes back to your fork.

4. Finally, issue a Pull Request on GitHub from your fork. The request will be received by the NDI development team for integration.


