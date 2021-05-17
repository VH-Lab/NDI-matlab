# Tutorial 2: Analyzing your first electrophysiology experiment with NDI

## Tutorial 2.3: Using apps to analyze data (spike sorting)

You've seen how to read data from probes in NDI. Now suppose we want to do some analysis of this data? How would we do it?

Clearly, one could write functions in Matlab that read the data and perform some sort of analysis. But it would be
great to share those functions across the open source community, and to develop "apps" that excel at performing
specific tasks. NDI allows both approaches.

### Tutorial 2.3.1: What is an 'app' in NDI? ndi.app objects

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

We will use the program first as though we knew how to use it by magic, and then will go through how one could
figure out how to use the program if one didn't know.

### Tutorial 2.3.2: Extracting spikes using [ndi.app.spikeextractor](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/spikeextractor.m/)

This is planned tutorial that will cover

1. reading and plotting raw data (provided);
2. using a spike-sorting app to identify neurons from raw voltage recordings;
3. analyzing stimulus-responses using built-in tuning curve apps; 
4. plotting the responses in documents in the database.

This is targeted to be written in the first 6 months of application R01MH126791 (if funded).

