# Tutorial 7: Writing your own apps

## 7.2: Writing a simple calculation

Usually, end user scientists do not want to develop an app, but instead want to develop a consistent and tested
method for performing a calculation. We have developed an NDI mini-app class called [ndi.calculation](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/calculation.m/) for that purpose.

[ndi.calculation](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/calculation.m/) objects require very little in the way of construction:

1. A single document type that they produce
2. A function that creates the document type from input parameters
3. A function that searches for all possible inputs to the function
4. A short documentation for the document type

Once we have these ingredients, we have an [ndi.calculation](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/calculation.m/) that can be run as simply as

#### Code block 7.2.0.1 (Don't type into the Matlab command line until the end, at the bottom.)

```matlab
c = ndi.calc.example.simple(S); % where S is an ndi.session
c.run('NoAction'); % will run but will not replace existing calculations with the same parameters
```

We will cover the develop of a very simple calculation: [ndi.calc.example.simple](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bcalc/%2Bexample/simple.m/)

### 7.2.1 ndi.calc.example.simple

Our simple example will be very simple and silly, but illustrates the process of creating an [ndi.calculation](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/calculation.m/).

We will create a calculation that creates a document for each 'ndi.probe' object that simply has a field called
'answer' that is equal to 5. It is not useful for anything other than demonstrating the steps necessary to create a calculation, but you
can use it to design calculations that perform useful analysis and save the results to the database.  Let's design this very simple calculation.

### 7.2.2 Designing the database document

Let's look at the design of the database document definition for [ndi.calc.example.simple](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bcalc/%2Bexample/simple.m/), which we placed in `ndi_common/database_documents/apps/calculations/simple_calc.json`:

#### Code block 7.2.2.1: Database documentation definition for `simple_calc` (Do not type into Matlab command line)

```json
{
	"document_class": {
		"definition":						"$NDIDOCUMENTPATH\/apps\/calculations\/simple_calc.json",
		"validation":						"$NDISCHEMAPATH\/apps\/calculations\/simple_calc_schema.json",
		"class_name":						"ndi_calculation_simple_simple_calc",
		"property_list_name":					"simple",
		"class_version":					1,
		"superclasses": [
			{ "definition":					"$NDIDOCUMENTPATH\/ndi_document.json" },
			{ "definition":					"$NDIDOCUMENTPATH\/ndi_document_app.json" }
		]
	},
	"depends_on": [
		{	"name": "probe_id",
			"value": 0 
		}
	],
	"simple": {
		"input_parameters": {
			"answer":					5
		},
		"answer":						0
	}
}
```

The first block, `document_class`, is necessary for any document defined in NDI. It includes the location of the definition file, the location
of a file for validation (we will cover later), the class name, the `property_list_name` which tells NDI what the structure that has the main
results (later on in the file), the class version (which is 1), and the superclasses of the document. The line that includes the definition for `ndi_document` indicates that simple calc documents have all the fields of an ndi.document, which must be true for any NDI document. In this case, this document also is a subclass of ndi_document_app, which allows information about the application that created the calculation to be recorded.

In the next block, there is a set of "depends_on" fields, which indicate which dependencies are required for this document type. Here, we make the
document that describes each probe as a dependency, so that the "answer" can be attributed to the probe by any program or user that examines the
document. 

Finally, we have the data that is associated with our calculation in the structure `simple`. Because it is a document for an NDI calculation, it
must contain a structure "input_parameters" that describe how the calculator should search for its inputs, if there are such parameters (or the
structure can be empty if there are none). Last, we have the entries of the structure that contain the output of our calculation, which in this
case is a simple field "answer".

### 7.2.3 Writing the calculation object code

We are now ready to write the calculation code. This is the code that we will call to make our calculation.  The code has four functions. 

The first function that is needed is the *creator*. This function has the same name as the class and does any building that is necessary
to make the calculation function. Because [ndi.calculation](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/calculation.m/) is a subclass of [ndi.app](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/app.m/) and [ndi.appdoc](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bapp/appdoc.m/), most of our initialization is handled for us.
Our code object `simple` is a subclass of [ndi.calculation](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/calculation.m/), which has a handy routine that can be used to tell the object what document it should
make. 

Here is a snapshot of the creator function. Note that this code snippet can't stand on its own; we will give the full object code at the bottom.

#### Code block 7.2.3.1: Creator for [ndi.calc.example.simple](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bcalc/%2Bexample/simple.m/) (do not type into Matlab command line):

```matlab
		function simple_obj = simple(session)
			% SIMPLE - a simple demonstration of an ndi.calculation object
			%
			% SIMPLE_OBJ = SIMPLE(SESSION)
			%
			% Creates a SIMPLE ndi.calculation object
			%
				ndi.globals;
				simple_obj = simple_obj@ndi.calculation(session,'simple_calc',...
					fullfile(ndi_globals.path.documentpath,'apps','calculations','simple_calc.json'));
		end; % simple()
```

The second function is the `calculate` function that actually performs the calculation, given inputs. The `parameters` input to `calculate` needs
to have the same fields as the structure that holds the central data of the document; in this case, it needs to be a structure with the fields
of `simple` in the document above (`input_parameters`, `depends_on`,`simple`).

#### Code block 7.2.3.2: `calculate` function for [ndi.calc.example.simple](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bcalc/%2Bexample/simple.m/) (do not type into Matlab command line):

```matlab
	function doc = calculate(ndi_calculation_obj, parameters)
		% CALCULATE - perform the calculation for ndi.calc.example.simple
		%
		% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
		%
		% Creates a simple_calc document given input parameters.
		%
		% The document that is created simple has an 'answer' that is given
		% by the input parameters.
			% check inputs
			if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters.''']); end;
			if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on.''']); end;
			
			simple = parameters;
			simple.answer = parameters.input_parameters.answer;
			doc = ndi.document(ndi_calculation_obj.doc_document_types{1},'simple',simple);
			for i=1:numel(parameters.depends_on),
				doc = doc.set_dependency_value(parameters.depends_on(i).name,parameters.depends_on(i).value);
			end;
	end; % calculate
```

The function simply sets the `answer` field to the `answer` field of the input_parameters, and then sets the dependency that was input.

You'll notice that the `calculate` function performs the calculation with its inputs fully set up. Some other function has set up the inputs 
correctly so that the function can perform its calculation. The user can do this manually, but the best practice is to have the ndi.calculation
object search for all of the possible inputs on which it can perform the calculation. This allows the calculation to be called simply by the `run`
function. 

#### Code block 7.2.3.3: `default_search_for_input_parameters` function for [ndi.calc.example.simple](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bcalc/%2Bexample/simple.m/) (do not type into Matlab command line):

```matlab
		function parameters = default_search_for_input_parameters(ndi_calculation_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculation.
			%
				parameters.input_parameters = struct('answer',5);
				parameters.depends_on = vlt.data.emptystruct('name','value');
				parameters.query = struct('name','probe_id','query',ndi.query('element.ndi_element_class','contains_string','ndi.probe',''));
		end; % default_search_for_input_parameters
```

The last function that we need is a documentation function that simply returns its own help as a text string. This allows other programs to
see the documentation for the calculation, and gives programmers/users a consistent place in the help to look for a description of what the calculation does.

#### Code block 7.2.3.4 `doc_about` for [ndi.calc.example.simple](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bcalc/%2Bexample/simple.m/) (do not type into Matlab command line):

```matlab
		function doc_about(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: SIMPLE_CALC
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | SIMPLE_CALC -- ABOUT |
			%   ------------------------
			%
			%   SIMPLE_CALC is a demonstration document. It simply produces the 'answer' that
			%   is provided in the input parameters. Each SIMPLE_CALC document 'depends_on' an
			%   NDI daq system.
			%
			%   Definition: apps/simple_calc.json
			%
				eval(['help ndi.calc.example.simple.doc_about']);
		end; %doc_about()
```

Putting it all together, we can look at the entire calculation:

#### Code block 7.2.3.5: Full object code for [ndi.calc.example.simple](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bcalc/%2Bexample/simple.m/):

```matlab
classdef simple < ndi.calculation

	methods

		function simple_obj = simple(session)
			% SIMPLE - a simple demonstration of an ndi.calculation object
			%
			% SIMPLE_OBJ = SIMPLE(SESSION)
			%
			% Creates a SIMPLE ndi.calculation object
			%
				ndi.globals;
				simple_obj = simple_obj@ndi.calculation(session,'simple_calc',...
					fullfile(ndi_globals.path.documentpath,'apps','calculations','simple_calc.json'));
		end; % simple()

		function doc = calculate(ndi_calculation_obj, parameters)
			% CALCULATE - perform the calculation for ndi.calc.example.simple
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Creates a simple_calc document given input parameters.
			%
			% The document that is created simple has an 'answer' that is given
			% by the input parameters.
				% check inputs
				if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters.''']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on.''']); end;
				
				simple = parameters;
				simple.answer = parameters.input_parameters.answer;
				doc = ndi.document(ndi_calculation_obj.doc_document_types{1},'simple',simple);
				for i=1:numel(parameters.depends_on),
					doc = doc.set_dependency_value(parameters.depends_on(i).name,parameters.depends_on(i).value);
				end;
		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculation_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculation.
			%
				parameters.input_parameters = struct('answer',5);
				parameters.depends_on = vlt.data.emptystruct('name','value');
				parameters.query = struct('name','probe_id','query',ndi.query('element.ndi_element_class','contains_string','ndi.probe',''));
		end; % default_search_for_input_parameters

		function doc_about(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: SIMPLE_CALC
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | SIMPLE_CALC -- ABOUT |
			%   ------------------------
			%
			%   SIMPLE_CALC is a demonstration document. It simply produces the 'answer' that
			%   is provided in the input parameters. Each SIMPLE_CALC document 'depends_on' an
			%   NDI probe.
			%
			%   Definition: apps/simple_calc.json
			%
				eval(['help ndi.calc.example.simple.doc_about']);
		end; %doc_about()
	end; % methods()
			
end % simple

```

### 7.3.1 Running the calculation

Let's open our tree shrew experiment from Tutorials 2.1-2.5 to run the calculation.

#### Code block 7.3.1.1. Opening the tree shrew experiment (type into the Matlab command line).
```matlab
dirname = [userpath filesep 'Documents' filesep 'NDI' filesep 'ts_exper2']; % change this if you put the example somewhere else
ref = 'ts_exper2';
S = ndi.session.dir(ref,dirname);
```

Now we can run the calculation, as in the beginning of the tutorial. We can run the calculation in one of two modes. 

In the first mode, we can run the calculation on all possible inputs. 

#### Code block 7.3.1.2. Running the calculation, asking the program to find all possible inputs (type into the Matlab command line).
```matlab
c = ndi.calc.example.simple(S);
d = c.run('NoAction'); % will run but will not replace existing calculations with the same parameters
```

Now let's search for the documents we just created, even though we had them returned in `d`. We will inspect the output.

#### Code block 7.3.1.3. Searching for the calculations we made (type into Matlab command line).

```matlab
D = S.database_search(ndi.query('','isa','simple_calc',''));
D{1}.document_properties.simple, % should be struct with field 'answer' == 5
D{1}.document_properties.depends_on  % should have name of 'probe_id'
```

The other way to call a calculation is to use a very targeted set of parameters. If you want to perform your calculation only on specific items, such in the case of [ndi.calc.example.simple](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/%2Bcalc/%2Bexample/simple.m/),
a specific probe or probes, then you can do that, too, by specifying the specific inputs that you want to search for. 

#### Code block 7.3.1.4 Running the calculation, asking the program to find a specific input to the calculation (type into the Matlab command line).

```matlab
p = S.getprobes('type','n-trode');
disp(['Probe {1} properties are as follows:']);
p{1}, % look at the probe properties
input_p.input_parameters.answer = 5;
input_p.depends_on = struct('name','probe_id','value',p{1}.id());
d2 = c.run('Replace',input_p); % let's replace it
disp(['Document properties:']);
d2{1}.document_properties.simple, % should be struct with field 'answer' == 5
d2{1}.document_properties.depends_on  % should have name of 'probe_id' and p{1}'s probe id
```

One can use some additional queries to find specific or parameterized documents to use as inputs for a calculation. See `help ndi.calculation.search_for_input_parameters` or look at the [ndi.calculation](https://vh-lab.github.io/NDI-matlab/reference/%2Bndi/calculation.m/) help page.

### 7.1.6 Discussion/Feedback

This concludes our tutorial on writing a simple NDI calculation.

Post [comments, bugs, questions, or discuss](https://github.com/VH-Lab/NDI-matlab/issues/199).
