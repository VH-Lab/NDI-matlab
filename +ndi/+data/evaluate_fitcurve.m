function [y, varargout] = evaluate_fitcurve(fitcurve_doc, varargin)
    % EVALUATE_FITCURVE - evaluate a fitcurve (the standard fitcurve type)
    %
    % Y = EVALUATE_FITCURVE(FITCURVE_DOC, X, ...)
    %
    % Evaluate an FITCURVE document function for indicated values of X.
    %
    
    % Step 1: extract information from document

    fit_equation = fitcurve_doc.document_properties.fitcurve.fit_equation;

    fit_independent_variables = strsplit(fitcurve_doc.document_properties.fitcurve.fit_independent_variable_names);

    for i=1:numel(fit_independent_variables)
        fit_independent_variables{i} = strtrim(fit_independent_variables{i}); % remove whitespace
    end;

    if numel(fit_independent_variables)>1
        error(['Do not know how to deal with this yet.']); % pretty easy though, just process variable input arguments
    end;

    fit_dependent_variables = strsplit(fitcurve_doc.document_properties.fitcurve.fit_dependent_variable_names);

    for i=1:numel(fit_dependent_variables)
        fit_dependent_variables{i} = strtrim(fit_dependent_variables{i}); % remove whitespace
    end;

    if numel(fit_dependent_variables)>1
        error(['Do not know how to deal with this yet.']);
    end;

    fit_parameter_names = strsplit(fitcurve_doc.document_properties.fitcurve.fit_parameter_names);

    for i=1:numel(fit_parameter_names)
        fit_parameter_names{i} = strtrim(fit_parameter_names{i});
    end;

    fit_parameter_values = fitcurve_doc.document_properties.fitcurve.fit_parameters;
    if ischar(fit_parameter_values)
        fit_parameter_values = str2mat(fit_parameter_values);
    end;

    if numel(fit_parameter_values) ~= numel(fit_parameter_names)
        error(['Fit parameter names and fit parameter values do not have same number of entries.']);
    end;

    % Step 2: Change all variables from 'name' to 'ndi_evaluate_fitcurve_name'

    fit_equation_mod = fit_equation;

    for i=1:numel(fit_parameter_names)
        fit_equation_mod = regexprep(fit_equation_mod,['(?<![\w\d])' fit_parameter_names{i} '(?![\w\d])'],['ndi_evaluate_fitcurve_' fit_parameter_names{i}]);
        vlt.data.assign(['ndi_evaluate_fitcurve_' fit_parameter_names{i}], fit_parameter_values(i));
    end;

    for i=1:numel(fit_independent_variables)
        fit_equation_mod = regexprep(fit_equation_mod,['(?<![\w\d])' fit_independent_variables{i} '(?![\w\d])'],['ndi_evaluate_fitcurve_' fit_independent_variables{i}]);
        vlt.data.assign(['ndi_evaluate_fitcurve_' fit_independent_variables{i}], varargin{i});
    end;

    for i=1:numel(fit_dependent_variables)
        fit_equation_mod = regexprep(fit_equation_mod,['(?<![\w\d])' fit_dependent_variables{i} '(?![\w\d])'],['ndi_evaluate_fitcurve_' fit_dependent_variables{i}]);
    end;

    eval([fit_equation_mod ';']);

    vlt.data.assign('y', eval(['ndi_evaluate_fitcurve_' fit_dependent_variables{i}]));
