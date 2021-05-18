# Tutorial 2: Analyzing your first electrophysiology experiment with NDI

## Tutorial 2.3: Using apps to analyze data (spike sorting)

(We're building this tutorial now. Only partially finished! Stay tuned.)

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


### 2.3.3 Spike sorting using [ndi.app.spikesorter](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/spikesorter.m/)

Now we will feed our results to our plain spikesorting application, which relies on the KlustaKwik clustering tool (Harris KD, *J. Neurophys.*, 2000).

*more here*

### 2.3.4 Manually curating the clusters

*more here*

### 2.3.5 How can we learn about the functionality of [ndi.app](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/app.m) objects?

In section 2.2, we used [ndi.app.spikeextractor](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/spikeextractor.m/) as though we were born knowning what to do. How could we learn how to use a new app if there isn't a tutorial available?

There are three great ways to learn about what apps do and how to use them. 

1. Read the main documentation for the app by typing `help *appclass*` or `doc *appclass*` into the Matlab command line. For example, try `help ndi.app.spikeextractor`.

2. Many apps follow what we call the ``appdoc`` convention for creating the documents that they create and loading the documents and data that they have generated. This is a convention that have developed relatively recently, and we are in the process of converting all of our included ndi.app objects to use this form. If an app follows [ndi.app.appdoc](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/appdoc.m/) (which means it is a member of the [ndi.app.appdoc](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/appdoc.m/) class), then they will have a set of methods called:

| Method | Description |
| ------ | ------      |
| *appdoc_description* | The help information should have a full description of all database documents that are produced by the application. Type `help *appname*/appdoc_description`. For example, `help ndi.app.spikeextractor/appdoc_description` |
| *add_appdoc* | Add a new document of a given type to the database, using the app |
| *clear_appdoc* | Delete a document of a given type from the database, using the app
| *find_appdoc* | Find the NDI document for a given type, using the app |
| *loaddata_appdoc* | Load binary data associated with an NDI document, using the app |

Let's look at the document types that are written and needed by [ndi.app.spikeextractor](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/spikeextractor.m/): 

#### Code block 2.3.5.1. Type this into Matlab

```matlab
help ndi.app.spikeextractor/appdoc_description
```

You see a long bit of text that describes all of the document types that are generated and calculated by [ndi.app.spikeextractor](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/spikeextractor.m/).

Here's a table of the document types and their "about" info for ndi.app.spikeextractor:

| Appdoc Type | Description |
| -- | -- |
| EXTRACTION_PARAMETERS | EXTRACTION_PARAMETERS documents hold the parameters that are to be used to guide the extraction of spikewaves |
| EXTRACTION_PARAMETERS_MODIFICATION | EXTRACTION_PARAMETERS_MODIFICATION documents allow the user to modify the spike extraction parameters for a specific epoch |
| SPIKEWAVES | SPIKEWAVES documents store the spike waveforms that are read during a spike extraction. It DEPENDS ON the ndi.time.timeseries object on which the extraction is performed and the EXTRACTION_PARAMETERS that descibed the extraction |
| SPIKETIMES | SPIKETIMES documents store the times spike waveforms that are read during a spike extraction. It DEPENDS ON the ndi.time.timeseries object on which the extraction is performed and the EXTRACTION_PARAMETERS that descibed the extraction. The times are in the local epoch time units. |


3. If the app writer really loves his/her/their users, then he/she/they will create a tutorial. Look for a tutorial, that should be referenced in the Matlab help.


