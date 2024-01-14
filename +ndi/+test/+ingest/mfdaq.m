 % this is a manual, script-based test

S = ndi.setup.vhlab('2019-11-19','/Users/vanhoosr/Desktop/2019-11-19');

ds_v = S.daqsystem_load('name','vhvis_spike2');
ds_i = S.daqsystem_load('name','vhintan');


drv = ds_v.daqreader;
fnv = ds_v.filenavigator;

et = fnv.epochtable()


ef = et(1).underlying_epochs.underlying;

d_ingest = drv.ingest_epochfiles(ef)


