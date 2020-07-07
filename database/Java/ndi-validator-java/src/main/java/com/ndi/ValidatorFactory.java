package com.ndi;

import org.everit.json.schema.FormatValidator;
import java.util.List;

public class ValidatorFactory {

    private ValidatorFactory(){}

    public static Validation build(){
        return new Everit();
    }

    public static Validation build(List<FormatValidator> validators) {
        return new Everit(validators);
    }
}
