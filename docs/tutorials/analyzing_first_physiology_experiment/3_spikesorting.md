# Tutorial 2: Analyzing your first electrophysiology experiment with NDI

## Tutorial 2.3: Using apps to analyze data (spike sorting)

You've seen how to read data from probes in NDI. Now suppose we want to do some analysis of this data? How would we do it?

Clearly, one could write functions in Matlab that read the data and perform some sort of analysis. But it would be
great to share (or borrow) those functions across the open source community, and to develop "apps" that excel at performing
specific tasks. NDI allows both approaches.

### Tutorial 2.3.1: What is an 'app' in NDI? [ndi.app](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/app.m/) objects

An app for our purposes is any application program that can read data from NDI and perform some analysis or
computation on this data. Some apps exist outside of NDI, and know how to read data from NDI experiments and
write results back to NDI experimental sessions. One example of such an app is the spike sorting program
JRClust. 

There is another set of apps that are developed specifically for NDI that are members of a special parent class
called ndi.app. This parent class performs some services to help app developers maintain a consistant approach to
make it easier for users and programmers that want to use the app to easily figure out what it does and how to 
use it. 

Here, we will examine one of these apps that we made for spike extraction. Just like Windows computers come with
NotePad and Mac computers come with TextEdit, our [ndi.app.spikeextractor](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/spikeextractor.m/) is a plain-but-usable program for
extracting spike waveforms from voltage records. It is suitable for spike extraction situations where the channel count for each electrode is low, such as single electrodes or tetrodes. It is not suitable for dense, multichannel electrodes like NeuroPixels or dense NeuroNexus probes.

We will use the program first as though we knew how to use it by magic, and then we will go through how one could
figure out how to use the program if one didn't know.

### Tutorial 2.3.2: Extracting spikes using [ndi.app.spikeextractor](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/spikeextractor.m/)

#### Code block 2.3.2.1. Type this into Matlab.

```matlab
dirname = [userpath filesep 'Documents' filesep 'NDI' filesep 'ts_exper2']; % change this if you put the example somewhere else
ref = 'ts_exper2';
S = ndi.session.dir(ref,dirname);  

% let's find our probes that correspond to extracellular electrodes

p = S.getprobes('type','n-trode');

% make a new app instance
se = ndi.app.spikeextractor(S);

% find out what the spike extraction parameters are
extraction_param_struct = se.defaultstruct_appdoc('extraction_parameters');
% if we wanted to modify these parameters, we could
% for now, let's proceed with the defaults

% we will add a parameter document to our database that our extractor will use

my_extraction_name = 'my_extraction_params';
extraction_param_doc = se.add_appdoc('extraction_parameters',extraction_param_struct,'Replace',my_extraction_name);

% now let's perform the extraction over all epochs

redo = 1; % redo it if we already did it
 % we know there are two probes, so do it for both
se.extract(p{1},[],my_extraction_name,redo);
se.extract(p{2},[],my_extraction_name,redo);

```

Now, let's take a look at what we extracted:

#### Code block 2.3.2.2 Type this into Matlab.

```matlab
% now let's take a look at what we got for the first probe, first epoch
epoch_id = 't00001';

[spikes,waveparameters,spikewaves_doc] = se.loaddata_appdoc('spikewaves',p{1},epoch_id,my_extraction_name);

% let's plot these waveforms

t_spike = [waveparameters.S0:waveparameters.S1] * 1/waveparameters.samplerate; % create a time vector

% spikes is a 3-d matrix.
% The first dimension has the number of samples per spike.
% The second dimension has data from each channel. Because this is a single electrode, there is only one channel. If it were a tetrode, this would be 4.
% The third dimension is the number of spikes detected.
size(spikes)

figure(101);
plot(t_spike,squeeze(spikes));
xlabel('Time (s)');
ylabel('Voltage');
box off;

% We can see how we did by plotting the spike times back with the raw data:

[spiketimes,spiketimes_doc] = se.loaddata_appdoc('spiketimes',p{1},epoch_id,my_extraction_name);

[d,t] = readtimeseries(p{1},epoch_id,-Inf,Inf);
figure(102);
plot(t,d);
hold on;
samples = round(vlt.signal.value2sample(spiketimes, 1/(t(2)-t(1)), 0));
plot(t(samples),d(samples),'ko'); % mark each spike peak location with a circle 
```


