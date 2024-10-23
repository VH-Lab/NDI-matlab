% this is a manual, script-based test

S = ndi.setup.vhlab('2019-11-19','/Users/vanhoosr/Desktop/2019-11-19');

ds_v = S.daqsystem_load('name','vhvis_spike2');
ds_i = S.daqsystem_load('name','vhintan');

drv = ds_v.daqreader;
fnv = ds_v.filenavigator;
mdrv = ds_v.daqmetadatareader{1};

et = fnv.epochtable()
ef = et(1).underlying_epochs.underlying;
d_ingest = drv.ingest_epochfiles(ef)
md_ingest = mdrv.ingest_epochfiles(ef);

dri = ds_i.daqreader;
fni = ds_i.filenavigator;

eti = fni.epochtable();
efi = eti(1).underlying_epochs.underlying;

di_ingest = dri.ingest_epochfiles(efi);

d_fingest = fnv.ingest();

[b,d_intan_ingested] = ds_i.ingest(); % takes a little while

[b,d_vhvis_ingested] = ds_v.ingest(); % takes a little while

% removal


q_i1 = ndi.query('','isa','daqreader_mfdaq_epochdata_ingested');
q_i2 = ndi.query('','isa','daqmetadatareader_epochdata_ingested');
q_i3 = ndi.query('','isa','epochfiles_ingested');

d_ing = S.database_search(q_i1|q_i2|q_i3);

% d_ing = S.database_search(ndi.query('','isa','daqreader_mfdaq_epochdata_ingested'))
% d_ing = fnv.find_ingested_documents()
% d_ing = S.database_search(ndi.query('','isa','daqmetadatareader_epochdata_ingested'))
