function [labels, docs] = lookup_uberon_term(term_name, options)
%LOOKUP_UBERON_TERM  Looks up a term in the UBERON ontology using the OLS API.
%
%   [labels, docs] = LOOKUP_UBERON_TERM(term_name, ...) 
%   searches for the specified term in the UBERON ontology and returns 
%   information about the matching terms.
%
%   Inputs:
%       term_name: The name or description of the term to search for.
%       ontology: The ontology to search in (default: 'uberon').
%       type: The type of term to search for (default: 'class').
%       exact: Whether to perform an exact match (default: false).
%       queryFields: The field to search in (default: 'label').
%
%   Outputs:
%       labels: A cell array of labels for the matching terms.
%       docs: The complete response.response.docs structure from the OLS API.
%
%   Example:
%       [labels, docs] = lookup_uberon_term('lateral gastric nerve');
%       [labels, docs] = lookup_uberon_term('heart', 'queryFields','description');

  arguments
      term_name (1, :) char
      options.ontology (1, :) char = 'uberon'
      options.type (1, :) char = 'class'
      options.exact (1, 1) logical = false
      options.queryFields (1, :) char = 'label'
  end

  % Construct the URL for the OLS API
  url = 'https://www.ebi.ac.uk/ols/api/search';

  % Send the request to the OLS API
  webOptions = weboptions('Timeout', 30, 'ContentType', 'json');  % Set timeout and content type
  response = webread(url, ...
                     'q', term_name, ...
                     'ontology', options.ontology, ...
                     'type', options.type, ...
                     'queryFields', options.queryFields, ...
                     'exact', string(options.exact), ...  
                     webOptions);

  % Extract the labels and docs
  docs = response.response.docs;
  labels = cell(numel(docs), 1);
  for i = 1:numel(docs)
      labels{i} = docs(i).label;
  end

end

