This file describes nsd_variable "types" that are to be taken as standards across apps.

| Class | Type field | Description | Example apps |
| ----- |----------  |:-----------:| ------------:|
|nsd_variable_branch|Extracted Spike Waveform Set|A branch that is guarenteed to contain types 'SpikeWaves', 'SpikeTimes', 'Extracted Spike Parameters'; it may contain any number of 'SpikeFeatures' types, such as 'SpikeFeaturesPCA' |[vhlab_mlapp_spikeextractor](https://github.com/VH-Lab/vhlab_mlapp_spikeextractor)|
|nsd_variable|SpikeWaves|A file that contains spike waves in vhlab format|[vhlab_mlapp_spikeextractor](https://github.com/VH-Lab/vhlab_mlapp_spikeextractor)|

