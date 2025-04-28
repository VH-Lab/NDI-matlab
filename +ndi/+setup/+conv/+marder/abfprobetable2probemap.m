function abfprobetable2probemap(S,options)
% ABFPROBETABLE2PROBEMAP - Create epochprobemap files for a Marder ndi session
%
%   ABFPROBETABLE2PROBEMAP(S) reads all ABF files within the NDI session
%   directory specified by the ndi.session or ndi.dataset object S and
%   generates corresponding epochprobemap files. This function utilizes
%   the 'probetable.csv' file and any 'subject*.txt' files found in the
%   main session directory to map recorded channels to probes and subjects.
%
%   ABFPROBETABLE2PROBEMAP(S, OPTIONS) allows for customization of the
%   epochprobemap creation process through a structure of name-value pair
%   arguments.
%
%   Inputs:
%   S (ndi.session or ndi.dataset)
%       An ndi.session or ndi.dataset object representing the experimental
%       session containing the ABF data. The function will operate on the
%       directory associated with this object.
%
%   Options:
%   'acquisitionDelay' (duration, default = seconds(0))
%       A duration specifying the minimum time that must have passed since
%       an ABF file's creation date for it to be processed. This can be
%       useful to avoid processing files that are still being written.
%
%   'overwrite' (logical, default = false)
%       A logical flag indicating whether existing epochprobemap files 
%       should be overwritten. If true, the function will re-create 
%       epochprobemap files even if they already exist. If false, existing 
%       files will be skipped.
%
%   Notes:
%   - The 'probetable.csv' file is expected to have columns that can be 
%       used to match channel names (found in the ABF header) to probe 
%       information. The exact column names used for matching are 
%       determined within the 
%       NDI.SETUP.CONV.MARDER.CHANNELNAMETABLE2PROBENAME function.
%   - The 'subject*.txt' files are expected to contain a single line with 
%       the subject's local identifier.
%
%   See also: NDI.SESSION, NDI.DATASET, NDI.EPOCH.EPOCHPROBEMAP_DAQSYSTEM, 
%       NDI.SETUP.CONV.MARDER.CHANNELNAMETABLE2PROBENAME,
%       NDR.FORMAT.AXON.READ_ABF_HEADER

% Input argument validation
arguments
    S (1,1) {mustBeA(S, ["ndi.session", "ndi.dataset"])}
    options.acquisitionDelay (1,1) duration = seconds(0)
    options.overwrite (1,1) logical = false
end

dirname = S.getpath();

probetable = readtable([dirname filesep 'probetable.csv'],'Delimiter',',');

daqname = 'marder_abf';

% Add subjects to database (if not already added or overwriting)
s = dir([dirname filesep  'subje*.txt']);
subject = cell(size(s));
for i=1:numel(s)
    subject{i} = fileread([dirname filesep s(i).name]);
    mysub = S.database_search(ndi.query('subject.local_identifier','exact_string',subject{i}));
    if options.overwrite
        S.database_rm(mysub);
        mysub = [];
    end
    if isempty(mysub)
        mysub = ndi.subject(subject{i},'Crab from Eve Marder Lab at Brandeis');
        mysubdoc = mysub.newdocument + S.newdocument();
        S.database_add(mysubdoc);
    end
end

% Find abf files that do not yet have accompanying epochprobemaps
d = dir([dirname filesep '*.abf']);
if options.overwrite
    epoch_i = 1:numel(d);
else
    epm = dir([dirname filesep '*.epochprobemap.txt']);
    epm_fileNames = {epm(:).name};
    fileNames = extractBefore(epm_fileNames,'.');
    missing = ~contains({d(:).name},fileNames);

    % Skip files that do not meet input criterion
    timeDelay = datetime('now') - datetime([d(:).datenum],'ConvertFrom','datenum');
    skip = timeDelay < options.acquisitionDelay;

    epoch_i = find(missing & ~skip);
end

% Create epochprobemaps
for i = epoch_i
    h = ndr.format.axon.read_abf_header([dirname filesep d(i).name]);
    for k=1:numel(s)
        probemap = ndi.epoch.epochprobemap_daqsystem('stimulation',k,'stimulator',...
            'marder_abf:ai1',subject{k});
    end

    for j=1:numel(h.recChNames)
        [name,ref,probeType,subjectlist] = ...
            ndi.setup.conv.marder.channelnametable2probename(h.recChNames{j},probetable);
        daqsysstr = ndi.daq.daqsystemstring(daqname,{'ai'},j);
        for z=1:numel(name)
            probemap(end+1) = ndi.epoch.epochprobemap_daqsystem(name{z},ref(z),probeType{z},...
                daqsysstr.devicestring(),subjectlist{z});
        end
    end
    [~,myfile,~] = fileparts([dirname filesep d(i).name]);
    probemap.savetofile([dirname filesep myfile '.epochprobemap.txt']);
end