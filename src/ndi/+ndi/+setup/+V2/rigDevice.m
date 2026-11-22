function docs = rigDevice(rigName, configurationId, sessionId)
%RIGDEVICE The device entity of a rig, for its acquisition_configuration.
%
%   DOCS = ndi.setup.V2.rigDevice(RIGNAME, CONFIGURATIONID, SESSIONID)
%   returns {entity} (a did2 document struct): an `entity` of type device
%   whose `name` is RIGNAME and nothing else, in session SESSIONID, for the
%   acquisition_configuration whose id is CONFIGURATIONID to name by
%   `device_id`; or {} when RIGNAME is empty (a rig with no name mints no
%   device, as in the migration).
%
%   did-schema docs/plans/did_v2_standing_wiring_plan.md [acquisition system
%   is a device entity] and [device id required and named by the rig]: one
%   device entity per rig per session, named with the rig's name in `name`
%   only ([local identifier required only where looked up],
%   did_v2_go_forward_class_audit.md), as DID-matlab's
%   +did2/+convert/+migrators_j/daqsystem.m mints it for a v1 daqsystem.
%
%   THE ID is DID-matlab's: did2.convert.mintId('rig device', CONFIGURATIONID).
%   The migration mints the device with did2.convert.mintId('rig device')
%   inside the context v1_to_v2 opens for the v1 daqsystem, keyed on its
%   base.id (did2.convert.mintKey), and keeps that base.id as the
%   configuration's id; both forms derive the id from (that id, 'rig device',
%   1). So a session whose daq system ndi.daq.system/newdocumentV2 writes and
%   the same session migrated from v1 hold the same device id.
%
%   The writers: ndi.daq.system/newdocumentV2 (every named system) and
%   ndi.setup.conv.haley.sessionDocuments (a system whose instrument is not
%   known).
%
%   See also: ndi.setup.V2.entityDocuments, did2.convert.mintId.

arguments
    rigName {mustBeText}
    configurationId {mustBeTextScalar, mustBeNonzeroLengthText}
    sessionId {mustBeTextScalar, mustBeNonzeroLengthText}
end

docs = {};
if isempty(rigName) || strlength(string(rigName)) == 0
    return;
end
docs = ndi.setup.V2.entityDocuments('device', struct('name', char(rigName)), struct(), ...
    'SessionId', char(sessionId), 'Id', did2.convert.mintId('rig device', char(configurationId)));
end
