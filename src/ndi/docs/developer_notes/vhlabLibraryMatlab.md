# vhlab-library-matlab usage in NDI-matlab

The following table lists the occurrences of calls to functions and usages of conventions from the `vhlab-library-matlab` repository within `NDI-matlab`.

| vhlab-library-matlab function | Usage (NDI function/class) | Line Number | Comment |
|---|---|---|---|
| cellname2nameref | src/ndi/+ndi/+setup/+conv/+vhlab/importMeasuredDataCells.m | 22 | Direct call |
| getparameters | src/ndi/+ndi/+daq/+metadatareader/NewStimStims.m | 37 | Direct call on stimscript object |
| getstimscript | src/ndi/+ndi/+daq/+metadatareader/NewStimStims.m | 35 | Direct call |
| getstimscript | src/ndi/+ndi/+setup/+daq/+reader/+mfdaq/+stimulus/vhlabvisspike2.m | 116 | Direct call |
| neural_response_significance | src/ndi/+ndi/+app/oridirtuning.m | 161 | Direct call |
| read_stimtimes_txt | src/ndi/+ndi/+setup/+daq/+reader/+mfdaq/+stimulus/vhlabvisspike2.m | 108 | Direct call |
| testdirinfo | src/ndi/+ndi/+setup/+conv/+vhlab/approachMappingTable.m | 37 | Reference to file format convention |
| vhintan_channelgrouping | src/ndi/+ndi/+setup/+daq/+system/deprecating/vhlab.m | 48, 50 | Reference to file format convention |
| vhintan_channelgrouping | src/ndi/+ndi/+setup/+daq/+system/export_vhlab_daq_systems.m | 12, 14 | Reference to file format convention |
| vhintan_clusternameref | src/ndi/+ndi/+gui/gui.m | 154 | Referenced by name for execution |
| vhintan_importcells | src/ndi/+ndi/+gui/gui.m | 150 | Referenced by name for execution |
| vhintan_intan2spike2time | src/ndi/+ndi/+setup/+daq/+system/deprecating/vhlab.m | 48 | Reference to file format convention |
| vhintan_intan2spike2time | src/ndi/+ndi/+setup/+daq/+system/export_vhlab_daq_systems.m | 13 | Reference to file format convention |
| vhintan_intan2spike2time | src/ndi/+ndi/+setup/vhlab.m | 21 | Reference to file format convention |
| vhspike2_channelgrouping | src/ndi/+ndi/+setup/+daq/+system/deprecating/vhlab.m | 53, 55 | Reference to file format convention |
| vhspike2_channelgrouping | src/ndi/+ndi/+setup/+daq/+system/export_vhlab_daq_systems.m | 27, 28 | Reference to file format convention |

## Alphabetized List

- cellname2nameref
- getparameters
- getstimscript
- neural_response_significance
- read_stimtimes_txt
- testdirinfo
- vhintan_channelgrouping
- vhintan_clusternameref
- vhintan_importcells
- vhintan_intan2spike2time
- vhspike2_channelgrouping
