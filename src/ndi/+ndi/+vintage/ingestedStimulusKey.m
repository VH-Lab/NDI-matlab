function key = ingestedStimulusKey(epochId, readerId)
%INGESTEDSTIMULUSKEY How a migrated ingested stimulus file names its epoch and reader.
%
%   KEY = ndi.vintage.ingestedStimulusKey(EPOCHID, READERID) is the text
%   that opens the description of the `opaque_body` a v1
%   `daqmetadatareader_epochdata_ingested` becomes:
%
%       The ingested stimulus file of epoch <EPOCHID>: the metadata the NDI
%       metadata reader <READERID>
%
%   followed, in the description, by ' (<reader class>)' when the class is
%   known and then ' read from the epoch''s files, ...'.
%
%   ONE FUNCTION, BOTH SIDES. The body records its epoch and its metadata
%   reader only here: did-schema's data_body has no epoch field, and the
%   presentation manipulation that owns the body is anchored "during the
%   session", not to the epoch. So the writer
%   (ndi.migrate.internal.ingestedStimulusBodies) and the reader
%   (ndi.vintage.ingestedStimulusBody, which ndi.daq.metadatareader's
%   get_ingested_document asks) build the text here, and cannot drift apart.
%
%   Decided by Jess Haley, 2026-10-26 [ingested stimulus file is a body of the
%   presentation] and [ingested stimulus reader finds the body] (did-schema
%   V_eta_go_forward_class_audit.md).
%
%   See also ndi.vintage.ingestedStimulusBody,
%            ndi.migrate.internal.ingestedStimulusBodies.

arguments
    epochId {mustBeText}
    readerId {mustBeText}
end

key = sprintf(['The ingested stimulus file of epoch %s: the metadata the NDI ' ...
    'metadata reader %s'], char(epochId), char(readerId));
end
