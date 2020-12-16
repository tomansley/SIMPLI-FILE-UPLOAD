/**
 * @description       : 
 * @author            : tom.h.ansley@medtronic.com
 * @last modified on  : 12-15-2020
 * @last modified by  : tom.h.ansley@medtronic.com
 * Modifications Log 
 * Ver   Date         Author                       Modification
 * 1.0   12-10-2020   tom.h.ansley@medtronic.com   Initial Version
**/
public abstract with sharing class FileUploadTypeAbstract implements Database.Stateful, Database.AllowsCallouts, Database.Batchable<SObject> {

        public String classType                       {get; set;} //a class name as a string for easy debugging and output.
        public String fileUploadConfigName            {get; set;} //the config name that should be used to identify how to process the file.
        public String fileName                        {get; set;} //the file name of the file being processed.
        public File_Upload_Config__c fileUploadConfig {get; set;} //the file upload config SObject based on the provided config name.
        public FileUploadTypeAbstract nextBatchJob    {get; set;} //holds the next batch job that is to be run by the concrete class.
        public File_Upload_Job__c job                 {get; set;} //holds the job status and statistics which can be viewed by the user.
        public String sourceAttachId                  {get; set;} //the attachment Id which is used to find the attachment holding the data to be processed.
        public String resultAttachId                  {get; set;} //the attachment Id which is used to find the attachment holding the results of processing.
        public ContentVersion sourceAttach            {get; set;} //holds the attachment with data to be processed.
        public ContentVersion  resultAttach           {get; set;} //holds the attachment with results data
        public Integer batchNum                       {get; set;} //indicates what batch number we are processing.
        public String fileResults                     {get; set;} //the accumulated results of processing the file for this batch.
        public Integer totalSuccess                   {get; set;} //the accumulated result of all successful records processed.
        public Integer totalFailure                   {get; set;} //the accumulated result of all failed records processed.
        public Integer totalIgnored                   {get; set;} //the accumulated result of all records that failed processing but were ignored.
        public Integer totalRows                      {get; set;} //total lines processed.
        public Integer currentRow                     {get; set;} //holds the currently processed row.
        public Boolean isChild                        {get; set;} //indicates whether this is the first time a batch is running (false) or not (true).
        
        /*
         * Constructor which initializes basic values. This constructor is always called when using the FileUploadHelper
         * to instantiate an object of the FileUploadTypeAbstract variety.
         */
        public FileUploadTypeAbstract()
        {
            this.batchNum     = 1;
            this.totalRows    = 0;
            this.totalSuccess = 0;
            this.totalIgnored = 0;
            this.totalFailure = 0;
            this.currentRow   = 1;
            this.fileResults  = '';
            this.isChild      = false;
        }
    
        /*
         * Method which holds all processing logic. This method gets called after the initialize() method has been called.
         */
        public abstract void process();
        
        /*
         * Method which is called by FileUploadHelper whenever a new concrete FileUploadTypeAbstract class is instantiated. This method
         * will typically always be called AFTER the copyDataFromParent method is called. This allows all data to be copied from parent
         * to child before initializing.
         */
        public abstract void initialize();
        
        /*
         * Method which indicates the string that should be added to the result file at the TOP of the file if the header is to be added.
         */
        public abstract void setFileResultHeader();
        
        /*
         * Method which indicates the string that should be added to the result file at the BOTTOM of the file if the footer is to be added.
         */
        public abstract void setFileResultFooter();
    
        /*
         * Method which returns (in matrix form) a set of data which will typically be used by the user to validate that the data being
         * processed looks to be correct. This method can also perform other validations to ensure that the attached file is valid.
         */
        public abstract List<List<String>> getValidateDataFromFile();
        
        /*
         * Method which allows the implementor of a concrete FileUploadTypeAbstract class to copy implementation specific data from parent to child
         * whenever a new class is instantiated. Note that this method will only be called if concrete classes are created using the FileUploadHelper.
         */
        public abstract void copyDataFromParent(FileUploadTypeAbstract fileUploadJob);
    
        /* IMPLEMENTS DATABASE.BATCHABLE INTERFACE */
        public Database.QueryLocator start(Database.BatchableContext BC) 
        {
            return Database.getQueryLocator('SELECT Id FROM User LIMIT 1'); //Need a query here but the data is not used at all and the query does not count towards governor limits.
        }
    
        /* IMPLEMENTS DATABASE.BATCHABLE INTERFACE */
        public void execute(Database.BatchableContext BC, List<sObject> scope) {
            System.debug('PROCESSING JOB - ' + classType + ', ATTACHMENT ID - ' + sourceAttachId + ', FILE UPLOAD CONFIG NAME - ' + fileUploadConfigName);
            try 
            {
                this.process();
            } catch(Exception e) {
                
                try {
    
                    //log the exception to the user logs
                    System.debug(LoggingLevel.ERROR, 'Exception thrown by ' + classType + ' - ' + e.getMessage());
                    System.debug(LoggingLevel.ERROR, 'Stacktrace - ' + e.getStackTraceString());
                    
                    fileResults += '\nFATAL ERROR WHILE PROCESSING DATA ---\n\n';
                    fileResults += 'MESSAGE     - ' + e.getMessage() + '\n\n';
                    fileResults += 'STACK TRACE - ' + e.getStackTraceString() + '\n\n';
                    
                    updateResultAttachment();
                    
                    job.Status__c               = 'Error';
                    job.Processing_End_Time__c  = System.now();
                    job.Result_Attachment_Id__c = resultAttachId;
                    update job;
    
                    
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR, e.getMessage());
                    System.debug(LoggingLevel.ERROR, e.getStackTraceString());
                } finally {
                    
                }
                
            }
        }
    
        /* IMPLEMENTS DATABASE.BATCHABLE INTERFACE */ 
        public void finish(Database.BatchableContext BC) 
        {
            
            System.debug('AT FINISHED');
            System.debug('CURRENT ROW - ' + currentRow);
            System.debug('TOTAL ROWS - ' + totalRows);
            
            //if we have more rows to process then create another batch job.
            if (currentRow < totalRows)
            {
                updateResultAttachment();
    
                if (job.Status__c == 'Processing')
                {
                //instantiate a new file upload batch job object using that type
                FileUploadTypeAbstract batchJob = FileUploadHelper.instantiateChildFileUploadJob(this);
                
                // enqueue the job for processing
                ID jobId = Database.executeBatch(batchJob);
                    job.Apex_Batch_Id__c        = String.valueOf(jobId);
                }
            
                job.Current_Batch_Number__c  = batchNum;
                job.Total_Failed_Rows__c     = totalFailure;
                job.Total_Success_Rows__c    = totalSuccess;
                job.Total_Rows_Processing__c = totalRows;
                job.Total_Ignored_Rows__c    = totalIgnored;
                job.Total_Processed_Rows__c  = totalFailure + totalSuccess + totalIgnored;
                job.Result_Attachment_Id__c  = resultAttachId;
    
                update job;
            
    
            //else write out the results.
            } else {
                
                if (fileUploadConfig.Provide_Result_File_Footer__c)
                    setFileResultFooter();
    
                updateResultAttachment();
    
                job.Current_Batch_Number__c = 0;
                job.Total_Failed_Rows__c    = totalFailure;
                job.Total_Success_Rows__c   = totalSuccess;
                job.Total_Ignored_Rows__c   = totalIgnored;
                job.Total_Rows_Processing__c   = 0;
                job.Total_Processed_Rows__c = totalFailure + totalSuccess + totalIgnored;
                job.Status__c               = 'Completed';
                job.Processing_End_Time__c  = System.now();
                job.Result_Attachment_Id__c = resultAttachId;
    
                update job;
            }
    
        }
        
        private void updateResultAttachment()
        {
            ContentVersion attach = null;
            
            //if we already have an associated salesforce file(earlier was attachment)
            if (resultAttachId != null)
            {
                //existing attachment
                ContentVersion attachment = [SELECT Id,
                                                    VersionData,
                                                    ContentDocumentId 
                                             FROM ContentVersion 
                                             WHERE Id = :resultAttachId];

                attach = new ContentVersion();
                String attachBody        = attachment.VersionData.toString();
                attachBody               = attachBody + fileResults;
                attach.VersionData       = Blob.valueOf(attachBody);
                attach.ContentDocumentId = attachment.ContentDocumentId;
                
            //if we are creating new salesforce file
            } else {
                
                attach = new ContentVersion();
                attach.ContentLocation = 'S'; // S = Stored in Salesforce
                attach.PathOnClient    = fileName + '-RESULTS.txt';
                attach.Title           = fileName + '-RESULTS.txt';
                attach.VersionData     = Blob.valueOf(fileResults);
            }
            
            System.debug(LoggingLevel.DEBUG, 'FILE RESULT - ' + fileResults);
            attach.PathOnClient = string.valueof(batchNum);
            insert attach;
    
            //Retrieve the content document Id from the inserted content document 
            attach = [select Id,ContentDocumentId,VersionData,Title,PathOnClient from ContentVersion where Id = :attach.Id];
              
            resultAttachId = [SELECT LatestPublishedVersionId 
                              FROM ContentDocument
                              WHERE Id = :attach.ContentDocumentId][0].LatestPublishedVersionId; //for file download
            
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();

            //Create ContentDocumentLink record for the file upload config object
            List<ContentDocumentLink> cdls = [SELECT Id 
                                              FROM ContentDocumentLink
                                              WHERE LinkedEntityId = :fileUploadConfig.Id
                                                    AND ContentDocumentId = :attach.ContentDocumentId];
            if(cdls.isEmpty())
            {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.LinkedEntityId    = fileUploadConfig.Id;
                cdl.ContentDocumentId = attach.ContentDocumentId;
                cdl.ShareType         = 'V';
                links.add(cdl);
            }
            
            //Create ContentDocumentLink for file upload job object
            cdls = [SELECT Id 
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :job.Id
                        AND ContentDocumentId = :attach.ContentDocumentId];

            if(cdls.isEmpty())
            {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.LinkedEntityId    = job.Id;
                cdl.ContentDocumentId = attach.ContentDocumentId;
                cdl.ShareType         = 'V';
                links.add(cdl);
            }

            insert links;
        }
        
    }