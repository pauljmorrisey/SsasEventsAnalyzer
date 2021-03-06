﻿
DECLARE @StartQueryTrace_JobName VARCHAR(128) = N'$(StartQueryTrace_JobName)';
DECLARE @StartQueryTrace_JobId BINARY(16);
DECLARE @StartQueryTrace_cmd VARCHAR(2048);

SELECT	@StartQueryTrace_JobId = job_id
FROM	msdb.dbo.sysjobs
WHERE	name = @StartQueryTrace_JobName
;

IF (@StartQueryTrace_JobId IS NOT NULL)
BEGIN;
	PRINT N'Delete Existing Job: $(StartQueryTrace_JobName)';
	EXEC msdb.dbo.sp_delete_job 
		@job_id=@StartQueryTrace_JobId, 
		@delete_unused_schedule=1
	;
END
;



/* Create Job */
PRINT N'Creating Job: $(StartQueryTrace_JobName)';
SET @StartQueryTrace_JobId = NULL;
EXEC msdb.dbo.sp_add_job 
		@job_name=@StartQueryTrace_JobName, 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Starts SSAS xEvent trace collecting query data.', 
		--@owner_login_name=N'sa', 
		@job_id = @StartQueryTrace_JobId OUTPUT
;
/* Build TraceCollection cmdExec command */
PRINT N'Building : (Step01) $(StartQueryTrace_JobName)';
SET @StartQueryTrace_cmd = N'';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'<Create xmlns="http://schemas.microsoft.com/analysisservices/2003/engine"> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'  <ObjectDefinition> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'    <Trace> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'      <AutoRestart>true</AutoRestart> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'      <ID>TraceQuery</ID> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'      <Name>TraceQuery</Name> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'      <XEvent xmlns="http://schemas.microsoft.com/analysisservices/2011/engine/300/300"> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'        <event_session name="TraceQuery" dispatchLatency="0" maxEventSize="0" maxMemory="4" memoryPartition="none" eventRetentionMode="AllowSingleEventLoss" trackCausality="true" xmlns="http://schemas.microsoft.com/analysisservices/2003/engine"> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'          <event package="AS" name="QueryEnd" /> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'          <target package="package0" name="event_file"> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'            <parameter name="filename" value="$(xevent_trace_dir)TraceQuery.xel" /> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'            <parameter name="max_file_size" value="4096" /> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'          </target> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'        </event_session> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'      </XEvent> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'    </Trace> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'  </ObjectDefinition> ';
SET @StartQueryTrace_cmd = @StartQueryTrace_cmd + N'</Create> ';

/* Create Job Steps */
PRINT N'Creating Job Step: (Step01) $(StartQueryTrace_JobName)';
EXEC msdb.dbo.sp_add_jobstep 
		@job_id=@StartQueryTrace_JobId, 
		@step_name=N'(Step01) $(StartQueryTrace_JobName)', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, 
		@subsystem=N'ANALYSISCOMMAND', 
		@command=@StartQueryTrace_cmd,
		@server=N'$(ssas_instance)',  
		@flags=0
;
EXEC msdb.dbo.sp_update_job 
		@job_id = @StartQueryTrace_JobId, 
		@start_step_id = 1
;
EXEC msdb.dbo.sp_add_jobserver 
		@job_id = @StartQueryTrace_JobId, 
		@server_name = N'(local)'
;