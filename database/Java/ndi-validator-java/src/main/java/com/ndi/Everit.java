package com.ndi;

import org.everit.json.schema.FormatValidator;
import org.everit.json.schema.Schema;
import org.everit.json.schema.ValidationException;
import org.everit.json.schema.loader.SchemaLoader;
import org.json.JSONObject;

import java.util.List;
import java.util.HashMap;

/**
 * Json validation implementation based off of com.ndi.Everit's json-schema validator
 * implementation: 'https://github.com/everit-org/json-schema', which follows the
 * Draft v7 specification: "https://tools.ietf.org/html/draft-handrews-json-schema-validation-00"
 */
public class Everit implements Validation {
    private final List<FormatValidator> validators;

    public Everit(List<FormatValidator> validators){
        this.validators = validators;
    }

    public Everit(){
        this.validators = null;
    }

    @Override
    public HashMap<String, String> performValidation(JSONObject input, JSONObject schema) {
        HashMap<String, String> output = new HashMap<>();
        SchemaLoader.SchemaLoaderBuilder loader = SchemaLoader.builder()
                .draftV7Support()
                .schemaJson(schema);
        System.out.println(this.validators);
        if (this.validators != null){
            for (FormatValidator validator : validators){
                loader.addFormatValidator(validator);
            }
        }
        Schema validation = loader.build().load().build();
        try{
            validation.validate(input);
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
        return output;
    }
}
