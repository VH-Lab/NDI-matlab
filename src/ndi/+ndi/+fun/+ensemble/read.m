function [activity, neuron_ids, neuron_names, info] = read(S, ensembleElement, epoch)
% ndi.fun.ensemble.read - read one epoch of an ensemble element
%
% [ACTIVITY, NEURON_IDS, NEURON_NAMES, INFO] = ndi.fun.ensemble.READ(S, ENSEMBLEELEMENT, EPOCH)
%
% Reads the ensemble activity for epoch EPOCH from ENSEMBLEELEMENT, an
% ndi.element.ensemble (or its document / id) belonging to the ndi.session (or
% ndi.dataset) S.
%
% =========================================================================
% OUTPUTS
% =========================================================================
%   ACTIVITY     - an N-neurons-by-Smax sparse matrix; ACTIVITY(i,n) is the time
%                  of the n-th spike of neuron i (reconstructed from the
%                  element's stored marked point process, see
%                  ndi.element.ensemble/spikeMatrix). For a windowed / streaming
%                  read, call ENSEMBLEELEMENT.readtimeseries directly instead.
%   NEURON_IDS   - a 1-by-N cell array of the neuron element document ids, in
%                  the row order of ACTIVITY.
%   NEURON_NAMES - a 1-by-N cell array of the neuron names, same order.
%   INFO         - the 'ensemble' property structure of the epoch's map document
%                  (ensemble_name, value_type, value_description, num_neurons,
%                  clocktype).
%
% EPOCH may be an epoch id (char) or an epoch index (number).
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   ens = ndi.fun.ensemble.create(S, probe, 'epoch_1');
%   [E, ids, names, info] = ndi.fun.ensemble.read(S, ens, 'epoch_1');
%
% See also: ndi.element.ensemble, ndi.fun.ensemble.create, ndi.fun.ensemble.plot

    arguments
        S
        ensembleElement
        epoch
    end

    ens = local_ensemble(ensembleElement, S);

    [activity, neuron_ids] = ens.spikeMatrix(epoch);
    neuron_names = ens.neuronNames(epoch);
    mapdoc = ens.epochEnsembleDoc(epoch);
    info = mapdoc.document_properties.ensemble;

end % read()

% -------------------------------------------------------------------------

function ens = local_ensemble(x, S)
% return an ndi.element.ensemble from an object, a document, or an id
    if isa(x, 'ndi.element.ensemble')
        ens = x;
    else
        ens = ndi.database.fun.ndi_document2ndi_object(x, S);
        if ~isa(ens, 'ndi.element.ensemble')
            error('ndi:ensemble:read:notEnsemble', ...
                'The provided element is not an ndi.element.ensemble.');
        end
    end
end % local_ensemble()
