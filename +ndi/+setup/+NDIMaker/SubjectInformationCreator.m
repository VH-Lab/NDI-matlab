% file: +ndi/+setup/+NDIMaker/SubjectInformationCreator.m

classdef (Abstract) SubjectInformationCreator < handle
%SUBJECTINFORMATIONCREATOR Abstract base class for creating NDI subject information.
%
%   This abstract class defines the standard interface for creating NDI subject
%   documents and related openMINDS objects from a row of a metadata table.
%
%   Subclasses must implement the 'create' method to define lab-specific
%   logic for interpreting table data.

    methods (Abstract)
        % CREATE - Generates subject information from a single table row.
        %
        %   [SUBJECTIDENTIFIER, STRAIN, SPECIES, BIOLOGICALSEX] = CREATE(OBJ, TABLEROW)
        %
        %   This method must be implemented by all subclasses. It takes a
        %   1-row table as input and returns the subject's local identifier
        %   and any relevant openMINDS objects.
        %
        %   Inputs:
        %       obj (ndi.setup.SubjectInformationCreator) - The instance of the creator class.
        %       tableRow (table) - A single row from a MATLAB table containing the
        %                          metadata for a single epoch or recording.
        %
        %   Outputs:
        %       subjectIdentifier (char) - The unique local identifier string for the subject
        %                                  (e.g., 'mySubject_01@mylab.org'). Return NaN on failure.
        %       strain (openminds.core.research.Strain) - An openMINDS strain object. Return NaN if not applicable.
        %       species (openminds.controlledterms.Species) - An openMINDS species object. Return NaN if not applicable.
        %       biologicalSex (openminds.controlledterms.BiologicalSex) - An openMINDS sex object. Return NaN if not applicable.
        %
        [subjectIdentifier, strain, species, biologicalSex] = create(obj, tableRow);
    end % abstract methods

end % classdef