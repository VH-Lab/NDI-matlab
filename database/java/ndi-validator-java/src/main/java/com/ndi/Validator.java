package com.ndi;

import org.everit.json.schema.FormatValidator;
import org.everit.json.schema.Schema;
import org.everit.json.schema.ValidationException;
import org.everit.json.schema.loader.SchemaLoader;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.HashMap;

/**
 * Json validation implementation based off of com.ndi.Everit's json-schema validator
 * implementation: 'https://github.com/everit-org/json-schema', which follows the
 * Draft v7 specification: "https://tools.ietf.org/html/draft-handrews-json-schema-validation-00"
 */
public class Validator implements Validatable {
    private List<FormatValidator> validators;
    private final JSONObject document;
    private final JSONObject schema;
    private HashMap<String, String> report;

    public Validator(String document, String schema){
        this.document = new JSONObject(document);
        this.schema = new JSONObject(schema);
    }

    public Validator(JSONObject document, JSONObject schema){
        this.document = document;
        this.schema = schema;
    }

    public Validator addValidators (List<FormatValidator> validators){
        this.validators = validators;
        return this;
    }

    public Validator addValidator(FormatValidator validator){
        if (this.validators == null){
            this.validators = new ArrayList<>(Collections.singletonList(validator));
        }
        else{
            this.validators.add(validator);
        }
        return this;
    }

    /**
     * get a report detailing the error message of the validation
     *
     * @return a key-value pairs, where the key represents the
     * JSON key that has the wrong type, and the value represents
     * a string detailing the error message. If the HashMap is empty,
     * then it means the json document is valid
     */
    @Override
    public HashMap<String, String> getReport() {
        if (this.report == null){
            return this.performValidation();
        }
        else{
            return this.getReport();
        }
    }

    /**
     * Perform JSON Validation using org.everit JSON validator
     *
     * @return a key-value pairs, where the key represents the
     *         JSON key that has the wrong type, and the value represents
     *         a string detailing the error message. If the HashMap is empty,
     *         then it means the json document is valid
     */
    @Override
    public HashMap<String, String> performValidation() {
        HashMap<String, String> output = new HashMap<>();
        SchemaLoader.SchemaLoaderBuilder loader = SchemaLoader.builder()
                .draftV7Support()
                .schemaJson(schema);
        if (this.validators != null){
            for (FormatValidator validator : validators){
                loader.addFormatValidator(validator);
            }
        }
        Schema validation = loader.build().load().build();
        try{
            validation.validate(document);
            return output;
        }
        catch(ValidationException e){
            List<ValidationException> exceptionList = e.getCausingExceptions();
            if (exceptionList.isEmpty()){
                output.put(e.getPointerToViolation(), e.getMessage());
                return output;
            }
            for (ValidationException individual : exceptionList){
                output.put(individual.getPointerToViolation(), individual.getMessage());
            }
        }
        this.report = output;
        return output;
    }
}