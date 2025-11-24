# Manual: Writing ndi.calculator Objects

## Overview

An `ndi.calculator` is a mini-app in the NDI (Neuroscience Data Interface) system that performs computations on data and stores the results as NDI documents in a database. Calculators enable reproducible, traceable analysis by:

- Defining clear input parameters and dependencies
- Storing computational results with full provenance
- Allowing queries to find and reuse existing calculations
- Supporting both simple and complex multi-step analyses

## Repository Structure

External calculators (those not in the core NDI-matlab repository) are typically organized in repositories following the naming convention **`NDIcalc-REPONAME-matlab`**, where `REPONAME` describes the domain or purpose of the calculators. For example:

- `NDIcalc-vis-matlab` - Calculators for vision research
- `NDIcalc-extracellular-matlab` - Calculators for extracellular recordings (future)

### Standard Folder Structure

Each calculator repository contains three main folders:

```
NDIcalc-REPONAME-matlab/
├── +ndi/
│   └── +calc/
│       └── +category/
│           ├── calculator1.m
│           ├── calculator2.m
│           └── ...
├── ndi_common/
│   ├── database_documents/
│   │   └── calc/
│   │       ├── calculator1_calc.json
│   │       ├── calculator2_calc.json
│   │       └── ...
│   └── schema_documents/
│       └── calc/
│           ├── calculator1_calc_schema.json
│           ├── calculator2_calc_schema.json
│           └── ...
└── docs/
```

**Key directories**:

- **`+ndi/+calc/`** - Contains the MATLAB calculator class files organized by category (e.g., `+vis`, `+extracellular`)
- **`ndi_common/database_documents/calc/`** - Contains JSON files that define the structure of blank calculator output documents
- **`ndi_common/schema_documents/calc/`** - Contains JSON schema files for validating calculator documents

This structure ensures consistency across calculator packages and allows NDI to automatically discover and validate calculator document types.

## Architecture

Each calculator consists of two main components:

1. **MATLAB Class File** - The code that performs calculations (`.m` file)
2. **JSON Document Definition** - The database schema for storing results (`.json` file)

## Required Components

### 1. Class File Structure

Your calculator class must:
- Inherit from `ndi.calculator`
- Implement three required methods:
  - `constructor(session)` - Initialize the calculator
  - `calculate(parameters)` - Perform the computation
  - `default_search_for_input_parameters()` - Define default parameters

**Location**: `+ndi/+calc/+[category]/[calculator_name].m`

Example categories: `+vis`, `+extracellular`, `+example`

### 2. JSON Document Definition

Defines the structure of the output document, including:
- Document metadata (class name, version, superclasses)
- Dependencies (what documents this calculator depends on)
- Input parameters (configuration values)
- Output fields (results to be stored)

**Location**: `ndi_common/database_documents/calc/[calculator_name]_calc.json`

### 3. JSON Schema Definition (Optional)

A JSON schema file validates the structure of calculator documents, ensuring they conform to the expected format. While optional, schemas are recommended for production calculators.

**Location**: `ndi_common/schema_documents/calc/[calculator_name]_calc_schema.json`

The schema defines validation rules for all fields in your calculator document. Refer to existing schema files in the repository for examples.

## Step-by-Step Guide

### Step 1: Plan Your Calculator

Before coding, determine:

1. **Input**: What documents/elements does your calculator need?
   - Examples: spike times, stimulus information, element epochs

2. **Parameters**: What configuration values are needed?
   - Examples: time windows, thresholds, filter settings

3. **Output**: What results will be stored?
   - Examples: tuning curves, statistics, waveforms

4. **Binary Data**: Will you store large data files?
   - Examples: spike waveforms, images, time series

5. **Granularity**: One document per analysis, or multiple documents?
   - Important: NDI documents cannot be updated, only deleted and recreated
   - If you'll add more data later, create separate documents (e.g., one per epoch)

### Step 2: Create the JSON Document Definition

Start from the simple template (`simple_calc.json`) and customize:

```json
{
    "document_class": {
        "definition": "$NDICALCDOCUMENTPATH/calc/my_calculator_calc.json",
        "validation": "$NDICALCSCHEMAPATH/calc/my_calculator_calc_schema.json",
        "class_name": "my_calculator_calc",
        "property_list_name": "my_calculator_calc",
        "class_version": 1,
        "superclasses": [
            { "definition": "$NDIDOCUMENTPATH/base.json" },
            { "definition": "$NDIDOCUMENTPATH/app.json" }
        ]
    },
    "depends_on": [
        { "name": "element_id", "value": 0 }
    ],
    "my_calculator_calc": {
        "input_parameters": {
            "param1": 0.001,
            "param2": 100
        },
        "output_field1": [],
        "output_field2": []
    }
}
```

**Key fields**:
- `depends_on` - Documents this calculator requires (by their IDs)
- `input_parameters` - Configuration values with defaults
- Additional fields - Your output results (initialize with appropriate defaults)

**Optional**: Add `"files"` section if storing binary data:
```json
"files": {
    "file_list": [ "mydata.bin" ]
}
```

### Step 3: Create the MATLAB Class

#### 3.1 Constructor

```matlab
classdef my_calculator < ndi.calculator

    methods
        function obj = my_calculator(session)
            % MY_CALCULATOR - calculator that does [description]
            %
            % OBJ = MY_CALCULATOR(SESSION)
            %
            % Creates a MY_CALCULATOR ndi.calculator object
            %

            % Get path to JSON file using dynamic path resolution
            w = which('ndi.calc.category.my_calculator');
            parparparpar = fileparts(fileparts(fileparts(fileparts(w))));

            % Call superclass constructor with document type info
            obj = obj@ndi.calculator(session, 'my_calculator_calc', ...
                fullfile(parparparpar, 'ndi_common', 'database_documents', ...
                'calc', 'my_calculator_calc.json'));
        end
```

**Key points**:
- Use `fileparts()` chain to navigate from class location to root directory
- First argument to superclass: document type name (without `.json`)
- Second argument: full path to JSON definition file

#### 3.2 Calculate Method

```matlab
        function doc = calculate(ndi_calculator_obj, parameters)
            % CALCULATE - perform the calculation
            %
            % DOC = CALCULATE(NDI_CALCULATOR_OBJ, PARAMETERS)
            %
            % Creates a my_calculator_calc document given input parameters.
            %

            % Validate inputs
            if ~isfield(parameters, 'input_parameters')
                error('parameters structure lacks ''input_parameters''.');
            end
            if ~isfield(parameters, 'depends_on')
                error('parameters structure lacks ''depends_on''.');
            end

            % Step 1: Extract dependencies
            element_id = did.db.struct_name_value_search(...
                parameters.depends_on, 'element_id');
            element = ndi.database.fun.ndi_document2ndi_object(...
                element_id, ndi_calculator_obj.session);

            % Step 2: Perform your calculation
            result = your_analysis_function(element, ...
                parameters.input_parameters);

            % Step 3: Build output structure
            output = parameters;  % Start with input parameters
            output.output_field1 = result.data1;
            output.output_field2 = result.data2;

            % Step 4: Create NDI document
            doc = ndi.document(...
                ndi_calculator_obj.doc_document_types{1}, ...
                'my_calculator_calc', ...
                output);

            % Step 5: Set dependencies
            for i = 1:numel(parameters.depends_on)
                doc = doc.set_dependency_value(...
                    parameters.depends_on(i).name, ...
                    parameters.depends_on(i).value);
            end

            % Optional: Add binary files
            % doc = doc.add_file('mydata.bin', full_path_to_file);
        end
```

**Key points**:
- Always validate that `input_parameters` and `depends_on` exist
- Use `did.db.struct_name_value_search()` to extract dependency values
- Start output structure with `parameters` to preserve input info
- Use `ndi_calculator_obj.doc_document_types{1}` for document type
- Document property name (3rd arg) must match JSON definition

#### 3.3 Default Search Parameters

```matlab
        function parameters = default_search_for_input_parameters(...
                ndi_calculator_obj)
            % DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default search parameters
            %
            % PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ)
            %
            % Returns default search parameters for finding inputs.
            %

            % Set default input parameters
            parameters.input_parameters = struct(...
                'param1', 0.001, ...
                'param2', 100);

            % Initialize empty depends_on structure
            parameters.depends_on = did.datastructures.emptystruct(...
                'name', 'value');

            % Define query to find appropriate input documents
            parameters.query = struct('name', 'element_id', ...
                'query', ndi.query('element.type', 'exact_string', ...
                'spikes', ''));
        end
```

**Key points**:
- `input_parameters` - Default values for your parameters
- `depends_on` - Use `emptystruct()` to create proper structure
- `query` - Defines how to search for input documents
  - `name` - Which dependency to search for
  - `query` - `ndi.query` object specifying search criteria

### Step 4: Optional Methods

#### 4.1 Custom Query Logic

If you need more complex queries:

```matlab
        function query = default_parameters_query(...
                ndi_calculator_obj, parameters_specification)
            % DEFAULT_PARAMETERS_QUERY - custom query logic
            %
            % Allows combining multiple queries with AND/OR logic
            %

            q1 = ndi.query('', 'isa', 'stimulus_tuningcurve', '');
            q2 = ndi.query('stimulus_tuningcurve.independent_variable_label', ...
                'contains_string', 'contrast', '');
            q3 = ndi.query('stimulus_tuningcurve.independent_variable_label', ...
                'contains_string', 'Contrast', '');

            % Combine queries: | for OR, & for AND
            q_combined = q1 & (q2 | q3);

            query = struct('name', 'stimulus_tuningcurve_id', ...
                'query', q_combined);
        end
```

#### 4.2 Input Validation

For additional validation beyond queries:

```matlab
        function b = is_valid_dependency_input(...
                ndi_calculator_obj, name, value)
            % IS_VALID_DEPENDENCY_INPUT - validate potential inputs
            %
            % B = IS_VALID_DEPENDENCY_INPUT(NDI_CALCULATOR_OBJ, NAME, VALUE)
            %
            % Returns true if the document with id VALUE is valid for
            % dependency NAME.
            %

            b = 1;  % Default to true

            switch lower(name)
                case 'stimulus_tuningcurve_id'
                    % Custom validation logic
                    q = ndi.query('base.id', 'exact_string', value, '');
                    d = ndi_calculator_obj.session.database_search(q);
                    if ~isempty(d)
                        d = d{1};
                        % Check specific conditions
                        b = numel(d.document_properties...
                            .independent_variable_label) == 1;
                    end
                otherwise
                    b = 1;
            end
        end
```

#### 4.3 Binary Data Loading

If your calculator stores binary files:

```matlab
        function [data1, data2] = load(ndi_calculator_obj, doc)
            % LOAD - load binary data from document
            %
            % [DATA1, DATA2] = LOAD(NDI_CALCULATOR_OBJ, DOC)
            %
            % Loads binary data associated with document DOC.
            %

            % Convert doc_id to document if needed
            if ~isa(doc, 'ndi.document')
                doc = ndi_calculator_obj.session.database_search(...
                    ndi.query('base.id', 'exact_string', doc));
            end

            % Open binary file
            myfile = ndi_calculator_obj.session.database_openbinarydoc(...
                doc, 'mydata.bin');

            % Read data using appropriate format
            [data1, data2] = your_read_function(myfile);

            % Close file
            ndi_calculator_obj.session.database_closebinarydoc(myfile);
        end
```

#### 4.4 Plotting Results

For visualizing calculator output:

```matlab
        function h = plot(ndi_calculator_obj, doc_or_parameters, varargin)
            % PLOT - visualize calculator results
            %
            % H = PLOT(NDI_CALCULATOR_OBJ, DOC_OR_PARAMETERS, ...)
            %
            % Produces a diagnostic plot of the results.
            %

            % Call superclass to set up axes
            h = plot@ndi.calculator(ndi_calculator_obj, ...
                doc_or_parameters, varargin{:});

            if isa(doc_or_parameters, 'ndi.document')
                doc = doc_or_parameters;
            else
                error('Plotting requires an ndi.document.');
            end

            % Extract data
            data = doc.document_properties.my_calculator_calc;

            % Create plots
            hold on;
            plot(data.x, data.y, 'b-', 'linewidth', 2);

            % Add labels if not suppressed
            if ~h.params.suppress_x_label
                h.xlabel = xlabel('X Label');
            end
            if ~h.params.suppress_y_label
                h.ylabel = ylabel('Y Label');
            end
            if ~h.params.suppress_title
                h.title = title('My Calculator Results');
            end

            box off;
        end
```

## Usage Examples

### Running a Calculator

```matlab
% Create session
session = ndi.session('my_experiment');

% Create calculator
calc = ndi.calc.category.my_calculator(session);

% Option 1: Use default parameters
docs = calc.run('Replace');

% Option 2: Custom parameters
params = calc.default_search_for_input_parameters();
params.input_parameters.param1 = 0.002;
docs = calc.run('Replace', params);

% Option 3: Search for specific inputs
params.query.query = params.query.query & ...
    ndi.query('element.reference', 'exact_number', 1, '');
docs = calc.run('Replace', params);
```

### Querying Calculator Results

```matlab
% Find all calculator documents
q = ndi.query('', 'isa', 'my_calculator_calc', '');
docs = session.database_search(q);

% Find for specific element
q1 = ndi.query('', 'isa', 'my_calculator_calc', '');
q2 = ndi.query('', 'depends_on', 'element_id', element_doc_id);
docs = session.database_search(q1 & q2);

% Access results
doc = docs{1};
results = doc.document_properties.my_calculator_calc;
value1 = results.output_field1;
```

## Best Practices

### 1. Naming Conventions
- **Class file**: lowercase with underscores (e.g., `spike_shape.m`)
- **Document type**: class name + `_calc` (e.g., `spike_shape_calc`)
- **JSON file**: same as document type (e.g., `spike_shape_calc.json`)

### 2. Design Decisions
- **Granularity**: Create separate documents per epoch/trial if data may be added later
- **Dependencies**: Include all documents needed to reproduce the calculation
- **Parameters**: Store all configuration values in `input_parameters`
- **Output**: Store both raw results and derived statistics

### 3. Path Resolution
Always use dynamic path resolution in constructor:
```matlab
w = which('ndi.calc.category.my_calculator');
parparparpar = fileparts(fileparts(fileparts(fileparts(w))));
```

This ensures your calculator works regardless of installation location.

### 4. Query Construction
- Use `ndi.query()` for database searches
- Combine queries with `&` (AND) and `|` (OR)
- Common query types:
  - `'exact_string'` - Exact match
  - `'contains_string'` - Substring match
  - `'isa'` - Document type check
  - `'depends_on'` - Dependency check
  - `'exact_number'` - Numeric equality

### 5. Error Handling
- Always validate `input_parameters` and `depends_on` exist
- Check that queries return expected number of documents
- Provide informative error messages

### 6. Documentation
- Document all methods with clear help text
- Explain input parameters and their units
- Describe output fields and their meaning
- Include usage examples

## Testing

### Basic Test
```matlab
% Create test session
S = ndi.session.test('test_my_calculator');

% Create calculator and run
calc = ndi.calc.category.my_calculator(S);
docs = calc.run('Replace');

% Verify results
assert(~isempty(docs), 'No documents created');
assert(isfield(docs{1}.document_properties.my_calculator_calc, ...
    'output_field1'), 'Missing output field');
```

### Advanced Testing
For production calculators, implement:
- `generate_mock_docs()` - Create synthetic test data
- `compare_mock_docs()` - Validate results against expected output

See `contrast_tuning.m` lines 281-393 for examples.

## Common Patterns

### Multiple Dependencies
```json
"depends_on": [
    { "name": "element_id", "value": 0 },
    { "name": "stimulus_id", "value": 0 },
    { "name": "element_epoch_id", "value": 0 }
]
```

### Array Outputs
```json
"output_field": []
```
Initialize as empty array, populate in `calculate()`.

### Nested Structures
```matlab
output.results.tuning_curve.mean = [...];
output.results.tuning_curve.stderr = [...];
output.results.statistics.p_value = 0.05;
```

### Binary File Handling
```matlab
% In calculate():
fname = [session.path filesep 'ndiobjects' filesep doc_id '.bin'];
% ... write data to fname ...
doc = doc.add_file('mydata.bin', fname);

% In load():
myfile = session.database_openbinarydoc(doc, 'mydata.bin');
data = fread(myfile, ...);
session.database_closebinarydoc(myfile);
```

## Troubleshooting

### Calculator doesn't find inputs
- Check your `query` in `default_search_for_input_parameters()`
- Verify input documents exist: `session.database_search(query)`
- Check dependency names match JSON definition

### Documents not created
- Verify `calculate()` returns valid `ndi.document` object
- Check all dependencies are set with `set_dependency_value()`
- Ensure JSON definition matches document structure

### Path errors
- Use dynamic path resolution with `which()` and `fileparts()`
- Verify JSON file exists at specified path
- Check MATLAB path includes calculator directory

### Query syntax errors
- Use `ndi.query()` constructor, not raw strings
- Combine with `&` and `|`, not `&&` and `||`
- Field names are case-sensitive

## References

- **Examples**: See `+ndi/+calc/+vis/` in NDIcalc-vis-matlab
- **Base class**: `+ndi/calculator.m` in NDI-matlab
- **Tutorial**: `making_a_new_calculator.md` in NDIcalc-vis-matlab
- **Simple template**: `+ndi/+calc/+example/simple.m` in NDI-matlab

## Summary Checklist

When creating a new calculator:

- [ ] Plan inputs, parameters, outputs, and granularity
- [ ] Create JSON document definition in `ndi_common/database_documents/calc/`
- [ ] Create MATLAB class in `+ndi/+calc/+[category]/`
- [ ] Implement constructor with dynamic path resolution
- [ ] Implement `calculate()` method
- [ ] Implement `default_search_for_input_parameters()` method
- [ ] Add optional methods as needed (plot, load, etc.)
- [ ] Test with real or mock data
- [ ] Document all methods and parameters
- [ ] Verify calculator can be run with default parameters
