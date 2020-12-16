/**
 * @description       : 
 * @author            : tom.h.ansley@medtronic.com
 * @last modified on  : 12-10-2020
 * @last modified by  : tom.h.ansley@medtronic.com
 * Modifications Log 
 * Ver   Date         Author                       Modification
 * 1.0   12-10-2020   tom.h.ansley@medtronic.com   Initial Version
**/
public with sharing class HelperTest {

    public static Account createAccount(Boolean insertRecord)
    {
        Account acct = new Account();
        acct.name = 'Test Account';
        
        if (insertRecord)
            Database.insert(acct);

        return acct ;    
    }
    
    // Creating a  Account record 
    public static Account createAccount()
    {
        return createAccount(true);
    }

    public static File_Upload_Config__c createContactCreateFileUpload()
    {
        File_Upload_Config__c fileUpload = new File_Upload_Config__c();
        fileUpload.Name = 'Contact Create';
        fileUpload.API_Object_Name__c = 'Contact';
        fileUpload.Batch_Size__c = 2;
        fileUpload.Display_Data_Before_Processing__c = true;
        fileUpload.Validation_Display_Rows__c = '5';
        fileUpload.DML_Operation__c = 'Insert';
        fileUpload.Ignored_Errors__c = 'Ignored Errors Test';
        
        insert fileUpload;

        List<File_Upload_Config_Field__c> fields = new List<File_Upload_Config_Field__c>();

        File_Upload_Config_Field__c field = new File_Upload_Config_Field__c();
        field.Name = 'Customer Name';
        field.API_Field_Name__c = 'AccountId';
        field.Foreign_Key_API_Field_Name__c = 'Account.Name';
        field.File_Upload_Config__c = fileUpload.Id;

        fields.add(field);

        field = new File_Upload_Config_Field__c();
        field.Name = 'Contact Last Name';
        field.API_Field_Name__c = 'LastName';
        field.Foreign_Key_API_Field_Name__c = '';
        field.File_Upload_Config__c = fileUpload.Id;

        fields.add(field);

        field = new File_Upload_Config_Field__c();
        field.Name = 'Contact First Name';
        field.API_Field_Name__c = 'FirstName';
        field.Foreign_Key_API_Field_Name__c = '';
        field.File_Upload_Config__c = fileUpload.Id;

        fields.add(field);

        insert fields;
        
        return fileUpload;

    }

}