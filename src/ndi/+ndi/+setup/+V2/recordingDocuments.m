function [docs, ids] = recordingDocuments(subjectId, file, t0, tz, sid, options)
%RECORDINGDOCUMENTS The documents that record one raw file, in one call.
%
%   [DOCS, IDS] = ndi.setup.V2.recordingDocuments(SUBJECTID, FILE, T0, TZ, SID,
%   'Leaf', LEAF, 'Variable', VARIABLE, 'Format', FORMAT) builds, in the
%   session SID, the five documents a recorded file needs, already joined:
%
%     1 absolute_time_reference  the recording's UTC start T0 (a wall-clock
%                                datetime read in the IANA time zone TZ) and,
%                                with 'Duration', its length
%                                (ndi.setup.V2.utcReference)
%     2 entity (type epoch)      the recording's epoch, timed by 1
%     3 relative_time_reference  the epoch's own clock (dev_local_time from 0)
%     4 LEAF statement           the recording (an observation such as
%                                'intensity_observation') about SUBJECTID,
%                                its VARIABLE (a term), its value in a data
%                                body, timed by BOTH 3 and 1
%     5 opaque_body              FILE, recorded BY LOCATION (ingest 0, its
%                                absolute path): never copied. Its format
%                                FORMAT (a term), size, and with 'Checksums'
%                                its MD5.
%
%   DOCS is {1, 2, 3, 4, 5}. IDS has the ids a later stage needs:
%   time_reference_id (1: time a later statement about the recording by it),
%   epoch_id (2), epoch_time_reference_id (3), statement_id (4: a calculation
%   from the recording names it as its input) and body_id (5).
%
%   Options:
%     'Leaf'         the statement class (required)
%     'Variable'     the statement's variable, a term (required; look it up
%                    by name: ndi.setup.V2.registeredTerm('', NAME))
%     'Format'       the file format, a term (required)
%     'Method'       the statement's method, a term (default: none)
%     'DatumType'    the data body's datum type ('uint8', ...; default none)
%     'Duration'     the recording's length in seconds ([] = unknown)
%     'SourceText'   T0 exactly as the source wrote it (`source_value`;
%                    default: T0 to the second)
%     'Epoch'        the epoch's local_identifier (default: FILE's stem)
%     'Checksums'    default true
%     'Description'  the body's description (default: says it is the raw
%                    recording, kept where the source keeps it)
%
%   FILE must exist; a relative FILE is taken from the current folder (a
%   body records an ABSOLUTE location).
%
%   A real recording often has more: the acquisition system and its reader
%   that NDI's acquisition objects are rebuilt from, the instrument, the
%   recording's keys (its dimensions). The Haley import builds those
%   (ndi.setup.conv.haley.sessionDocuments); this is the minimum every
%   recorded file needs.
%
%   See also ndi.setup.V2.utcReference, ndi.setup.V2.attachFile,
%   ndi.setup.conv.template.import_V2.

arguments
    subjectId {mustBeTextScalar, mustBeNonzeroLengthText}
    file {mustBeTextScalar, mustBeNonzeroLengthText}
    t0 (1,1) datetime
    tz {mustBeTextScalar, mustBeNonzeroLengthText}
    sid {mustBeTextScalar, mustBeNonzeroLengthText}
    options.Leaf {mustBeTextScalar} = ''
    options.Variable = []
    options.Format = []
    options.Method = []
    options.DatumType {mustBeTextScalar} = ''
    options.Duration = []
    options.SourceText {mustBeTextScalar} = ''
    options.Epoch {mustBeTextScalar} = ''
    options.Checksums (1,1) logical = true
    options.Description {mustBeTextScalar} = ''
end
for need = {'Leaf', 'Variable', 'Format'}
    if isempty(options.(need{1}))
        error('ndi:setup:V2:recordingOption', ...
            'recordingDocuments needs ''%s'' (see its help).', need{1});
    end
end
file = char(file);
sid = char(sid);
if ~startsWith(file, filesep) && isempty(regexp(file, '^[A-Za-z]:', 'once'))
    file = fullfile(pwd, file);
end
if ~isfile(file)
    error('ndi:setup:V2:noRecording', 'The recording %s is not on disk.', file);
end
[~, stem, ext] = fileparts(file);
epochName = char(options.Epoch);
if isempty(epochName)
    epochName = stem;
end

absRef = ndi.setup.V2.utcReference(t0, tz, sid, 'SourceText', options.SourceText, ...
    'Duration', options.Duration);
ep = ndi.setup.V2.entityDocuments('epoch', struct('local_identifier', epochName), ...
    struct('time_reference_id', {{absRef.base.id}}), 'SessionId', sid);
ep = ep{1};
relEpoch = did2.build.relativeTimeReference(ep.base.id, 'Clock', 'dev_local_time', ...
    'Start', 0, 'Duration', options.Duration, 'SessionId', sid);
args = {'DataBody', true, 'TimeReferenceIds', {relEpoch.base.id, absRef.base.id}, ...
    'SessionId', sid};
if ~isempty(options.DatumType)
    args = [args, {'DatumType', char(options.DatumType)}];
end
if ~isempty(options.Method)
    args = [args, {'Method', options.Method}];
end
st = did2.build.statement(char(options.Leaf), char(subjectId), options.Variable, [], args{:});

info = dir(file);
description = char(options.Description);
if isempty(description)
    description = sprintf('The raw recording, %s, where the source keeps it.', [stem ext]);
end
f = struct('format', options.Format, 'filename', [stem ext], 'size_bytes', info.bytes, ...
    'description', description);
if options.Checksums
    f.content_hash = ndi.fun.file.MD5(file);
    f.hash_algorithm = 'MD5';
end
body = did2.build.document('opaque_body', f, 'SessionId', sid, ...
    'Edges', struct('owner_id', st.base.id), 'Files', {'body_data_0'});
% recorded BY LOCATION, not ingested: the raw data is never copied
body = ndi.setup.V2.attachFile(body, 'body_data_0', file, 'Ingest', false);

docs = {absRef, ep, relEpoch, st, body};
ids = struct('time_reference_id', absRef.base.id, 'epoch_id', ep.base.id, ...
    'epoch_time_reference_id', relEpoch.base.id, 'statement_id', st.base.id, ...
    'body_id', body.base.id);
end
