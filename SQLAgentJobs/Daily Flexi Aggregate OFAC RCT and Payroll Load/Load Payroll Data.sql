USE Sandbox

SET ANSI_NULLS, QUOTED_IDENTIFIER ON;

if datename(WEEKDAY, GetDate()) = 'Wednesday'

begin



	declare @httpMethod	nvarchar(10) 
	declare @URL		nvarchar(200)
	declare @Headers	nvarchar(200)
	declare @JsonBody	nvarchar(max)
	declare @Username	nvarchar(50)
	declare @Password	nvarchar(50)
	declare @PeoId		nvarchar(50)

	set @httpMethod = 'POST'
	-- MH 6/28/2022 - To move sessionid to header
	--set @URL		= 'https://api.prismhr.com/api-1.25/services/rest/login/createPeoSession'
	set @URL		= 'https://api.prismhr.com/api-1.29/services/rest/login/createPeoSession'
	set @Headers	= '[{ "Name": "Content-Type", "Value" :"application/x-www-form-urlencoded" }]'


	--  Get the Account Credentials to set @JsonBody

	--  Open Encryption Key

	OPEN SYMMETRIC KEY WebserviceAPIPassword_Key11  
	   DECRYPTION BY CERTIFICATE WebserviceAPIPassword;  

	--  Once Encryption Key is open, now you can decrypt the password

	select @Username	= AccountName,
		   @Password	= CONVERT(varchar, DecryptByKey(Pwd_Encrypted)),
		   @PeoId		= CredID1
	from Sandbox.dbo.WebserviceAPICreds
	where ServiceName = 'PrismHR'
	  and Environment = 'PROD'



	set @JsonBody	= 'username='  + @Username + 
					  '&password=' + @Password +
					  '&peoId='	   +  @PeoId


	--  Step 1 - Get sessionId

	/* OLD 9/6/2022

	Declare @ts as table
	(
		Json_Result  NVARCHAR(MAX),
		ContentType  VARCHAR(100),
		ServerName   VARCHAR(100),
		Statuscode   VARCHAR(100),
		Description  VARCHAR(100),
		Json_Headers NVARCHAR(MAX)
	)

	DECLARE @i AS INT 
 
	INSERT INTO @ts
	EXECUTE @i =  [Sandbox].[dbo].[APICaller_Web_Extended] 
				   @httpMethod
				  ,@URL
				  ,@Headers
				  ,@JsonBody

	-- SELECT * FROM @ts

	DECLARE @sessionId	nvarchar(100)
 
	 SELECT 
			@sessionId = [name]	
	 FROM (
				SELECT Context = Json_Result 
				  from @ts
			)tb
		OUTER APPLY OPENJSON  (context)  
	  WITH
		( [name]		VARCHAR(100) '$.sessionId' );

	*/
	--  NEW  9/6/2022

	declare @CurlCommand		nvarchar(max)
	DECLARE @ResponseHeader	as table(rownum int identity(1, 1), ResponseHeader nvarchar(max))
	DECLARE @sessionId	nvarchar(100)



	set @CurlCommand = N'EXEC master..xp_cmdshell ''curl -s -o /dev/null -D - POST "' + 
												   @URL +
												   '" -H "Content-Type: application/x-www-form-urlencoded" -d "' + 
												   @JsonBody + 
												   '"'''


	--PRINT @CurlCommand
	
	SET TEXTSIZE 2147483647
	insert into @ResponseHeader
	EXEC sp_executesql @CurlCommand

	--select * from @ResponseHeader

	/*

	SELECT ResponseHeader 
	from @ResponseHeader
	where ISJSON(ResponseHeader) = 1

	*/

	 SELECT 
			@sessionId = max([name])  -- in case they add another Response Header that is well-formed JSON
	 FROM (
				SELECT Context = ResponseHeader 
				  from @ResponseHeader
				--  where rownum = 6
				  where ISJSON(ResponseHeader) = 1
			)tb
		OUTER APPLY OPENJSON  (context)  
	  WITH
		( [name]		VARCHAR(100) '$.sessionId' );





--	 select @sessionId



	--  Step 2 - Get Batches to Load



	DECLARE @payDateStart	nvarchar(10)
	DECLARE @payDateEnd		nvarchar(10)
	DECLARE @payDate		nvarchar(10)
	DECLARE @clientId		nvarchar(10)
	DECLARE @dateType		nvarchar(10)
	declare	@Options		nvarchar(100)
	-- MH 6/28/2022 - To move sessionid to header
	DECLARE @authHeader		NVARCHAR(64);
	DECLARE @contentType	NVARCHAR(64);
	DECLARE @postData		NVARCHAR(2000);
	DECLARE @token			INT;

	SET @payDateStart	= '2016-01-21'
	SET @payDateEnd		= convert(date, dateadd(m, 1, GetDate()))
	set @payDate		= '2016-01-21'
	set @clientId		= '104214'
	set @dateType		= 'PERIOD'

	-- MH 6/28/2022 - To move sessionid to header
	SET @authHeader = @sessionId
	SET @contentType = 'application/json';

	-- MH 6/28/2022 - To move sessionid to header
	--set @URL		= 'https://api.prismhr.com/api-1.25/services/rest/payroll/getBatchListByDate'  +
	set @URL		= 'https://api.prismhr.com/api-1.29/services/rest/payroll/getBatchListByDate'  +
					 '?endDate='		+ @payDateEnd +
					 '&startDate='		+ @payDateStart + 
					 '&clientId='		+ @clientId  +
					 '&dateType='		+ @dateType /* +
					 '&sessionId='		+ @sessionId */
	--Print @URL

	DECLARE @status NVARCHAR(32)
	DECLARE @statusText NVARCHAR(32);
	DECLARE @responseText as table(rownum int identity(1, 1), responseText nvarchar(max))
	DECLARE @res as Int


/*  OLD 9/7/2022

	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'SessionID', @authHeader;
	--PRINT @contentType
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);



	set @CurlCommand = N'EXEC master..xp_cmdshell ''curl -s -o /dev/null -D - POST "https://rdi-staging4.riskcontrol.expert/gramercy/api/authentication?Lang=en" -H "accept: application/json" -H "X-Version: 1.1" -H "Content-Type: application/json" -d "{\"Username\":\"GramercyIT\",\"Password\":\"29KW9i1Zl3Dw\"}"'''

*/

-- NEW 9/7/2022

	set @CurlCommand = N'EXEC master..xp_cmdshell ''curl -s -o /dev/null -w - POST "' + 
												   @URL +
												   '" -H "SessionId: ' + 
												   @sessionId +
												   '" -H "Content-Type: application/json"' +
												   ''''


--	PRINT @CurlCommand
	
	SET TEXTSIZE 2147483647
	insert into @responseText
	EXEC sp_executesql @CurlCommand




	DECLARE @ResponseJSON	nvarchar(max)

	/*
	SELECT @status, responseText FROM @responseText

	select @ResponseJSON = responseText
	from @responseText

	print @ResponseJSON

	select *
	from @responseText

	*/

	
	
	DECLARE @NextChunkedRow		int
	DECLARE @LastChunkedRow		int

	set @ResponseJSON = ''

	set @NextChunkedRow = 1
	set @LastChunkedRow = (select max(rownum)
						   from @ResponseText)

	while @NextChunkedRow <= @LastChunkedRow

	begin

		set @ResponseJSON = @ResponseJSON + (select ResponseText
									   from @ResponseText
									   where rownum = @NextChunkedRow)

		set @NextChunkedRow = @NextChunkedRow + 1

	end

--  Remove the starting and trailing dashes
	set @ResponseJSON = substring(@ResponseJSON, 2, len(@ResponseJSON) -2)

--	print @ResponseJSON

	

	--  Reload every time

	truncate table [Sandbox].[dbo].[PayrollBatches]

	insert into [Sandbox].[dbo].[PayrollBatches]
	values (@sessionId, @ResponseJSON, getdate())



	--  Step 3 - Get Payroll Vouchers for outstanding Batches by pay period start and end date


	/*
	DECLARE @payDateStart	nvarchar(10)
	DECLARE @payDateEnd		nvarchar(10)
	DECLARE @clientId		nvarchar(10)


	set @clientId		= '104214'

	*/

	set @Options	= 'EmployerContribution%20Retirement'

	create table #responseText (rownum int identity(1, 1), responseText nvarchar(max))

	DECLARE c1 CURSOR FOR
	select payPeriodStartDate, payPeriodEndDate, payDate
	from [Sandbox].[dbo].v_PayrollBatchesToLoad
	order by 1

	OPEN c1

	FETCH NEXT FROM c1 
	INTO @payDateStart, @payDateEnd, @payDate
  
	WHILE @@FETCH_STATUS = 0  
	BEGIN  

	-- MH 6/28/2022 - To move sessionid to header
	--        set @URL = 'https://api.prismhr.com/api-1.25/services/rest/payroll/getPayrollVouchers'  +
			set @URL = 'https://api.prismhr.com/api-1.29/services/rest/payroll/getPayrollVouchers'  +
	--  MH 9/2/2021 - getPayrollVouchers uses the payDate, not the payPeriodStartDate and payPeriodEndDate
						'?payDateEnd='		+ @payDate +
						'&payDateStart='	+ @payDate + 
						'&clientId='		+ @clientId  +
	-- MH 6/28/2022 - To move sessionid to header
	--					'&sessionId='		+ @sessionId +
						'&options='			+ @Options

/*  OLD  9/7/2022

			-- Open the connection.
			EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
			--Print @token
			IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

			-- Send the request.
			EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
			--set a custom header Authorization is the header key and VALUE is the value in the header
			--PRINT @authHeader
			--PRINT @res
			EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'SessionID', @authHeader;
			--PRINT @contentType
			--PRINT @res
			EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
			--PRINT @res
			EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

			-- Handle the response.
			EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
			EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
			SET TEXTSIZE 2147483647
			INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

			-- Show the response.
			--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
			--SELECT @status, responseText FROM @responseText

			-- Close the connection.
			EXEC @res = sp_OADestroy @token;
			IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

*/

-- NEW 9/7/2022
			
			set @CurlCommand = N'EXEC master..xp_cmdshell ''curl -s -o /dev/null -w - ' + 
														   ' -H "SessionId: ' + 
														   @sessionId +
														   '" -H "Content-Type: application/json" "' +
														   '" -H "Accept: application/json" "' +
														   @URL +
														   '"'''

--			PRINT @CurlCommand

			truncate table #responseText
	
			SET TEXTSIZE 2147483647
			insert into #responseText
			EXEC sp_executesql @CurlCommand

--			select *
--			from @ResponseText

			set @ResponseJSON = ''

			set @NextChunkedRow = 1
			set @LastChunkedRow = (select max(rownum)
								   from #responseText)

			while @NextChunkedRow <= @LastChunkedRow

			begin

				set @ResponseJSON = @ResponseJSON + (select ResponseText
											   from #responseText
											   where rownum = @NextChunkedRow)

				set @NextChunkedRow = @NextChunkedRow + 1

			end

		--  Remove the starting and trailing dashes
			set @ResponseJSON = substring(@ResponseJSON, 2, len(@ResponseJSON) -2)

		--	print @ResponseJSON



			insert into [Sandbox].[dbo].[PayrollData]
			values (@sessionId, @ResponseJSON, getdate(), NULL)



	--  Reset the ResponseText table and @ResponseJSON


			set @ResponseJSON = ''


	--  Step 4 - Get Billing Vouchers for outstanding Batches by pay period start and end date

	-- MH 7/6/2022 - Clear out @Options

			set @Options = ''


	-- MH 6/28/2022 - To move sessionid to header
	--        set @URL = 'https://api.prismhr.com/api-1.25/services/rest/payroll/getBillingVouchers'  +
			set @URL = 'https://api.prismhr.com/api-1.29/services/rest/payroll/getBillingVouchers'  +
	--  MH 9/2/2021 - getBillingVouchers uses the payDate, not the payPeriodStartDate and payPeriodEndDate
						'?payDateEnd='		+ @payDate +
						'&payDateStart='	+ @payDate + 
						'&clientId='		+ @clientId  +
	-- MH 6/28/2022 - To move sessionid to header
	--					'&sessionId='		+ @sessionId +
						'&options='			+ @Options

/* OLD 9/7/2022

			-- Open the connection.
			EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
			--Print @token
			IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

			-- Send the request.
			EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
			--set a custom header Authorization is the header key and VALUE is the value in the header
			--PRINT @authHeader
			--PRINT @res
			EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'SessionID', @authHeader;
			--PRINT @contentType
			--PRINT @res
			EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
			--PRINT @res
			EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

			-- Handle the response.
			EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
			EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
			SET TEXTSIZE 2147483647
			INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

			-- Show the response.
			--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
			--SELECT @status, responseText FROM @responseText

			-- Close the connection.
			EXEC @res = sp_OADestroy @token;
			IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);


			select @ResponseJSON = responseText
			from @responseText

*/

-- NEW 9/7/2022
			
			set @CurlCommand = N'EXEC master..xp_cmdshell ''curl -s -o /dev/null -w - ' + 
														   ' -H "SessionId: ' + 
														   @sessionId +
														   '" -H "Content-Type: application/json" "' +
														   '" -H "Accept: application/json" "' +
														   @URL +
														   '"'''

--			PRINT @CurlCommand

			truncate table #responseText
	
			SET TEXTSIZE 2147483647
			insert into #responseText
			EXEC sp_executesql @CurlCommand

--			select *
--			from @ResponseText

			set @ResponseJSON = ''

			set @NextChunkedRow = 1
			set @LastChunkedRow = (select max(rownum)
								   from #responseText)

			while @NextChunkedRow <= @LastChunkedRow

			begin

				set @ResponseJSON = @ResponseJSON + (select ResponseText
											   from #responseText
											   where rownum = @NextChunkedRow)

				set @NextChunkedRow = @NextChunkedRow + 1

			end

		--  Remove the starting and trailing dashes
			set @ResponseJSON = substring(@ResponseJSON, 2, len(@ResponseJSON) -2)

--			print @ResponseJSON



			update [Sandbox].[dbo].[PayrollData]
			set BillJSONData = @ResponseJSON
			where SessionID = @sessionId
			  and PayPeriodStart = @payDateStart
			  and PayPeriodEnd = @payDateEnd

	-- For Reloads

			DECLARE @batchID	varchar(100)

			select @batchID = batchId
			from [Sandbox].[dbo].[v_PayrollBatches]
			where payPeriodStartDate = @payDateStart
			  and payPeriodEndDate   = @payDateEnd


			delete from [Sandbox].[dbo].[PayrollVoucher]
			where batchId = @batchID

			delete from [Sandbox].[dbo].[PayrollEarning]
			where batchId = @batchID

			delete from [Sandbox].[dbo].[PayrollDeduction]
			where batchId = @batchID

			delete from [Sandbox].[dbo].[PayrollEmployeeTax]
			where batchId = @batchID

			delete from [Sandbox].[dbo].[PayrollCompanyTax]
			where batchId = @batchID

			delete from [Sandbox].[dbo].[PayrollRetirement]
			where batchId = @batchID

			delete from [Sandbox].[dbo].[PayrollWorkerComp]
			where batchId = @batchID


			insert into [Sandbox].[dbo].[PayrollVoucher]
			select *
			from [Sandbox].[dbo].[v_PayrollVoucher]
			where batchId = @batchID

			insert into [Sandbox].[dbo].[PayrollEarning]
			select *
			from [Sandbox].[dbo].[v_PayrollEarning]
			where batchId = @batchID

			insert into [Sandbox].[dbo].[PayrollDeduction]
			select *
			from [Sandbox].[dbo].[v_PayrollDeduction]
			where batchId = @batchID

			insert into [Sandbox].[dbo].[PayrollEmployeeTax]
			select *
			from [Sandbox].[dbo].[v_PayrollEmployeeTax]
			where batchId = @batchID

			insert into [Sandbox].[dbo].[PayrollCompanyTax]
			select *
			from [Sandbox].[dbo].[v_PayrollCompanyTax]
			where batchId = @batchID

			insert into [Sandbox].[dbo].[PayrollRetirement]
			select *
			from [Sandbox].[dbo].[v_PayrollRetirement]
			where batchId = @batchID

			insert into [Sandbox].[dbo].[PayrollWorkerComp]
			select *
			from [Sandbox].[dbo].[v_PayrollWorkerComp]
			where batchId = @batchID


	--  Reset the ResponseText table and @ResponseJSON

			delete from @ResponseText
			set @ResponseJSON = ''


			FETCH NEXT FROM c1 
			INTO @payDateStart, @payDateEnd, @payDate

	END   
	CLOSE c1;  
	DEALLOCATE c1;

	drop table #responseText



	insert into [Sandbox].[dbo].[NewPrismHRCodes]
	select a.billCode, a.billCodeDescription
	from [Sandbox].[dbo].[v_BillingSumBilling] a
	where not exists (select 1
					  from [Sandbox].[dbo].[PayrollGLCodeLookup] b
					  where a.billCode = b.HRCode)
	  and a.billCode not in ('001',
							 '002',
							 '003',
							 '004',
							 'CLIADV',
							 'CLIBEN',
							 'MEDICARE',
							 'OASDI')
	group by a.billCode, a.billCodeDescription



	if @@ROWCOUNT > 0
	begin 
		DECLARE @MessageText NVARCHAR(100);
		SET @MessageText = N'New PrismHR Code(s) found';

		RAISERROR(
			@MessageText, -- Message text
			16, -- severity
			1, -- state
			N'2001' -- first argument to the message text
		);
	end
	else 
	begin

		DECLARE batch_cursor CURSOR FOR
		select batchId
		from [Sandbox].[dbo].[v_PayrollBatches] a
		where not exists (select 1
						  from [Sandbox].[dbo].[PayrollBatchesLoadStatus] b
						  where a.batchId = b.batchId)
		  and a.batchStatus = 'COMP'

		declare	@LoadBatchID	nvarchar(100)

	-- Just in case...	
		delete from [Sandbox].[dbo].[Results]

		OPEN batch_cursor

		FETCH NEXT FROM batch_cursor 
		INTO @LoadBatchID
  
		WHILE @@FETCH_STATUS = 0  
		BEGIN  

		insert into [Sandbox].[dbo].[Results]
	/* MH 12/28/2021 - New, to true-up to high level totals */
		/*
		select aaa.[Line Description],
			   sum(aaa.Amount) Amount
		from ( */
		select [Company Code],
				[GL Effective Date],
				[Journal Code],
				[Journal Desc],
				[GL Account],
		/*  MH  12/28/2021 - To Round Overhead to the High Level Totals
							 for the Current JEs only, not the accruals
							 or reversals
				[Amount], */
				case when substring([GL Account], 13, 2) = '03' -- Overhead
					 then [Amount] + (select case when a.[Journal Desc] like 'BatchID%'
												  then b.TrueUpAmount
												  else 0 end
									  from v_PayrollGLJournalEntriesOverheadRound b
									  where b.batchID = a.BatchID
										and b.Memo = a.[Line Description])
					 else [Amount] end [Amount],
				[Line Description],
				[XREF1],
				[XREF2],
				[XREF3],
				[Journal ID - Batch #]
		from [Sandbox].[dbo].[v_PayrollGLJournalEntries] a
		where BatchID = @LoadBatchID
	/*
	) aaa
	where aaa.[Journal Desc] like 'BatchID%'
	group by aaa.[Line Description] */
	/* MH 12/28/2021 - Old non-trued-up code
		select [Company Code],
			   [GL Effective Date],
			   [Journal Code],
			   [Journal Desc],
			   [GL Account],
			   [Amount],
			   [Line Description],
			   [XREF1],
			   [XREF2],
			   [XREF3],
			   [Journal ID - Batch #]
					from [Sandbox].[dbo].[v_PayrollGLJournalEntries]
					where BatchID = @LoadBatchID
	*/

			FETCH NEXT FROM batch_cursor 
			INTO @LoadBatchID

			END   
			CLOSE batch_cursor;  
			DEALLOCATE batch_cursor;

			declare @ResultRecs		int

			select @ResultRecs = count(*)
			from [Sandbox].[dbo].[Results]

			if @ResultRecs > 0

			begin

				exec master..xp_cmdshell 'sqlcmd -s, -W -Q "set nocount on; select [Company Code], [GL Effective Date], [Journal Code], [Journal Desc], [GL Account], Amount, [Line Description], XREF1, XREF2, XREF3, [Journal ID - Batch #] from [Sandbox].[dbo].[Results] order by [GL Effective Date] " | findstr /v /c:"-" /b > "E:\FlexiExport\FlexiPayrollLoad.csv"'
				delete from [Sandbox].[dbo].[Results]
				exec master..xp_cmdshell 'ren E:\FlexiExport\"FlexiPayrollLoad.csv" "FlexiPayrollLoad-%date:~10,4%%date:~4,2%%date:~7,2%.csv"'
				exec master..xp_cmdshell 'E:\FlexiExport\SFTPtoFlexiPROD.bat'

				insert into [Sandbox].[dbo].[PayrollBatchesLoadStatus]
				select batchId, 'Auto Load', Getdate()
				from [Sandbox].[dbo].[v_PayrollBatches] a
				where not exists (select 1
								  from [Sandbox].[dbo].[PayrollBatchesLoadStatus] b
								  where a.batchId = b.batchId)
				  and a.batchStatus = 'COMP'

			end
	
	end

end

else

begin

	declare @int	int
	set @int = 1






end

