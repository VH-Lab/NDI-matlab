function [ndiDocArray, openMindsObj] = makeSpeciesStrainSex(ndiSession, subjectID, options)
% MAKESPECIESSTRAINSEX - add species, strain, or sex information for a subject in an ndi.session
%
% [NDIDOCARRAY, OPENMINDSOBJ] = ndi.fun.doc.subject.makeSpeciesStrainSex(ndiSession, subjectID, ...)
%
%  (Detailed help description would go here)
%

    arguments
        % Positional Arguments
        ndiSession (1,1) ndi.session {mustBeNonempty} % Must be a single, non-empty ndi.session object
        subjectID (1,1) {mustBeTextScalar, ndi.validator.mustBeID} % Must be char/string scalar and pass NDI ID validation

        % Optional Name-Value Arguments (options structure)
        options.BiologicalSex (1,:) char ...
             {mustBeMember(options.BiologicalSex, {'', 'male', 'female', 'hermaphrodite', 'notDetectable'})} = ''

        options.Species       (1,:) char = '' % Optional: Species as NCBI Taxonomy identifier
        options.Strain (1,:) char = '' % if you intend to handle strain here too
    end


