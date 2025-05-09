function [epochid] = filename2epochid(session,filename)
%FILENAME2EPOCHID Finds the epochid associated with a given filename
%   Detailed explanation goes here
%%
cacheTable = session.cache.table;
probeInd = find(contains({cacheTable.type},'epochtable-hash'));
epochid = {};
for p = probeInd
    et = cacheTable(p).data.epochtable;
    for e = 1:numel(et)
        underlyingFiles = et(e).underlying_epochs.underlying;
        if isa(underlyingFiles,'ndi.daq.system.mfdaq')
            continue
        end
        fileInd = contains(underlyingFiles,filename);
        if ~any(fileInd)
            continue
        end
        epochid{end+1,1} = et(e).epoch_id;
    end
end
epochid = unique(epochid);

if iscell(epochid) & isscalar(epochid)
    epochid = epochid{1};
elseif isempty(epochid)
    error('FILENAME2EPOCHID:NoEpochFound','No file was found matching the filename %s',filename);
end


 % epochid = function ndi.fun.epoch.filename2Epochid (dataFile);
            % epochFile (any data file associated specifically with that epoch)
            % helper function find epoch file by looking at
            % underlying_epcoh two layers down to get mat file name
end