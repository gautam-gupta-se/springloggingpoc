package com.example.springlogingpoc;

import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
public class DemoController {

    @GetMapping(path = "/helloMessage")
    public String message(){
        log.info("this is message controller");
        return "Hello there";
    }


    @GetMapping
    public String defaultMessage(){
        log.info("this is default controller");
        return "Hello there";
    }
}
