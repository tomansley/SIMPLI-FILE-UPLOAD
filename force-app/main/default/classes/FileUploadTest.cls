/**
 * @description       : 
 * @author            : tom.h.ansley@medtronic.com
 * @last modified on  : 12-10-2020
 * @last modified by  : tom.h.ansley@medtronic.com
 * Modifications Log 
 * Ver   Date         Author                       Modification
 * 1.0   12-10-2020   tom.h.ansley@medtronic.com   Initial Version
**/
@isTest
private class FileUploadTest {

    @testSetup
    private static void createSampleData()
    {
        
        Account acc = HelperTest.createAccount();
        
        File_Upload_Config__c fileUpload = HelperTest.createContactCreateFileUpload();

    }
    
    static testMethod void testBatchProcessing() 
    {

        //1. Get file upload
        File_Upload_Config__c fileUploadConfig = FileUploadHelper.getFileUploadConfig('Contact Create');
        
        //2. Create Salesforce file
        ContentVersion attach = new ContentVersion();
        attach.ContentLocation = 'S'; // S = Stored in Salesforce
        attach.PathOnClient = 'TestFileName.csv';
        attach.Title = 'TestFileName.csv';                 
        attach.VersionData  = Blob.valueOf('Customer Name,Contact Last Name,Contact First Name,Column Not Used for anything\nTest Account,Ansley,Tom,1\nTest Account,Shmo,Joe,2\nTest Account,Reynolds,Sean,r\Test Account,Flowers,Daisy,y');

        insert attach;
        
        //3.  Create and Process Job
        FileUploadTypeCSV fileUploadJob = (FileUploadTypeCSV) FileUploadHelper.processData(attach.Id, 'Contact Create');

        System.assertEquals(fileUploadJob.isChild, false);

        //create and process child job
        FileUploadTypeCSV childJob = (FileUploadTypeCSV) FileUploadHelper.instantiateChildFileUploadJob(fileUploadJob);

        System.assertEquals(childJob.isChild, true);

        childJob.execute(null, null);

        childJob.currentRow = 100;
        childJob.finish(null);

        String resultAttachId = childJob.resultAttachId;
        
        System.assertNotEquals(resultAttachId, null);

        ContentDocument contentDoc = [select Title from ContentDocument where LatestPublishedVersionId = :resultAttachId];
        System.assertEquals(contentDoc.Title, 'TestFileName.csv-RESULTS.txt');
    }

}