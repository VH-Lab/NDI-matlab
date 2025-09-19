# NDI Frequently Asked Questions

## Q: Can I use NDI to analyze data recorded in any format?

**A**: Yes. The NDI system includes pieces of code called [`ndi.daq.reader` objects](https://vh-lab.github.io/NDI-matlab/NDI-matlab/reference/%2Bndi/%2Bdaq/reader.m/) which interpret data recorded with different acquisition devices. Each `ndi.daq.reader` is specific to a particular device, and `ndi.daq.reader` objects [already exist](https://vh-lab.github.io/NDI-matlab/NDI-matlab/reference/%2Bndi/%2Bdaq/%2Breader/mfdaq.m/) for devices by several neuroscience software manufacturers.

## Q: Can I use NDI if my lab builds our own devices and measuring tools?

**A**: Yes. You will need to write one piece of code - an [`ndi.daq.reader` object](https://vh-lab.github.io/NDI-matlab/NDI-matlab/reference/%2Bndi/%2Bdaq/reader.m/) - for each original DAQ system you use. Possibly, you will also need to create an `ndi.daq.metadatareader to read metadata, such as stimulus information for custom stimuli. Once these are created, your data can be read and analyzed with NDI.

## Q: Do I need to change the way my lab organizes our data files in order to use NDI?

**A**: No - the NDI system is able to retrieve data files organized in any way.  NDI uses pieces of code called `ndi.file.navigator` objects to locate data from a recording epoch. Each `ndi.file.navigator` works within a specific organization system, and you can specify the parameters to cause the file navigator to navigate your lab's system.

## Q: Can I use NDI to pool data from multiple labs? 

**A**: Yes. Once each lab has an ndi.daq.system that consists of an `ndi.file.navigator` that can locate files within its storage system and `ndi.daq.reader` objects for each their data acquisition systems, NDI can read and analyze datasets from both labs together.


