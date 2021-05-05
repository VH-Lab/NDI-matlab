# 1.2 Automating the reading of data from your rig or lab or collaborator

In the previous tutorial, we reviewed the steps necessary to create [ndi.daqsystem](link) objects to read in a dataset, and
to add the metadata that is necessary to tell NDI about the contents of each epoch. 

Most labs use the same data acquisition devices and file organization schemes over and over again, and many labs also store
the necessary metadata that describes the probes and subjects that are acquired. NDI allows you to create small software objects
that read this metadata directly from the laboratory files. Then, opening an experimental session becomes as simple as a one
line command such as 

```matlab
S = ndi.setup.vhlab([reference],[foldername]);
```

It's our guess that many labs have at least one person handy with code, and this task might fall to them. This tutorial is
written for people who already have some familiarity with coding. If you'd like help creating these functions for your lab,
use the [issue tracker](https://github.com/VH-Lab/NDI-matlab/issues) to post a question. Creating these automatic readers 
is the biggest stress point in using NDI. The system is relatively easy to use once you are able to read your data!

While there are many ways to organize code for custom setups, we have created a motif that is easy to follow. The `ndi` package
in Matlab has a subpackage called `setup`. Here, we have placed m-files that create an [ndi.session](link) with the default
settings for various labs or users. The `setup` package also has a subpackage structure that mimics the subpackage structure
of `ndi`. In Matlab, packages are denoted by putting a `+` in the folder name:

- `+ndi/+setup/`
  - `+daq/`
    - `+metadata/`
    - `+metadatareader/`
    - `+reader/`
    - `+system/`  

## 1.2.1 Example files for vhlab

To import data from our lab, we created 4 Matlab files:

- `+ndi/+setup/vhlab.m` - A function that builds an ndi.session object with daq systems that read from our lab's major devices.
- `+ndi/+setup/+daq/+metadata/epochprobemap_daqsystem_vhlab.m` - A class that examines our lab's metadata files that describe the mapping between probes and data acquisition systems and returns an epochprobemap that NDI can interpret. Overrides the default [ndi.daq.metadata.epochprobemap_daqsystem.m](link) class that reads the `probemap.txt` text files we saw in [Tutorial 1.1](../1_example_dataset/). 
- `+ndi/+setup/+daq/+reader/+mfdaq/+stimulus/vhlabvisspike2.m` - A class that reads stimulus event data from our custom acquisition files.
- `+ndi/+daq/+metadatareader/NewStimStims.m` - A class that imports stimulus metadata from our lab's open source [NewStim](https://github.com/VH-Lab/vhlab-NewStim-matlab) package. (We put it in NDI proper because it is an open source program, not intended solely for our lab.)

## 1.2.2 Creating a `setup` file.

The setup file accomplishes, in an automated fashion, exactly what we did in [Tutorial 1.1](../1_example_dataset/): it 
opens an [ndi.session](link) with a particular reference name and directory path, and adds the daq systems that are necessary
to read the probe data. It normally lives in `+ndi/+setup/LABORINVESTIGATORNAME.m`. We include the code here:

#### Code block 1.2.2.1: Content of `+ndi/+setup/vhlab.m`. (Do not type into Matlab command line.)

```matlab
function S = vhlab(ref, dirname)
% ndi.setup.vhlab - initialize an ndi.session.dir with VHLAB devices
%
%  S = ndi.setup.vhlab(REF, DIRNAME)
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of VHLAB devices, as
%  found in ndi.setup.daq.system.vhlab.
%
%  If the devices are already added, they are not re-created.
%

S = ndi.session.dir(ref, dirname);
vhlabdevnames = ndi.setup.daq.system.vhlab(); % returns list of daq system names

for i=1:numel(vhlabdevnames),
	dev = S.daqsystem_load('name',vhlabdevnames{i});
	if isempty(dev),
		S = ndi.setup.daq.system.vhlab(S, vhlabdevnames{i});
	end
end

 % update SYNCGRAPH
nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));
n_intan2spike2 = ndi.time.syncrule.filefind(struct('number_fullpath_matches',1, ...
	'syncfilename','vhintan_intan2spike2time.txt',...
	'daqsystem1','vhintan','daqsystem2','vhvis_spike2'));

S.syncgraph_addrule(nsf);
S.syncgraph_addrule(n_intan2spike2);
```

This function calls another function that we will see in a minute (`ndi.setup.daq.system.vhlab`) that actually builds the
daq system objects that we use in our lab. At the end of this function, 2 [ndi.time.syncrules](link) are added that describe
how synchronization is performed across our devices. If 2 or more of the same files are present in an epoch, then it is assumed
that files are from the same underlying device and they are assumed to have the same time clock. Our custom acquisition code
also produces a file `vhintan_intan2spike2time.txt` that has the time shift and scaling between our Intan acquisition system
and our CED Spike2 acquisition system, and we instruct NDI to use that file to synchronize the 2 devices using shift and scale 
in that file.

## 1.2.3 Creating a function that creates the daq systems for a lab

We also write a function that builds the daq systems that we use in our lab. This process involves 1) naming the daq system,
2) specifying the [ndi.daq.reader](link) that is used, 3) specifying any [ndi.daq.metadatareader] if necessary, and 
4) specifying the [ndi.file.navigator](link) to find the files that comprise each epoch.

If this function here is called with 0 input arguments, then it returns a list of all known daq systems objects for our lab.
Otherwise, if it is called with the name of a daq system that this function knows how to build, it builds it. It adds the
appropriate [ndi.daq.reader](link), [ndi.daq.metadatareader](link), and [ndi.file.navigator](link).

#### Code block 1.2.3.1: Content of `+ndi/+setup/+daq/+system/vhlab.m`. (Do not type into Matlab command line.)

```matlab
function S = vhlab(S, daqsystemname)
% ndi.setup.daq.system.vhlab - initialize daq systems used by VHLAB
%
% S = ndi.setup.daq.system.vhlab(S, DEVNAME)
%
% Creates daq systems that look for files in the VHLAB standard recording
% scheme, where data from different epochs are organized into
% subdirectories (using ndi.file.navigator.epochdir). DEVNAME should be the 
% name a daq systems in the table below. These daq systems are added to the ndi.session
% object S. If DEVNAME is a cell list of strings, then multiple items are added.
%
% If the function is called with no input arguments, then it returns a list
% of all valid device names.
% 
% Each epoch is defined by the presence of a 'reference.txt' file, as well
% as specific files that are needed by each device as described below.
%
%  Devices created   | Description
% |------------------|--------------------------------------------------|
% | vhintan          | ndi.daq.system.mfdaq that looks for files        |
% |                  |    'vhintan_channelgrouping.txt' and '*.rhd'     |
% | vhspike2         |    ndi.daq.system.mfdaq that looks for files     |
% |                  |    'vhspike2_channelgrouping.txt' and '*.smr'    |
% | vhvis_spike2     | ndi.daq.system.mfdaq.stimulus that looks for     |
% |                  |    files 'stimtimes.txt', 'verticalblanking.txt',|
% |                  |    'stims.mat', and 'spike2data.smr'.            |
% -----------------------------------------------------------------------
%
% See also: ndi.file.navigator.epochdir

if nargin == 0,
	S = {'vhintan', 'vhspike2', 'vhvis_spike2'};
	return;
end;

if iscell(daqsystemname),
	for i=1:length(daqsystemname),
		S = ndi.setup.daq.system.vhlab(S, daqsystemname{i});
	end
	return;
end

  % all of our daq systems use this custom epochprobemap class
epochprobemapclass = 'ndi.setup.daq.metadata.epochprobemap_daqsystem_vhlab';

switch daqsystemname,
	case 'vhintan',
		fileparameters = {'reference.txt','.*\.rhd\>','vhintan_channelgrouping.txt'};  
		readerobjectclass = ['ndi.daq.reader.mfdaq.intan'];
		epochprobemapfileparameters = {'vhintan_channelgrouping.txt'};
		mdr = {};
	case 'vhspike2',
		fileparameters = {'reference.txt', '.*\.smr\>', 'vhspike2_channelgrouping.txt'}; 
		readerobjectclass = ['ndi.daq.reader.mfdaq.cedspike2'];
		epochprobemapfileparameters = {'vhspike2_channelgrouping.txt'};
		mdr = {};
	case 'vhvis_spike2'
		fileparameters = {'reference.txt', 'stimtimes.txt', 'verticalblanking.txt',...
			'stims.mat', 'spike2data.smr'}; 
		readerobjectclass = ['ndi.setup.daq.reader.mfdaq.stimulus.vhlabvisspike2'];
		epochprobemapfileparameters = {'stimtimes.txt'}; 
		mdr = {ndi.daq.metadatareader.NewStimStims('stims.mat')};
	otherwise,
		error(['Unknown device requested ' daqsystemname '.']);
end

ft = ndi.file.navigator.epochdir(S, fileparameters, epochprobemapclass, epochprobemapfileparameters);

eval(['dr = ' readerobjectclass '();']);

mydev = ndi.daq.system.mfdaq(daqsystemname, ft, dr, mdr); % create the daq system object
S = S.daqsystem_add(mydev); % add the daq system object to our ndi.session
```

Let's look at the creation of these daq system objects in detail. 

- `vhintan` - This daq system looks for groups of files with one file named `reference.txt`, a file that ends in `.rhd`, and
another file called `vhintan_channelgrouping.txt`. These files are produced by the computer that runs our main acquisition on our rigs, when an Intan acquisition device is used. Together, `reference.txt` and `vhintan_channelgrouping.txt` have information
about the probes that were used in that recording and the channel mapping of those probes. We will look at these in more detail later. We use the reader `ndi.daq.reader.mfdaq.intan`, which knows how to read channel data from Intan .rhd files. We tell our
daq.system object that 'vhintan_channelgrouping.txt' is the file to use to read epochprobemap information (we will instruct it
how to interpret the data in a later function), and there is no metadata reader `mdr`. We also tell ndi.file.navigator that
all of these files will appear in subfolders within our main folder by using the [ndi.file.navigator.epochdir](link) class.

- `vhspike2` - This daq system is very similar to `vhintan`, except that it looks for files that end in .smr and looks for a
different epochmap metadata file (`vhspike2_channelgrouping.txt`).

- `vhvis_spike2` - This system is more custom. It relies on text files that are generated by our scripts that run on our CED Micro1401 acquisition system: `stimtimes.txt`, `verticalblanking.txt`, `spike2data.smr`, and a file generated by our visual stimulation system called `stims.mat`. We add a metadatareader `ndi.daq.metadatareader.NewStimStims` that knows how to interpret the `stims.mat` file. We will cover this custom [ndi.daq.reader](link) next.



