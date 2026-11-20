function name = acquisitionConfigurationClass()
%ACQUISITIONCONFIGURATIONCLASS The class a daq system's V2 record is written as.
%
%   NAME = ndi.vintage.acquisitionConfigurationClass() is
%   'acquisition_configuration' when the loaded did-schema declares that
%   class, else 'acquisition_system'. Decided by Jess Haley, 2026-11-19
%   [acquisition configuration renamed] (did-schema
%   docs/plans/did_v2_standing_wiring_plan.md): `acquisition_system` is
%   renamed `acquisition_configuration`, how a device's recordings are read.
%   The siblings write the new name before did-schema renames the class, and
%   NDI CI reads did-schema `main` (or a same-name branch), so a writer asks
%   the schema in use which name it holds, as DID-matlab's migrator does
%   (did2.convert.acquisitionConfigurationClass). Readers take either name
%   (ndi.vintage.acquisitionConfigurationNames).
%
%   See also: ndi.vintage.acquisitionConfigurationNames,
%             ndi.vintage.acquisitionConfigurationQuery.

name = 'acquisition_system';
if did2.schema.cache.shared().hasClass('acquisition_configuration')
    name = 'acquisition_configuration';
end
end
