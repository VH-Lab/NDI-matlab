package com.ndi;

public class ValidatorFactory {

    private ValidatorFactory(){}

    public static Validation build(){
        return new Everit();
    }
}
