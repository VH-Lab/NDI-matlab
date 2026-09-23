function P = readprm(prmFile)
% NDI.FUN.PROBE.IMPORT.JRCLUST.READPRM - read a JRCLUST parameter (.prm) file
%
% P = NDI.FUN.PROBE.IMPORT.JRCLUST.READPRM(PRMFILE)
%
% Reads the JRCLUST parameter file PRMFILE and returns the parameters that NDI needs
% in order to interpret a JRCLUST sort. A .prm file is a MATLAB script of assignments
% (JRCLUST reads it the same way, see jrclust.utils.mToStruct), so it is evaluated
% here; user-defined parameters, such as the ndiPath/ndiElementName/ndiElementReference
% written by an NDI bootstrap, are returned along with the standard ones.
%
% Fields of P:
%   prmFile              - the file that was read
%   directory            - the folder holding PRMFILE (where JRCLUST writes its output)
%   sessionName          - PRMFILE's name without its extension (JRCLUST's session name)
%   resFile              - [directory]/[sessionName]_res.mat, JRCLUST's results file
%   recordingFormat      - the 'recordingFormat' parameter ('' if not set)
%   sampleRate           - the sampling rate, in Hz
%   nChans               - the number of channels
%   rawRecordings        - cell array of the recordings that were sorted, in order.
%                            For the 'ndi' recording format these are NDI epoch ids;
%                            any directory part is stripped.
%   evtWindow            - the spike waveform window, in ms (default [-0.25 0.75])
%   evtWindowSamp        - EVTWINDOW converted to samples, as JRCLUST computes it
%                            (round(evtWindow*sampleRate/1000))
%   ndiPath              - the ndi.session path recorded in the file ('' if absent)
%   ndiElementName       - the ndi.element name recorded in the file ('' if absent)
%   ndiElementReference  - the ndi.element reference recorded in the file ([] if absent)
%   params               - a struct of every parameter found in the file
%
% The .prm file is the authority on which epochs were sorted and in what order:
% JRCLUST concatenates 'rawRecordings' in the listed order, and spike times in the
% results file are sample indices into that concatenated stream.
%
% If the file cannot be evaluated (or leaves required parameters unset) and JRCLUST
% is on the MATLAB path, jrclust.Config is used as a fallback reader.
%
% See also: NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE, NDI.FUN.PROBE.IMPORT.JRCLUST.RESULTS,
%   NDI.FUN.PROBE.EXPORT.JRCLUST
%
% Example:
%    P = ndi.fun.probe.import.jrclust.readprm('/path/to/.JRCLUST/ctx_|_1/jrclust.prm');
%

    arguments
        prmFile (1,:) char {mustBeFile}
    end

    params = i_evalParamFile(prmFile);

    % Fall back to JRCLUST's own reader if the evaluation came up short.
    needed = {'sampleRate','nChans','rawRecordings'};
    haveAll = all(cellfun(@(f) isfield(params,f) && ~isempty(params.(f)), needed));
    if ~haveAll && ~isempty(which('jrclust.Config')),
        try
            % feval: this file is in the package ndi.fun.probe.import.jrclust, so an
            % unqualified 'jrclust.Config' could be resolved against this package
            % instead of JRCLUST's top-level 'jrclust' package.
            hCfg = feval('jrclust.Config', prmFile);
            for i=1:numel(needed),
                if ~isfield(params,needed{i}) || isempty(params.(needed{i})),
                    params.(needed{i}) = hCfg.(needed{i});
                end;
            end;
            for f = {'evtWindow','recordingFormat','ndiPath','ndiElementName','ndiElementReference'},
                if (~isfield(params,f{1}) || isempty(params.(f{1}))) && isprop(hCfg,f{1}),
                    params.(f{1}) = hCfg.(f{1});
                end;
            end;
        catch ME
            warning(['Could not read ' prmFile ' with jrclust.Config: ' ME.message]);
        end;
    end;

    [directory, sessionName, ~] = fileparts(prmFile);

    P = struct();
    P.prmFile     = prmFile;
    P.directory   = directory;
    P.sessionName = sessionName;
    P.resFile     = fullfile(directory, [sessionName '_res.mat']);
    P.params      = params;

    P.recordingFormat     = i_getField(params,'recordingFormat','');
    P.sampleRate          = i_getField(params,'sampleRate',[]);
    P.nChans              = i_getField(params,'nChans',[]);
    P.rawRecordings       = i_recordingList(i_getField(params,'rawRecordings',{}));
    P.evtWindow           = i_getField(params,'evtWindow',[-0.25 0.75]); % JRCLUST default
    P.ndiPath             = i_getField(params,'ndiPath','');
    P.ndiElementName      = i_getField(params,'ndiElementName','');
    P.ndiElementReference = i_getField(params,'ndiElementReference',[]);

    if isempty(P.sampleRate),
        error('ndi:fun:probe:import:jrclust:readprm:noSampleRate', ...
            'No sampleRate parameter could be read from %s.', prmFile);
    end;
    P.evtWindowSamp = round(P.evtWindow * P.sampleRate / 1000); % matches jrclust.Config

end % readprm()

function params = i_evalParamFile(prmFile__)
% Evaluate a JRCLUST .prm file and collect the resulting variables. Comments are
% stripped first, then the whole script is evaluated (the same approach JRCLUST
% takes in jrclust.utils.mToStruct) so that files that build parameters from
% intermediate variables - a documented JRCLUST idiom, e.g.
%   depths = 0:50:750; siteLoc = [zeros(16,1) depths(:)];
% - are read correctly. Local names end in '__' so they cannot collide with a
% parameter name and are excluded from the result.
    params = struct();
    try
        text__ = fileread(prmFile__);
    catch ME
        warning(['Could not read ' prmFile__ ': ' ME.message]);
        return;
    end;

    lines__ = regexp(text__, '\r\n|\r|\n', 'split');
    keep__ = cell(1,0);
    for i__ = 1:numel(lines__),
        ln__ = lines__{i__};
        c__ = find(ln__=='%',1,'first'); % .prm files have no strings containing '%'
        if ~isempty(c__),
            ln__ = ln__(1:c__-1);
        end;
        ln__ = strtrim(ln__);
        if ~isempty(ln__),
            keep__{end+1} = [ln__ ' ']; %#ok<AGROW>
        end;
    end;
    if isempty(keep__),
        return;
    end;

    try
        eval(cell2mat(keep__));
    catch ME
        warning(['Could not evaluate ' prmFile__ ': ' ME.message]);
    end;

    vars__ = whos();
    names__ = setdiff({vars__.name}, ...
        {'prmFile__','params','text__','lines__','keep__','ln__','c__','i__','vars__','names__','ME'});
    for i__ = 1:numel(names__),
        params.(names__{i__}) = eval(names__{i__});
    end;
end % i_evalParamFile()

function v = i_getField(s, f, default)
    if isfield(s,f) && ~isempty(s.(f)),
        v = s.(f);
    else,
        v = default;
    end;
end % i_getField()

function c = i_recordingList(r)
% Normalize the rawRecordings parameter to a cell array of names, stripping any
% directory part (for the 'ndi' recording format the entries are NDI epoch ids,
% which may themselves contain '.' characters, so fileparts is not used here).
    if isempty(r),
        c = {};
        return;
    end;
    if ~iscell(r),
        r = {r};
    end;
    c = cell(1,numel(r));
    for i=1:numel(r),
        item = r{i};
        if ~ischar(item) && ~isstring(item),
            error('ndi:fun:probe:import:jrclust:readprm:badRecording', ...
                'rawRecordings entry %d is not a character vector.', i);
        end;
        item = char(item);
        seps = find(item=='/' | item=='\');
        if ~isempty(seps),
            item = item(seps(end)+1:end);
        end;
        c{i} = item;
    end;
end % i_recordingList()
