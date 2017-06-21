# Probe

In NSD, a **probe** is an instrument for observing or manipulating the experimental environment. Types of probes include recording or stimulating electrodes and the display or recording of information (whether visual, auditory, olfactory, gustatory, temperature, etc). Probes are distinct from **devices**, which are digital input/output devices that perform digital sampling or control of probes.

The probes that are acquired or controlled in any device epoch are listed in the `nsd_epochcontents` object for that epoch. They include the following fields:

`nsd_epochcontents` fields:

   * **name**: A name for the probe, must start with a letter and contain no whitespace but otherwise unrestricted
   * **reference**: A reference for the probe; identical reference numbers indicate that NSD should try to combine data; (for example, if you move an electrode, one should change the reference number to indicate that the probe is being used differently); can be any non-negative integer
   * **type**: The type of probe; must be a string that begins with a letter and has no whitespace; there are standard types (see below) but users can use any valid string for type.
   * ** devicestring**: A string that indicates the device (and channels) that have a digital record of the probe (see `nsd_devicestring`)

Standard types:

|**Type**              | **Description** |
|----------------------|-----------------|
|_Electrodes_          |                 |
|'n-trode'             |A bundle of N extracellular electrodes that sample overlapping electric fields; the number of channels is calculated from the number of channels specified in the device string |
|'electrode-SPEC'      |An electrode of a specification that is contained in a reference SPEC (might contain a means of looking up electrode geometry, impedance / channel quality measurements, etc) |
|'patch'               |A whole cell patch electrode (two channels; first is Vm, second is I) |
|'patch-Vm'            |A whole cell patch electrode (single channel, specifies voltage recording) |
|'patch-I'             |A whole cell patch electrode (single channel, specifies current recording) |
|'patch-attached'      |A patch electrode in cell-attached configuration (single channel, specifies voltage recording) |
|'sharp'               |A sharp electrode (two channels; first is voltage, second is current) |
|'sharp-Vm'            |A sharp electrode (single channel, specifies voltage recording) |
|'sharp-I'             |A sharp electrode (single channel, specifies current recording) |
|_Imaging_             |                 |
|'wide-field-imaging'  |Wide-field imaging data, as one might acquire with intrinsic signal imaging |
|'2-photon-imaging'    |2-photon fluorescent imaging data (laser-scanned or imaged) |
|'1-photon-imaging'    |1-photon fluorescent imaging (laser-scanned or imaged) |
|'brightfield-imaging' |Brightfield images |
|_Stimulators_         |                |
|'display'             |An instrument that displays patterns with light |
|'stim-n-trode'        |An N-channel extracellular electrode stimulator; the number of channels is calculated from the number of channels specified in the device string |
|'n-LED'               |An N-channel LED stimulator; the number of channels is calculated from the number of channels specified in the device string |
|_Environment_         |                |
|Lick-spout            |A lick-spout    |
|Interoral-cannula     |An interoral cannula|
|Reward-well           |A reward well


