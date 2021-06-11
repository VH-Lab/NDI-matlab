# Tutorial 1: Introduction

## 1.2 NDI Concepts and vocabulary

In order to make NDI easy to use, we sought to codify the elements of actual experiments using specific terms, in much the same way that concepts like files, folders, and windows make modern computer operating systems easier to use.

### Probes, subjects, elements, DAQ systems

We define a **probe** as an instrument that makes a measurement of or produces a stimulus for a **subject**. 

In this framework, a variety of experimental apparatus are considered *probes*. Examples of *probes* that make measurements include a whole cell pipette, a sharp electrode, a single channel extracellular electrode, multichannel electrodes with either known or unknown geometries, cameras, 2-photon microscopes, fMRI machines, nose-poke detectors, EMG electrodes, and EEG electrodes. Examples of *probes* that provide stimulation are odor ports, valve-driven interaural cannulae, food reward dispensers, visual stimulus monitors, audio speakers, and stimulating electrodes.

A *probe* requires two important connections. The first connection is with a *subject*. This *subject* can be an experimental research animal, a human subject, a set of cells in a dish, a test resistor, the air, a potato, anything, but it must be named and given an identifier in NDI. 

The second important connection of a **probe** is to a data acquisition system that stores the measurements or the stimulation history of the *probe*. We term such a system a **DAQ system**. Each time a *DAQ system* is switched into record mode, an **epoch** of data is recorded. 

*Probes* are part of a broader class of experiment items that we term **elements**, which include not only concrete physical objects like *probes* but also inferred objects that are not observed directly, such as neurons in an extracellular recording experiment, or abstract quantities, such as simulated data, or a model of the information that an animal has about a stimulus at a given time.

### Real world vocabulary

![NDI real world vocabulary](2_realworldvocabulary_topleft.jpg)

An example experiment. A *probe* is any instrument that can make a measurement from or provide stimulation to a *subject*. In this case, an electrode with an amplifier is monitoring signals in the cerebral cortex of a ferret. The electrode is a *probe*, and the ferret is a *subject*. A DAQ system is an instrument that digitally logs the measurements or stimulus history of a *probe*. In this case, a data acquisition system (DAQ) is logging the voltage values produced by the electrode's amplifier and storing the results in a file on a computer. An epoch is an interval of time during which a DAQ system is switched on and then off to make a recording. In this case, 3 epochs have been sampled. The experiment has additional experiment *elements*. One of these *elements* is a filtered version of the electrode data. A second *element* is a neuron, whose existence and spike times have been inferred by a spike analysis application and recorded in the experiment. 

#### Real world vocabulary: elements

![NDI real world vocabulary: elements](2_realworldvocabulary_bottom.jpg)

In NDI, a wide variety of experiment items are called *elements*, of which *probes* are a subset. Examples of *probes* include multi-channel extracellular electrodes, reward wells, 2-photon microscopes, intrinsic signal imaging systems, intracellular or extracellular single electrodes, and visual stimulus monitors. Other *elements* include items that are directly linked to *probes*, such as filtered versions of signals, or inferred objects like neurons whose activity is inferred from extracellular recordings or images. Still, other *elements* have no physical derivation, such as artificial data or purely simulated data; nevertheless, we want to be able to treat these items identically in analysis pipelines. Finally, *elements* might be the result of complex modeling that depends on many other experiment *elements*, such as an inferred phenomenological model of the amount of information that an animal has about whether a stimulus is a grating.

#### Real world vocabulary: DAQ systems

![NDI real world vocabulary: DAQ systems](2_realworldvocabulary_topright.jpg)

DAQ systems digitally record *probe* measurements or histories of stimulator activity. In NDI, DAQ systems are logical entities, which could correspond physically to a single DAQ device made by a particular company (top) or a collection of home-brewed devices that operate together to have the behavior of a single DAQ device (bottom). In the bottom example, information from an electrode *probe* and digital triggers from a visual stimulation *probe* are acquired on a single DAQ device, but digital information from both systems (in separate files) is needed to fully describe the activity in each epoch.

### Discussion/Feedback

Post [comments, bugs, questions, or discuss](https://github.com/VH-Lab/NDI-matlab/issues/175).
