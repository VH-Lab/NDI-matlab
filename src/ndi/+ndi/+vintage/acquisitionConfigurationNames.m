function c = acquisitionConfigurationNames()
%ACQUISITIONCONFIGURATIONNAMES The V2 class names of a daq system's record.
%
%   C = ndi.vintage.acquisitionConfigurationNames() returns
%   {'acquisition_configuration', 'acquisition_system'}: the current name
%   first, then the name documents written before the rename carry. Decided
%   by Jess Haley, 2026-11-19 [acquisition configuration renamed] (did-schema
%   docs/plans/did_v2_standing_wiring_plan.md): `acquisition_system` is
%   renamed `acquisition_configuration`, how a device's recordings are read.
%   The siblings read both names before did-schema renames the class.
%
%   The list is the `daqsystem` row's `eta_class` in ndi.vintage.map, the one
%   place it is kept.
%
%   See also: ndi.vintage.acquisitionConfigurationQuery, ndi.vintage.map.

c = ndi.vintage.names(ndi.vintage.entryFor('daqsystem').eta_class);
end
