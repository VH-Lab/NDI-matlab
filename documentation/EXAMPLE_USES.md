## 5 examples of recording situations

### 1. Simple: 1 device, 1 probe, 3 things

An experimentor records spontaneously generated responses with a single electrode inserted in visual cortex. The analyst wants to examine the responses of single neurons and the local field potential.

_Physical situation_: There is a single physical hardware data acquisition system, in this case a system made by Cambridge Electronic Deisgn called the micro1401. A wire connects the electrode to an amplifier, and a wire from the amplifier connects to an input (let's say input 0) on the micro1401.

The recording system is turned on to record a bout of spontaneous activity, and then turned off. Each time the recording is turned on, a file (.smr format) is written to disk. The software that manages the recording of the micro1401 is written by CED and is called Spike2.

Let's say there are 3 recording epochs. Therefore, we have 3 .smr files (let's say at path epoch1/myfile.smr, epoch2/myotherfile.smr, epoch3/myotherfileagain.smr).

_NDI configuration_: The raw data is managed by a member of the class `ndi_daqsystem`. There is a subclass, `ndi_daqsystem_mfdaq`, that implements a generic multi-function data acquisition system. There is an `ndi_daqreader_mfdaq` class, and a specific subclass `ndi_daqreader_mfdaq_cedspike2` that implements the reading of the .smr files. 

We build an `ndi_daqsystem` object to add to the `ndi_experiment` object of this experiment, that we will call vhspike2 (for reading the electrode data). To do so, we need to create the 2 component objects of an `ndi_daqsystem`: an `ndi_daqreader` and an `ndi_filenavigator`. Let's say our experiment is in variable E.

`fileparams = ;
d = ndi_daqsystem_mfdaq(ndi_daqreader_mfdaq_cedspike2(), ndi_filenavigator(fileparams));'




### 2. Typical: 2 devices, 2 probes, 4 things

An experimentor records responses to visual stimulation with a single electrode inserted in visual cortex. The analyst wants to
examine the responses of single neurons to visual stimulation and the local field potential response to visual stimulation.

_Physical situation_: There is a single physical hardware data acquisition system, in this case a system made by
Cambridge Electronic Deisgn called the micro1401. A wire connects the electrode to an amplifier,
and a wire from the amplifier connects to an input (let's say input 0) on the micro1401. There is a visual stimulus computer that
produces videos on a monitor, and also generates 14 digital timing pulses that are acquired on 14 digital inputs (let's say
digital inputs 1..14):

  1. Stimulus trigger: trigger generated when a stimulus is shown
  2. Prestimulus trigger: trigger generated when system is ready to draw a stimulus (user-specified delay)
  3. Frame trigger: trigger generated when system updates the video image on the display
  4. Vertical blanking: trigger generated when monitor refreshes
  5. 8 digital channels encode the stimulus identity from 0 (no stimulus) to 1..255

The recording system is turned on to record a bout of visual stimulation, and then turned off. Each time the recording is turned
on, a file (.smr format) is written to disk, and the visual stimulus computer also writes a detailed stims.mat file to disk that
has a big list of parameters for each visual stimulus (how big it was, what its shape was, what its number was, etc). The software
that manages the recording of the micro1401 is written by CED and is called Spike2.

Let's say there are 3 recording epochs. Therefore, we have 3 .smr files (let's say at path epoch1/myfile.smr, epoch2/myotherfile.smr,
epoch3/myotherfileagain.smr), and 3 stims.mat files (let's say at path epoch1/stims.mat, epoch2/stims.mat, epoch3/stims.mat).

_NDI configuration_: We have created 2 `ndi_daqsystem` classes that assist in processing the data. These abstract classes are
`ndi_daqsystem_mfdaq`, that implements a generic multi-function data acquisition system, and `ndi_daqsystem_stimulus` that implements
a genetic stimulus system. There is an `ndi_daqreader_mfdaq` class, and a specific subclass `ndi_daqreader_mfdaq_cedspike2` that
knows how to read the .smr files, and an `ndi_daqreader_mfdaq_stimulus_vhlabvisspike2` subclass that reads the timing information
from .smr files and the stimulus parameter information from the stims.mat file. 

We build 2 ndi_daqsystem objects to add to the `ndi_experiment` object of this experiment, that we will call vhspike2 (for reading the electrode data) and another daq system object vhvis_spike2 that reads the triggers generated from the visual 
stimulus computer. 


