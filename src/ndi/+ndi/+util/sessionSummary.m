function summary = sessionSummary(session_obj)
% SESSIONSUMMARY - create a summary structure of an ndi.session object
%
% SUMMARY = NDI.UTIL.SESSIONSUMMARY(SESSION_OBJ)
%
% Returns a structure SUMMARY containing key fields and properties
% of the NDI.SESSION object SESSION_OBJ. This structure is intended
% for symmetry testing between different NDI language implementations.
%

% 1. Session basics
summary.reference = session_obj.reference;
summary.sessionId = session_obj.id();

% 2. Files in session path
session_path = session_obj.path();
if isfolder(session_path)
    d = dir(session_path);
    % Filter out '.' and '..' directories
    d = d(~ismember({d.name}, {'.', '..'}));
    summary.files = {d.name};
else
    summary.files = {};
end

% 3. Files in .ndi folder
dot_ndi_path = fullfile(session_path, '.ndi');
if isfolder(dot_ndi_path)
    d_ndi = dir(dot_ndi_path);
    d_ndi = d_ndi(~ismember({d_ndi.name}, {'.', '..'}));
    summary.filesInDotNDI = {d_ndi.name};
else
    summary.filesInDotNDI = {};
end

% 4. DAQ Systems
daqs = session_obj.daqsystem_load('name', '(.*)');
if isempty(daqs)
    daqs = {};
elseif ~iscell(daqs)
    daqs = {daqs};
end

daqNames = cell(1, numel(daqs));
daqDetails = struct('filenavigator_class', {}, 'daqreader_class', {}, ...
                    'epochNodes_filenavigator', {}, 'epochNodes_daqsystem', {});

for i = 1:numel(daqs)
    sys = daqs{i};
    daqNames{i} = sys.name;

    details = struct();

    % Get classes if they exist
    if isprop(sys, 'filenavigator') && ~isempty(sys.filenavigator)
        details.filenavigator_class = class(sys.filenavigator);

        % Try to get epoch nodes of filenavigator
        try
            details.epochNodes_filenavigator = sys.filenavigator.epochnodes();
        catch
            details.epochNodes_filenavigator = [];
        end
    else
        details.filenavigator_class = '';
        details.epochNodes_filenavigator = [];
    end

    if isprop(sys, 'daqreader') && ~isempty(sys.daqreader)
        details.daqreader_class = class(sys.daqreader);
    else
        details.daqreader_class = '';
    end

    % Try to get epoch nodes of daq system
    try
        details.epochNodes_daqsystem = sys.epochnodes();
    catch
        details.epochNodes_daqsystem = [];
    end

    % Add to structure array
    if isempty(daqDetails)
        daqDetails = details;
    else
        daqDetails(i) = details;
    end
end

summary.daqSystemNames = daqNames;
summary.daqSystemDetails = daqDetails;

% 5. Probes
probes = session_obj.getprobes();
% Preallocate a struct array instead of a cell array to avoid JSON decoding
% turning it into a struct array and causing comparison failures later.
probe_structs = struct('name', {}, 'reference', {}, 'type', {}, 'subject_id', {});
for i = 1:numel(probes)
    p = probes{i};
    probe_structs(i).name = p.name;
    probe_structs(i).reference = p.reference;
    probe_structs(i).type = p.type;
    probe_structs(i).subject_id = p.subject_id;
end

summary.probes = probe_structs;

end
