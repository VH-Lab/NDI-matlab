# Tutorial 2: Analyzing your first electrophysiology experiment with NDI

## 2.2 Automating the reading of data from your rig or lab or collaborator

In the previous tutorial, we reviewed the steps necessary to create [ndi.daq.system](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bdaq/system.m/) objects to read in a dataset, and
to add the metadata that is necessary to tell NDI about the contents of each epoch. 

Most labs use the same data acquisition devices and file organization schemes over and over again, and many labs also store
the necessary metadata that describes the probes and subjects that are acquired. NDI allows you to create small software objects
that read this metadata directly from the laboratory files. Then, opening an experimental session becomes as simple as a one
line command such as 

```matlab
S = ndi.setup.vhlab([reference],[foldername]);
```

Once this command has been run once, the directory can be opened with the standard `ndi.session.dir` command thereafter
(though there is no harm to re-issuing the `ndi.setup.*` command).

It's our guess that many labs have at least one person handy with code, and this task might fall to them. This tutorial is
written for people who already have some familiarity with coding. If you'd like help creating these functions for your lab,
use the [issue tracker](https://github.com/VH-Lab/NDI-matlab/issues) to post a question. Creating these automatic readers 
is the biggest stress point in using NDI. The system is relatively easy to use once you are able to read your data!

While there are many ways to organize code for custom setups, we have created a motif that is easy to follow. The `ndi` package
in Matlab has a subpackage called `setup`. Here, we have placed m-files that create an [ndi.session](https://vh-lab.github.io/NDI-matlab/reference/+ndi/session.m/) with the default
settings for various labs or users. The `setup` package also has a subpackage structure that mimics the subpackage structure
of `ndi`. In Matlab, packages are denoted by putting a `+` in the folder name:

- `+ndi/+setup/`
  - `+daq/`
    - `+metadata/`
    - `+metadatareader/`
    - `+reader/`
    - `+system/`  

### 2.2.1 Download an experiment with all vhlab metadata left intact 

Please download an example data directory called [ts_exper2](https://drive.google.com/file/d/1otNMkVgZ6KBIn2Y-W2oYVj2DgSOgV-xE/view?usp=sharing). Be sure to unzip the files, and we recommend placing them in your Matlab userpath under 'MATLAB/Documents/NDI/' as before. This directory contains the files that were generated at the
time of acquisition on Steve's rig in the Fitzpatrick lab at Duke, which is nearly identical to the format that we use in the
vhlab now. You'll see that these directories have a few more files. It's not necessary to follow the identities of the files in detail, but let's look at what is in t00001 as an example:

- `t00001`
  - `filetime.txt` - The time of the acquisition beginning in seconds from midnight
  - `reference.txt` = A file describing the probes that are present in this directory
  - `spike2data.S2R` - This is an irrelevant file! But it's there every time.
  - `spike2data.smr` - The raw data file acquired by CED's program Spike2 (data acquired via Micro1401)
  - `spike2datalog.txt` - A text log file (not relevant)
  - `stims.mat` - The record of stimulation as produced by the stimulus computer. It uses [NewStim](http://github.com/VH-Lab/vhlab-NewStim-matlab) stimuli and is written by VH lab's [RunExperiment](http://github.com/VH-Lab/vhlab-RunExperiment-matlab) program.
  - `stimtimes.txt` - A text file where each line contains a) the stimulus onset trigger, b) the stimulus ID number between 1-255, and c) an array of video frame trigger times (when the video frame was changed)
  - `twophotontimes.txt` - A record of triggers of all 2-photon frames. None in this experiment.
  - `verticalblanking.txt` - A record of each refresh of the monitor. This was not yet used in these experiments but is now part of the VH lab's suite.
  - `vhspike2_channelgrouping.txt` - A text file that indicates which acquisition channels of our vhspike2 DAQ system are connected to each probe.


### 2.2.2 Example NDI-matlab files for vhlab

To import data from our lab, we created 4 Matlab files:

- `+ndi/+setup/vhlab.m` - A function that builds an ndi.session object with daq systems that read from our lab's major devices.
- `+ndi/+setup/+daq/+metadata/epochprobemap_daqsystem_vhlab.m` - A class that examines our lab's metadata files that describe the mapping between probes and data acquisition systems and returns an epochprobemap that NDI can interpret. Overrides the default [ndi.epoch.epochprobemap_daqsystem.m](https://vh-lab.github.io/NDI-matlab/reference/+ndi/%2Bepoch/epochprobemap_daqsystem.m/) class that reads the `probemap.txt` text files we saw in [Tutorial 2.1](../1_example_dataset/). 
- `+ndi/+setup/+daq/+reader/+mfdaq/+stimulus/vhlabvisspike2.m` - A class that reads stimulus event data from our custom acquisition files.
- `+ndi/+daq/+metadatareader/NewStimStims.m` - A class that imports stimulus metadata from our lab's open source [NewStim](https://github.com/VH-Lab/vhlab-NewStim-matlab) package. (We put it in NDI proper because it is an open source program, not intended solely for our lab.)

### 2.2.3 Creating a `setup` file.

The setup file accomplishes, in an automated fashion, exactly what we did in [Tutorial 2.1](../1_example_dataset/): it 
opens an [ndi.session](https://vh-lab.github.io/NDI-matlab/reference/+ndi/session.m/) with a particular reference name and directory path, and adds the daq systems that are necessary
to read the probe data. It normally lives in `+ndi/+setup/LABORINVESTIGATORNAME.m`. We include the code here:

#### Code block 2.2.3.1: Content of `+ndi/+setup/vhlab.m`. (Do not type into Matlab command line.)

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
daq system objects that we use in our lab. At the end of this function, 2 [ndi.time.syncrules](https://vh-lab.github.io/NDI-matlab/reference/+ndi/%2Btime/syncrule.m/) are added that describe
how synchronization is performed across our devices. If 2 or more of the same files are present in an epoch, then it is assumed
that files are from the same underlying device and they are assumed to have the same time clock. Our custom acquisition code
also produces a file `vhintan_intan2spike2time.txt` that has the time shift and scaling between our Intan acquisition system
and our CED Spike2 acquisition system, and we instruct NDI to use that file to synchronize the 2 devices using shift and scale 
in that file.

### 2.2.4 Creating a function that creates the daq systems for a lab

We also write a function that builds the daq systems that we use in our lab. This process involves 1) naming the daq system,
2) specifying the [ndi.daq.reader](https://vh-lab.github.io/NDI-matlab/reference/+ndi/%2Bdaq/reader.m/) that is used, 3) specifying any [ndi.daq.metadatareader](https://vh-lab.github.io/NDI-matlab/reference/+ndi/%2Bdaq/metadatareader.m/) if necessary, and 
4) specifying the [ndi.file.navigator](https://vh-lab.github.io/NDI-matlab/reference/+ndi/+file/navigator.m/) to find the files that comprise each epoch.

If this function here is called with 0 input arguments, then it returns a list of all known daq systems objects for our lab
(`'vhintan', 'vhspike2', 'vhvis_spike2'`).
Otherwise, if it is called with the name of a daq system that this function knows how to build, it builds it. It adds the
appropriate [ndi.daq.reader](https://vh-lab.github.io/NDI-matlab/reference/+ndi/%2Bdaq/reader.m/), [ndi.daq.metadatareader](https://vh-lab.github.io/NDI-matlab/reference/+ndi/%2Bdaq/metadatareader.m/), and [ndi.file.navigator](https://vh-lab.github.io/NDI-matlab/reference/+ndi/+file/navigator.m/).

#### Code block 2.2.4.1: Content of `+ndi/+setup/+daq/+system/vhlab.m`. (Do not type into Matlab command line.)

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
all of these files will appear in subfolders within our main folder by using the [ndi.file.navigator.epochdir](https://vh-lab.github.io/NDI-matlab/reference/+ndi/+file/%2Bnavigator/epochdir.m/) class.

- `vhspike2` - This daq system is very similar to `vhintan`, except that it looks for files that end in .smr and looks for a
different epochmap metadata file (`vhspike2_channelgrouping.txt`).

- `vhvis_spike2` - This system is more custom. It relies on text files that are generated by our scripts that run on our CED Micro1401 acquisition system: `stimtimes.txt`, `verticalblanking.txt`, `spike2data.smr`, and a file generated by our visual stimulation system called `stims.mat`. We add a metadatareader `ndi.daq.metadatareader.NewStimStims` that knows how to interpret the `stims.mat` file. We will cover this custom [ndi.daq.reader](https://vh-lab.github.io/NDI-matlab/reference/+ndi/%2Bdaq/reader.m/) next.

### 2.2.5 Creating a custom [ndi.daq.reader.mfdaq.stimulus](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bsetup/%2Bdaq/%2Breader/%2Bmfdaq/%2Bstimulus/vhlabvisspike2.m/) object:

Our visual stimulation system produces a variety of event data, including information about stimulus onset and offset, the
vertical refresh signal from the monitor, an 8-bit code for each stimulus ID, a video frame trigger (every time we update the
image on the screen), and a signal we call the "pretime" trigger that is generally issued 0.5 seconds _before_ a stimulus is
begun (used for baseline subtracting in intrinsic signal imaging experiments among other applications).

Our acquisition system running on a CED Micro1401 generates text files related to these events, and we propagate them through
as a set of event channels. We define 5 fixed channels for our daq system: 

- `mk1`: a marker channel that indicates stim ON (+1) or stim OFF (-1)
- `mk2`: a marker channel that indicates the 8-bit stimulus identifier (stimid)
- `mk3`: a marker channel that indicates when the stimulus period opens (+1) and closes (-1); this includes interstimulus "background" time
- `e1`: an event channel that indicates each frame trigger / video frame update
- `e2`: an event channel that indicates the vertical refresh times of the stimulus monitor
- `e3`: an event channel that indicates the pre-stimulus trigger (indicates stimulus is upcoming, usually 0.5s away)

Rather than copying the entire code here, we will include a link to the file: [ndi.setup.daq.reader.mfdaq.stimulus.vhlabvisspike2.m](https://raw.githubusercontent.com/VH-Lab/NDI-matlab/master/%2Bndi/%2Bsetup/%2Bdaq/%2Breader/%2Bmfdaq/%2Bstimulus/vhlabvisspike2.m) . It should be relatively
self-explanitory for someone with a coding background to read and mimic this file.

### 2.2.6 Creating a custom epochprobemap class

In [Tutorial 2.1](../1_example_dataset/), we saw that each epoch of data had an associated epochprobemap that contained the 
following fields of information:

| name | reference | type | devicestring | subjectstring |
| ---- | --------- | ---- | ------------ | ------------- |
|  ctx |      1    |  n-trode          | ced_daqsystem:ai11 | treeshrew_12345@mylab.org |
| vis_stim | 1 | stimulator | vis_daqsystem:mk30;text30;md1 | treeshrew_12345@mylab.org |

We need to write a substitute class that is a subclass of [ndi.epoch.epochprobemap](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bepoch/epochprobemap.m/) that reads the epoch information and returns all of this same information.

In our vhlab session directories, we always have a single subject whose unique identifier is specified in a text file called
`subject.txt` in the top directory. This file is read, and this text is used as the `subjectstring` for all probes.

In each vhlab epoch directory, we have a file called `reference.txt` that includes the name, reference, and type of recording
present in each epoch. Our class's creator reads this file, and uses it to pull out the `name` and `reference` number for all
electrode (or imaging) probes. 

If our `reference.txt` file indicates that our vhlab "type" is singleEC (single extracellular) or 'ntrode', then it looks for
other text files that contain a mapping between the name and reference of each probe and the channels that were used on a
recording device to acquire it. In this experiment, we have `vhspike2_channelgrouping.txt` that indicates that our
probe 'ctx | 1' was acquired on channel 11 of our CED Micro1401/Spike2 system. 

Finally, if a file named `stimtimes.txt` exists in the epoch directory, then we add in an epochprobemap entry for our visual
stimulator:

| name | reference | type | devicestring | subjectstring |
| ---- | --------- | ---- | ------------ | ------------- |
| vis_stim | 1 | stimulator | vhvis_spike2:mk1-3;e1-3;md1 | treeshrew_12345@mylab.org |

We will not reproduce the code here but refer the reader to the [link for the source code](https://raw.githubusercontent.com/VH-Lab/NDI-matlab/master/%2Bndi/%2Bsetup/%2Bepoch/epochprobemap_daqsystem_vhlab.m) of the class ndi.setup.epoch.epochprobemap_daqsystem_vhlab that is a subclass of [ndi.epoch.epochprobemap_daqsystem](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bepoch/epochprobemap.m/).

### 2.2.7 Putting it all together

Now that we have these pieces together, we can read our example data that we call `ts_exper2`. We will pull up the same plots that we pulled up in [Tutorial 2.1](../1_example_dataset/).

#### Code block 2.2.7.1 Type this into Matlab

```matlab
prefix = [userpath filesep 'Documents' filesep 'NDI']; % if you put the folder somewhere else, edit this
S = ndi.setup.vhlab('ts_exper2',[prefix filesep 'ts_exper2']);

p_ctx1_list = S.getprobes('name','ctx','reference',1) % returns a cell array of matches
p_ctx1 = p_ctx1_list{1}; % take the first one, should be the only one

epoch_to_read = 1;
[data,t,timeref_p_ctx1]=p_ctx1.readtimeseries(epoch_to_read,-Inf,Inf); % read all data from epoch 1
figure(100);
plot(t,data);
xlabel('Time(s)');
ylabel('Voltage (V)');
set(gca,'xlim',[t(1) t(end)]);
box off;

p_visstim_list = S.getprobes('type','stimulator') % returns a cell array of matches
p_visstim = p_visstim_list{1}; % take the first one, should be the only one
[data,t,timeref_stim]=p_visstim.readtimeseries(timeref_p_ctx1,-Inf,Inf); % read all data from epoch 1 of p_ctx1 !
figure(100);
hold on;
vlt.neuro.stimulus.plot_stimulus_timeseries(7,t.stimon,t.stimoff,'stimid',data.stimid);
```

If you are paying close attention, you'll notice we got a little more information out of the `readtimeseries` command here. `t.stimoff` exists (it's extracted from our stimulus metadata), so we don't have to know the stimulus duration from elsewhere. That information is not directly accessible in the event record of the smr file, so there is an advantage to reading all the metadata that is available from all sources with a custom object.

### 2.2.8 Conclusion

This concludes our tutorial on setting up code files to read one's own data and metadata into NDI.

To help make this process clearer, we also include 3 other case studies in reading data (tutorials currently under construction):

-  Alessandra Angelluci lab (reads unpublished recording)
-  Don Katz lab (reads [Mukherjee et al., 2019](https://pubmed.ncbi.nlm.nih.gov/31232693/)) 
-  Eve Marder lab (reads [Hamood et al., 2015](https://pubmed.ncbi.nlm.nih.gov/25914899/))


