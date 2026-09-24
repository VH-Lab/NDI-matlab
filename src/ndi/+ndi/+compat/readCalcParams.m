function params = readCalcParams(doc, propertyListName)
%READCALCPARAMS Read a calculator document's parameters block, V_eta first, v1 fallback.
%
%   PARAMS = NDI.COMPAT.READCALCPARAMS(DOC, PROPERTYLISTNAME) returns the
%   run-parameters struct stored on calculator document DOC under its
%   class-scoped property block PROPERTYLISTNAME.
%
%   Under the V_eta canonical schema, calculator classes inherit from
%   subject_interaction and store their run knobs under the
%   `method_parameters` field. Under the did_v1 legacy schema the same
%   knobs lived under `input_parameters`. This helper reads
%   `method_parameters` first (V_eta canonical) and falls back to
%   `input_parameters` (v1) so caller code that hard-coded either name
%   keeps working when handed a document written under either schema.
%
%   Framework code that reads a calculator document's parameters block
%   should route through this helper rather than reaching into
%   `document_properties.<block>.input_parameters` directly. The
%   caller-facing `parameters.input_parameters` convention used by
%   ndi.calculator/run and its friends is a separate concern -- it names
%   an argument passed IN, not a field read out of a stored document --
%   and is not affected by this helper.
%
%   Inputs:
%     DOC              1x1 ndi.document
%     PROPERTYLISTNAME (1,:) char - the calculator document's
%                      property_list_name (the top-level block under
%                      document_properties, e.g. 'oridirtuning_calc'
%                      under V_eta or 'orientation_direction_tuning'
%                      under v1).
%
%   Outputs:
%     PARAMS  The parameters struct, or [] if neither field is present.
%
%   Notes:
%     - `method_parameters` wins whenever it is present, even if it is
%       empty ([]). The fallback to `input_parameters` fires only when
%       `method_parameters` is absent, which keeps "explicitly no
%       parameters" distinguishable from "field not written". This
%       matters for search_for_calculator_docs equivalence tests.
%     - A DOC whose property block PROPERTYLISTNAME is absent returns
%       []. That mirrors the behaviour of the getfieldpath+try/catch
%       pattern this helper replaces.
%
%   See also: ndi.calculator/search_for_calculator_docs,
%             ndi.compat.augmentRead, ndi.util.getfieldpath.

    arguments
        doc (1,1) ndi.document
        propertyListName (1,:) char {mustBeNonempty}
    end

    body = doc.document_properties;

    if ~isfield(body, propertyListName)
        params = [];
        return;
    end

    block = body.(propertyListName);

    if isfield(block, 'method_parameters')
        params = block.method_parameters;
        return;
    end

    if isfield(block, 'input_parameters')
        params = block.input_parameters;
        return;
    end

    params = [];
end
