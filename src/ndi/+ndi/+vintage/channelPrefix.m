function prefix = channelPrefix(type)
%CHANNELPREFIX The v1 channel-type prefix ('ai', 'di', 'mk', ...) of a stored channel type.
%
%   PREFIX = ndi.vintage.channelPrefix(TYPE). TYPE is an
%   `acquisition_channels.channels.type` term ({node, name}) or a char.
%   The prefix is found BY NODE (ndi.vintage.channelTypes, Jess Haley
%   2026-10-22 [channel types], [registry holds nodes]); a term without a
%   known node is read by its name: a prefix written before the terms
%   existed ('ai'), a read mode that has no term ('dep'), or the ontology
%   label ('analog input channel'), which is mapped back through the schema's
%   binding. A type that matches nothing is returned as its name, so a reader
%   sees what was stored rather than nothing.
%
%   See also ndi.vintage.channelTypes, ndi.v2.vocabHandle.

prefix = ndi.v2.vocabHandle('channel_type', type);
end
