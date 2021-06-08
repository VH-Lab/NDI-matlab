# Tutorial 2: Analyzing your first electrophysiology experiment with NDI

## 2.4 Analyzing stimulus responses

In the last tutorial, we saw how to use applications to identify spikes from electrophysiology recordings. Now we will employ another plain app 
for calculating responses to stimulation. Note that this tutorial requires that you have completed [Tutorial 2.3](https://vh-lab.github.io/NDI-matlab/tutorials/analyzing_first_physiology_experiment/3_spikesorting/) (the analysis here depends on the spike sorted results of Tutorial 2.3).

### 2.4.1 Sinusoidal gratings to assess direction and orientation preferences and spatial frequency preferences

In this experiment ([Van Hooser et al. 2013](https://pubmed.ncbi.nlm.nih.gov/23843520/)), we assessed tuning for stimulus direction and 
spatial frequency with sinusoidal gratings. A series of sinusoidal gratings drifting in different directions are shown [here](https://photos.app.goo.gl/AsSpsd9cGK1MWygC8).  In the actual
experiments, we assessed orientation/direction preferences coarsely, and then found the optimal spatial and temporal frequency for the cell before
assessing orientation/direction in a fine manner at the optimal spatial and temporal frequency for the cell. The fine orientation/direction
assessment is what is included in this demo.

So let's open our demo experiment and get started! We are also going to identify our stimulator (visual stimulus system) so that we can tell NDI to
analyze stimuli from this device.

#### Code Block 2.4.1.1. Type this into Matlab.

```matlab
dirname = [userpath filesep 'Documents' filesep 'NDI' filesep 'ts_exper2']; % change this if you put the example somewhere else
ref = 'ts_exper2';
S = ndi.session.dir(ref,dirname);

% find out stimulus probe
stimprobe = S.getprobes('type','stimulator');
stimprobe = stimprobe{1}; % grab the first one, should be our stimulus monitor
```

### 2.4.2 Gathering stimulus information

The first step in analyzing stimuli is to gather information about the stimulus presentations that were performed in the experiment. We use a 
small dedicated app for this purpose called [ndi.app.stimulus.decoder](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/%2Bstimulus/decoder.m/).

#### Code Block 2.4.2.1. Type this into Matlab.

```matlab
sapp = ndi.app.stimulus.decoder(S);
redo = 1;
[stim_pres_docs] = sapp.parse_stimuli(stimprobe,redo);
```

Now let's take a look at what has been decoded:

#### Code Block 2.4.2.2. Type this into Matlab.

```
stim_pres_docs{1}.document_properties.stimulus_presentation

% these are the fields that were decoded by ndi.app.stimulus.decoder
% let's take a look

 % here is information about the presentation time of the first stimulus
stim_pres_docs{1}.document_properties.stimulus_presentation.presentation_time(1)

 % here is information about the presentation order of the first 10 stimuli shown:

stim_pres_docs{1}.document_properties.stimulus_presentation.presentation_order(1:10)

 % We see that the first stimulus that was presented was stimulus number 4. Let's take a look at its properties:

stim_pres_docs{1}.document_properties.stimulus_presentation.stimuli(4).parameters

 % We can also take a look at the control or blank stimulus properties:

stim_pres_docs{1}.document_properties.stimulus_presentation.stimuli(17).parameters

% you can see that there are 4 such documents, one for each stimulus presentation in the experiment

stim_pres_docs,
```

### 2.4.3 Labeling control stimuli

For most turning curve data, we want to compare the response during the time of stimulation to the response of the system during some background time, or some "control" stimulus. For visual stimuli, this is often a period where a gray screen is shown that has the same duration as the visual stimuli that may be shown. For an auditory stimulus, it may be a period of time when no specific auditory stimulus is playing and the animal hears the noise of the background environment. Often, stimuli have in their parameters a field that declares that a stimulus is a control or blank stimulus. Our stimuli have such a code as shown above (stimulus 17).

#### Code Block 2.4.3.1. Type this into Matlab.

```matlab
rapp = ndi.app.stimulus.tuning_response(S);
cs_doc = rapp.label_control_stimuli(stimprobe,redo);
```

Let's examine what it did. We see that the [ndi.app.stimuli.tuning_response](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/%2Bstimulus/tuning_response.m/) app each of the 85 stimuli with the "blank" stimulus that was presented closest in time:

#### Code Block 2.4.3.2. Type this into Matlab.

```matlab
 % see the control stimulus identifier for all the stimuli
cs_doc{1}.document_properties.control_stimulus_ids.control_stimulus_ids
 % see the method used to identify the control stimulus for each stimulus:
cs_doc{1}.document_properties.control_stimulus_ids.control_stimulus_id_method

 % see the help for the label_control_stimuli function:
help ndi.app.stimulus.tuning_response.label_control_stimuli
```

### 2.4.4 Calculating stimulus responses

Once the control stimuli have been labeled (if desired; it is optional), then one can proceed to calcuate the stimulus responses. To do this, we 
can employ the [ndi.app.stimuli.tuning_response]((https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/%2Bstimulus/tuning_response.m/) app. This program will calculate the mean response to each stimulus. Because gratings are a periodic stimulus, this function will also calculate the response at the fundamental stimulus temporal frequency (F1 component) and at twice this temporal frequency (F2 component).

#### Code block 2.4.4.1. Type this into Matlab.

```matlab
e = S.getelements('element.type','spikes');

rdocs{1} = rapp.stimulus_responses(stimprobe, e{1}, redo);
rdocs{2} = rapp.stimulus_responses(stimprobe, e{2}, redo);
```

Now we can examine the sets of documents that are produced. We see that there are two sets of 3 documents each:

#### Code block 2.4.4.2. Type this into Matlab.

```matlab
 % look at rdocs{1}:
rdocs{1}
 % it is a 1x2 cell array, and each of these cell entries is in turn a 1x3 cell array
rdocs{1}{1}
 % this reflects the two epochs ('t00001' and 't00002'), and, for each epoch, the analysis of the mean response, the F1 component, and the F2 component

 % to see this, let's look at the first document

rdocs{1}{1}{1}.document_properties
rdocs{1}{1}{1}.document_properties.stimulus_response

rdocs{1}{1}{1}.document_properties.stimulus_response_scalar
 % we see that this is the 'mean' response. We can see the responses contained within:

rdocs{1}{1}{1}.document_properties.stimulus_response_scalar.responses
 % we can see that each of the 85 presentations includes a response that can possibly have a real and imaginary component, as well as a control response

rdocs{1}{1}{1}.document_properties.stimulus_response_scalar.responses.response_real(1)
rdocs{1}{1}{1}.document_properties.stimulus_response_scalar.responses.control_response_real(1)

```

### 2.4.5 Computing an orientation/direction tuning curve and calculating orientation/direction index values

Now that we have all of the responses to the individual stimuli, we can create a tuning curve, which examines how the response of the neuron depends on a particular stimulus parameter. In this case, the stimulus is 'angle', which corresponds to the direction of the sinusoidal grating stimulus. We have built a specific application [ndi.app.oridirtuning](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/oridirtuning.m/) to process tuning curves in response to oriented stimuli, or stimuli moving in particular directions. 

After generating the tuning curve, we can calculate many, many index values that characterize the tuning of each cell. The function that calculates the orientation and direction index values pulls up a plot. If you look at the plot that examines the mean response for `ctx_1`, you can see that the cell responds strongly to gratings drifting at 120 degrees and 300 degrees (0 degrees is up; 90 degrees is to the right).

#### Code block 2.4.5.1. Type this into Matlab.

```matlab
oapp = ndi.app.oridirtuning(S);

for i=1:2,
	tdoc{i} = oapp.calculate_tuning_curve(e{i});
	oriprops{i} = oapp.calculate_all_oridir_indexes(e{i}); % this takes a few minutes
end;
```

The program should pop up 6 figures that look like this when they are adjusted to have the same axes:

![Orientation / direction tuning curves for Ctx 1 and LGN 1](tutorial_02_04_orientation_curves.png)

The tuning curves show that cell Ctx 1 has a strong orientation-tuned mean response to bars drifting at an angle of about 90 degrees (vertical bars moving rightward) or 270 degrees (vertical bars moving leftward). The cell LGN 1 does not exhibit strong tuning for orientation or direction, but instead exhibits a strong modulated response (F1) to most directions.

Now let's take a look at these index values for the first cell. These index values are described in [Mazurek et al. (2014)](https://pubmed.ncbi.nlm.nih.gov/25147504/).

#### Code block 2.4.5.2. Type this into Matlab.

```matlab
  % see all the categories
oriprops{1}{1}.document_properties.orientation_direction_tuning
  % see the property information
oriprops{1}{1}.document_properties.orientation_direction_tuning.properties
  % see significance. Responses across orientation are very significant:
oriprops{1}{1}.document_properties.orientation_direction_tuning.significance
  % fit parameters:
oriprops{1}{1}.document_properties.orientation_direction_tuning.fit
  % vector tuning parameters:
oriprops{1}{1}.document_properties.orientation_direction_tuning.vector
```

Now we have seen how we can analyze stimulus responses and use applications to calculate tuning curves and index values. If you had your own stimulus responses of a different type, you could write functions or apps that analyze the results and calculate the appropriate index values.


### 2.4.5 Discussion/Feedback

Post [comments, bugs, questions, or discuss](https://github.com/VH-Lab/NDI-matlab/issues/179).

