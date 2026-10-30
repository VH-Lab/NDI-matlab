function [T, earlier] = channelTypes()
%CHANNELTYPES The v1 channel-type prefixes and the term each became.
%
%   [T, EARLIER] = ndi.vintage.channelTypes() returns T, a 10-by-2 cell,
%   {prefix, node}, one row per hardware channel type NDI's mfdaq systems name
%   (ndi.daq.system.mfdaq, ndi.daq.daqsystemstring), with the node a channel
%   type is written with now; and EARLIER, an N-by-2 cell {prefix, node} of
%   nodes a channel type was written with before, which documents already
%   migrated may still carry. Readers accept both (ndi.v2.vocabNodes).
%
%   Decided by Jess Haley, 2026-10-29 [text channel replaces NCIT Text]
%   (V_eta_go_forward_class_audit.md): the channel type of v1 prefix `tx` is
%   EMPTY:0000410 "text channel", replacing NCIT:C25704 Text. NDI reads
%   EMPTY:0000410 as 'tx' before DID-matlab's map writes it, and keeps reading
%   NCIT:C25704 as 'tx' for sessions already migrated.
%
%   did-schema #88, Decided by Jess Haley, 2026-10-22 [channel types]
%   (V_eta_go_forward_class_audit.md): `acquisition_channels.channels.type`
%   binds these ten types under NCIT:C44170 Channel; DID-matlab's migrator
%   maps each v1 prefix to its term, and NDI maps the term back to the prefix
%   for its readers. [registry holds nodes] (S1): that map lives in the two
%   codes, not in the term registry, and code matches a channel type by its
%   node, so a stored name (the prefix before the flip, the ontology label
%   after it) does not matter.
%
%   The eight read modes NDI derives from a channel at read time (dep den
%   dimp dimn aep aen aimp aimn) are not channel types and have no term: a
%   stored type that is one of them (a migrated syncrule's 'dep') has no
%   node and is read by its name, unchanged.
%
%   See also ndi.vintage.channelPrefix, ndi.v2.vocabNodes.

T = {
    'ai', 'EMPTY:0000370'   % analog input channel
    'ao', 'EMPTY:0000371'   % analog output channel
    'di', 'EMPTY:0000372'   % digital input channel
    'do', 'EMPTY:0000373'   % digital output channel
    't',  'EMPTY:0000374'   % time channel
    'ax', 'EMPTY:0000375'   % auxiliary input channel
    'e',  'EMPTY:0000376'   % event channel
    'mk', 'EMPTY:0000377'   % marker channel
    'md', 'NCIT:C52095'     % Metadata
    'tx', 'EMPTY:0000410'   % text channel
    };
earlier = {
    'tx', 'NCIT:C25704'     % Text, before [text channel replaces NCIT Text]
    };
end
