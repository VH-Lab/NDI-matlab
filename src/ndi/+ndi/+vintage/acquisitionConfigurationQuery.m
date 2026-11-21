function q = acquisitionConfigurationQuery()
%ACQUISITIONCONFIGURATIONQUERY An `isa` query for a daq system's V2 record.
%
%   Q = ndi.vintage.acquisitionConfigurationQuery() is the OR of
%   `isa <name>` over ndi.vintage.acquisitionConfigurationNames, so it finds
%   an `acquisition_configuration` and an `acquisition_system` (the name
%   before Jess Haley's decision of 2026-11-19 [acquisition configuration
%   renamed]). Unlike ndi.vintage.isaQuery('daqsystem') it does not find a
%   v1 `daqsystem`: the sites that use it read the V2 record only.
%
%   See also: ndi.vintage.acquisitionConfigurationNames, ndi.vintage.isaQuery.

names = ndi.vintage.acquisitionConfigurationNames();
q = ndi.query('', 'isa', names{1}, '');
for i = 2:numel(names)
    q = q | ndi.query('', 'isa', names{i}, '');
end
end
