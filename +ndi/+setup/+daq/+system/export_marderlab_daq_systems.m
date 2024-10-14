exportDir = fullfile(ndi.common.PathConstants.CommonFolder, 'daq_systems', 'marderlab');
if ~isfolder(exportDir); mkdir(exportDir); end


% Export "marder_ced" DAQ System
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
daqSystemName = 'marder_ced';
daqSystemConfig = ndi.setup.DaqSystemConfiguration( daqSystemName, ...
                 'DaqReaderClass', 'ndi.daq.reader.mfdaq.cedspike2', ...
                 'FileParameters', {'#\.smr\>', ...
                                    '#\.epochprobemap.txt\>'}, ...
    'EpochProbeMapFileParameters', '(.*)epochprobemap.txt' );

daqSystemConfig.export(fullfile(exportDir, [daqSystemName, '.json']))
