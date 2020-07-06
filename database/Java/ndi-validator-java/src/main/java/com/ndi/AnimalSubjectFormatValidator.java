package com.ndi;

import org.everit.json.schema.FormatValidator;

import java.util.Optional;

public class AnimalSubjectFormatValidator implements FormatValidator {
    private String formatName;

    public AnimalSubjectFormatValidator(String formatName){
        this.formatName = formatName;
    }

    @Override
    public Optional<String> validate(String subject) {
        System.out.println("");
        return Optional.empty();
    }

    @Override
    public String formatName() {
        return this.formatName;
    }
}
