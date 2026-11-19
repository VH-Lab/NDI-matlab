function n = syncConfigurationNames(mode, cache)
%SYNCCONFIGURATIONNAMES The edge and label names of a clock_alignment_configuration.
%
%   N = ndi.vintage.syncConfigurationNames() returns the names a
%   `clock_alignment_configuration` links its two rigs by and labels its two
%   trigger channels with, as the loaded did-schema declares them:
%
%     N.inputEdge      'input_id' when the schema declares it, else
%                      'from_acquisition_system_id' (v1 daqsystem1)
%     N.outputEdge     'output_id' when the schema declares it, else
%                      'to_acquisition_system_id' (v1 daqsystem2)
%     N.inputChannel   'input trigger channel' when the term registry holds
%                      it, else 'from trigger channel' (v1 daqsystem_ch1)
%     N.outputChannel  'output trigger channel' when the term registry holds
%                      it, else 'to trigger channel' (v1 daqsystem_ch2)
%
%   and, for readers, every spelling a stored configuration may use, newest
%   first:
%
%     N.inputEdges     {'input_id', 'from_acquisition_system_id'}
%     N.outputEdges    {'output_id', 'to_acquisition_system_id'}
%     N.inputChannels  {'input trigger channel', 'from trigger channel', 'daqsystem_ch1'}
%     N.outputChannels {'output trigger channel', 'to trigger channel', 'daqsystem_ch2'}
%
%   Decided by Jess Haley, 2026-11-10 [sync configuration edges are input
%   and output] (did-schema docs/plans/did_v2_go_forward_class_audit.md):
%   `from_acquisition_system_id` / `to_acquisition_system_id` become
%   `input_id` / `output_id`, and the method parameters "from/to trigger
%   channel" become "input/output trigger channel". The direction is
%   unchanged: input is the rig whose clock is mapped (v1 daqsystem1),
%   output the rig it is mapped onto (v1 daqsystem2). NDI-matlab reads both
%   spellings and writes what the loaded schema declares, so did-schema can
%   rename the edges (and the term registry the labels) after this lands
%   (did-schema CLAUDE.md section 3: changes the siblings must follow land
%   there first).
%
%   N = ndi.vintage.syncConfigurationNames('read') returns only the reader
%   lists (the four plural fields) and touches neither the schema nor the
%   term registry, so a reader does not depend on which schema is loaded.
%
%   N = ndi.vintage.syncConfigurationNames('write', CACHE) asks the
%   did2.schema.cache CACHE instead of the shared one.
%
%   See also: ndi.time.syncrule/newdocumentV2, ndi.vintage.syncruleParameters.

arguments
    mode (1,:) char {mustBeMember(mode, {'read', 'write'})} = 'write'
    cache = []
end

n = struct();
n.inputEdges     = {'input_id', 'from_acquisition_system_id'};
n.outputEdges    = {'output_id', 'to_acquisition_system_id'};
n.inputChannels  = {'input trigger channel', 'from trigger channel', 'daqsystem_ch1'};
n.outputChannels = {'output trigger channel', 'to trigger channel', 'daqsystem_ch2'};
if strcmp(mode, 'read')
    return;
end
if isempty(cache)
    cache = did2.schema.cache.shared();
end

declared = edgeNames(cache);
if any(strcmp(declared, 'input_id')) && any(strcmp(declared, 'output_id'))
    n.inputEdge = 'input_id';
    n.outputEdge = 'output_id';
else
    n.inputEdge = 'from_acquisition_system_id';
    n.outputEdge = 'to_acquisition_system_id';
end

if registryHolds('input trigger channel') && registryHolds('output trigger channel')
    n.inputChannel = 'input trigger channel';
    n.outputChannel = 'output trigger channel';
else
    n.inputChannel = 'from trigger channel';
    n.outputChannel = 'to trigger channel';
end
end

function names = edgeNames(cache)
names = {};
try
    s = cache.getClass('clock_alignment_configuration');
catch
    return;
end
if ~isfield(s, 'depends_on') || isempty(s.depends_on)
    return;
end
d = s.depends_on;
if isstruct(d); d = num2cell(d); end
names = cellfun(@(x) char(x.name), d, 'UniformOutput', false);
end

function tf = registryHolds(name)
tf = false;
ix = did2.schema.termIndex();
if ~ix.present
    return;
end
tf = isKey(ix.byName, did2.schema.termNameKey(name));
end
