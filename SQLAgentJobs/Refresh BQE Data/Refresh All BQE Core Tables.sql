USE Sandbox

declare @httpMethod	nvarchar(10) 
declare @URL		nvarchar(max)
declare @Headers	nvarchar(200)
declare @JsonBody	nvarchar(max)
declare @Username	nvarchar(50)
declare @Password	nvarchar(50)
declare @PeoId		nvarchar(50)

set @Headers	= '[{ "Name": "Content-Type", "Value" :"application/x-www-form-urlencoded" }]'

--set @Headers	= '[{ "Name": "Content-Type", "Value" :"application/json" }]'

DECLARE @clientId		nvarchar(10)
DECLARE @authHeader		NVARCHAR(max);
DECLARE @SetCookie		NVARCHAR(max);
DECLARE @contentType	NVARCHAR(64);
DECLARE @postData		NVARCHAR(2000);
DECLARE @token			INT;
DECLARE @ResponseJSON	nvarchar(max);
DECLARE @pagenumber		int

declare @CurlCommand		nvarchar(max)


SET @contentType = 'application/json';



--set @URL		= 'https://api-identity.bqecore.com/idp/connect/authorize?&client_id=Bn6xMgqqHBj5fe8Xveg_zm0fE5RxWjKd.apps.bqe.com&response_type=code&scope=openid&redirect_uri=https://api-explorer/time-logger'
set @URL		= 'https://api-identity.bqecore.com/idp/connect/authorize?&client_id=Bn6xMgqqHBj5fe8Xveg_zm0fE5RxWjKd.apps.bqe.com&response_type=code&scope=readwrite:core&redirect_uri=https://api-explorer/time-logger'

DECLARE @status NVARCHAR(32)
DECLARE @statusText NVARCHAR(32);
DECLARE @responseText as table(responseText nvarchar(max))
DECLARE @ResponseHeader	as table(ResponseHeader nvarchar(max))
DECLARE @res as Int

/*

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
SET TEXTSIZE 2147483647
INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'

-- Show the response.
PRINT 'Status: ' + @status + ' (' + @statusText + ')';
SELECT @status, @statusText, responseText FROM @responseText



-- Close the connection.
EXEC @res = sp_OADestroy @token;
IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);



DECLARE @ResonseJSON	nvarchar(max)

--SELECT @status, responseText FROM @responseText
SELECT @status, @statusText, responseHeader FROM @responseHeader

set @SetCookie	= (select substring(responseHeader, charindex('Set-Cookie: .AspNetCore.Antiforgery.BqaIEy92DQc=', responseHeader), charindex('Vary:', responseHeader) - charindex('Set-Cookie: .AspNetCore.Antiforgery.BqaIEy92DQc=', responseHeader))
                   from @responseHeader)

print @SetCookie

set @authHeader	= (select substring(responseText, charindex('<input name="__RequestVerificationToken" type="hidden" value="', responseText) + 62, charindex('" /></form>', responseText) - 62 - charindex('<input name="__RequestVerificationToken" type="hidden" value="', responseText))
                   from @responseText)

print @authHeader


/*

set @authHeader = '.AspNetCore.Antiforgery.BqaIEy92DQc=' + @authHeader
print @authHeader

*/

/*
select @ResonseJSON = responseText
from @responseText
*/




*/



/*

set @authHeader = '101518f7001e579e4530becffd7008ec8fd9f3b454f0d5f5a0e92b10f1826b4f'





*/


declare @TokenExpirationDateTime	datetime
declare @BQEAPIToken				nvarchar(max)
declare @BQEAPIRefreshToken			nvarchar(max)

select @TokenExpirationDateTime = ExpirationDateTime,
       @BQEAPIToken				= Token,
	   @BQEAPIRefreshToken		= RefreshToken
from [Sandbox].[dbo].[BQECoreAPIToken]


if IsNull(@TokenExpirationDateTime, dateadd(d, -1, getdate())) <= getdate()
begin


-- Get Refresh Access Token



	set @URL			= 'https://api-identity.bqecore.com/idp/connect/token'
	set @contentType	= 'application/x-www-form-urlencoded'
	--set @contentType	= 'application/json'

	--set @postData		= 'grant_type=authorization_code&redirect_uri=https://api-explorer/time-logger&code=' + @BQEAPIRefreshToken + '&client_id=Bn6xMgqqHBj5fe8Xveg_zm0fE5RxWjKd.apps.bqe.com&client_secret=XgD8vKawHtcN7SqjqZ08R4b042w79UYIoBAh5Gkfgx9Rrub0VyK71tvNWKMcnXhA'
	set @postData		= 'grant_type=refresh_token&refresh_token=' + @BQEAPIRefreshToken + '&client_id=Bn6xMgqqHBj5fe8Xveg_zm0fE5RxWjKd.apps.bqe.com&client_secret=V8JCiATeauWtYM4J_FYjYMkz0BcrSZeV6JO3URDqzu_sxxUyidLTEmFqIGGuu_La'
	

--	print @postData


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'POST', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
--	PRINT @authHeader
--	PRINT @res
--	PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
--	PRINT @res

	/*

	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Set-Cookie', @SetCookie;
	PRINT @res

	*/

	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
--	PRINT @res


	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;

	DELETE from @ResponseText
	SET TEXTSIZE 2147483647
	INSERT INTO @ResponseText (ResponseText) EXEC @res = sp_OAGetProperty @token, 'responseText'
--	print @res

--	select *
--	from @ResponseText	

	select @ResponseJSON = responseText
	from @responseText


	SET TEXTSIZE 2147483647
	delete from @ResponseHeader
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'
--	print @res

--	select @status, @statusText, ResponseHeader
--	from @ResponseHeader

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	
--	set @BQEAPIToken = (select substring(responseText, charindex('"access_token":"', responseText) + 16, charindex('","expires_in"', responseText) - charindex('"access_token":"', responseText)- 16)
--                        from @responseText)

	set @BQEAPIToken = (select aaa.[Value]
						from (
						select *
						from openjson(@ResponseJSON)) aaa
						where aaa.[key] = 'access_token')

--    set @BQEAPIRefreshToken = (select substring(responseText, charindex('"refresh_token":"', responseText) + 17, charindex('","scope":"', responseText) - charindex('"refresh_token":"', responseText)- 17)
--                               from @responseText) 

	set @BQEAPIRefreshToken = (select aaa.[Value]
							   from (
							   select *
							   from openjson(@ResponseJSON)) aaa
							   where aaa.[key] = 'refresh_token')


--    print @BQEAPIToken

    if IsNull(@BQEAPIToken, '') <> ''
	begin

		delete from [Sandbox].[dbo].[BQECoreAPIToken]

		insert into [Sandbox].[dbo].[BQECoreAPIToken]
		values (@BQEAPIToken, dateadd(hh, 1, GetDate()), @BQEAPIRefreshToken)

    end

end
else
begin

	set @BQEAPIToken = (select Token
						from [Sandbox].[dbo].[BQECoreAPIToken])

end

if IsNull(@BQEAPIToken, '') <> ''

begin


	set @authHeader = 'Bearer ' + @BQEAPIToken
	--print @authHeader





--  Get All Expenses - Using this to make sure BQE Core APIs are up and running

		SET @contentType	= 'application/json';
		set @URL			= 'https://api.bqecore.com/api/expense?page=1,100'

		set @PageNumber = 1

		-- Loop thru and increment @PageNumber until @@Rowcount = 1

		truncate table [Sandbox].[dbo].[BQEExpense]	 

		While @PageNumber is not NULL
		--While @PageNumber = 1

		Begin

			set @URL		= 'https://api.bqecore.com/api/expense?page=' + convert(varchar, @PageNumber) +',1000'


			-- Open the connection.
			EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
			--Print @token
			IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

			-- Send the request.
			EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

			EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
			--print @res
			EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
			--print @res
			EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
			--print @res
			EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
			--print @res

			-- Handle the response.
			EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
			EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
			SET TEXTSIZE 2147483647
			delete from @ResponseText
			INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

			delete from @ResponseHeader
			SET TEXTSIZE 2147483647
			INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


			-- Show the response.
			--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
			--SELECT @status, responseText FROM @responseText
			--SELECT @status, responseHeader FROM @ResponseHeader


			-- Close the connection.
			EXEC @res = sp_OADestroy @token;
			--PRINT @res
			IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

			/*
			SELECT @status, responseText FROM @responseText
			*/

			select @ResponseJSON = responseText
			from @responseText

			insert into [Sandbox].[dbo].[BQEExpense]	
			select [value]
--			into [Sandbox].[dbo].[BQEExpense]
			from openjson(@ResponseJSON)


			if @@ROWCOUNT > 0
				set @PageNumber = @PageNumber + 1
			else
				set @PageNumber = NULL
    

		end



	--  Get All Invoices

	SET @contentType	= 'application/json';
	set @URL			= 'https://api.bqecore.com/api/invoice?page=' + convert(varchar, @PageNumber) +',1000'
	set @PageNumber		= 1




	-- Loop thru and increment @PageNumber until @@Rowcount = 1

	truncate table [Sandbox].[dbo].[BQEInvoice]	 

	While @PageNumber is not NULL
	--While @PageNumber = 1

	Begin

		set @URL		= 'https://api.bqecore.com/api/invoice?page=' + convert(varchar, @PageNumber) +',1000'



		-- Open the connection.
		EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
		--Print @token
		IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

		-- Send the request.
		EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
		--print @res

		-- Handle the response.
		EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
		EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
		SET TEXTSIZE 2147483647
		delete from @ResponseText
		INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

		delete from @ResponseHeader
		SET TEXTSIZE 2147483647
		INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


		-- Show the response.
		--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
		--SELECT @status, responseText FROM @responseText
		--SELECT @status, responseHeader FROM @ResponseHeader


		-- Close the connection.
		EXEC @res = sp_OADestroy @token;
		--PRINT @res
		IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	
	--	SELECT @status, responseText FROM @responseText
	

		select @ResponseJSON = responseText
		from @responseText

		insert into [Sandbox].[dbo].[BQEInvoice]	
		select [value],
				json_value([Value], '$."id"') InvoiceId, 
				json_value([Value], '$."invoiceNumber"') InvoiceNumber, 
				json_value([Value], '$."status"') InvoiceStatus, 
				json_value([Value], '$."referenceNumber"') ReferenceNumber, 
				json_value([Value], '$."rfNumber"') RfNumber, 
				convert(money, json_value([Value], '$."invoiceAmount"')) InvoiceAmount, 
				convert(money, json_value([Value], '$."balance"')) Balance, 
				convert(money, json_value([Value], '$."serviceAmount"')) ServiceAmount, 
				convert(money, json_value([Value], '$."expenseAmount"')) ExpenseAmount, 
				convert(date, json_value([Value], '$."createdOn"')) CreatedDate, 
				convert(date, json_value([Value], '$."invoiceFrom"')) InvoiceFrom, 
				convert(date, json_value([Value], '$."invoiceTo"')) InvoiceTo, 
				convert(date, json_value([Value], '$."dueDate"')) DueDate
		--into [Sandbox].[dbo].[BQEInvoice]
		from openjson(@ResponseJSON)

		if @@ROWCOUNT > 0
			set @PageNumber = @PageNumber + 1
		else
			set @PageNumber = NULL
    

	end




	--  Get All Projects

	SET @contentType	= 'application/json';
	--set @URL			= 'https://api.bqecore.com/api/project?page=1,1000'

	set @PageNumber = 1

	-- Loop thru and increment @PageNumber until @@Rowcount = 1

	truncate table [Sandbox].[dbo].[BQEProject]	 

	While @PageNumber is not NULL
	--While @PageNumber = 1

	Begin

		set @URL		= 'https://api.bqecore.com/api/project?page=' + convert(varchar, @PageNumber) +',1000'

		-- Open the connection.
		EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
		--Print @token
		IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

		-- Send the request.
		EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
		--print @res

		-- Handle the response.
		EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
		EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
		SET TEXTSIZE 2147483647
		delete from @ResponseText
		INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

		delete from @ResponseHeader
		SET TEXTSIZE 2147483647
		INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


		-- Show the response.
		--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
		--SELECT @status, responseText FROM @responseText
		--SELECT @status, responseHeader FROM @ResponseHeader


		-- Close the connection.
		EXEC @res = sp_OADestroy @token;
		--PRINT @res
		IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

		/*
		SELECT @status, responseText FROM @responseText
		*/

		select @ResponseJSON = responseText
		from @responseText

		insert into [Sandbox].[dbo].[BQEProject]
		select [value],
				json_value([Value], '$."displayName"') DisplayName,
				json_value([Value], '$."name"') [ProjectName],
				json_value([Value], '$."code"') [ProjectCode],
				json_value([Value], '$."client"') [Client],
				json_value([Value], '$."manager"') [Manager],
				json_value([Value], '$."principal"') [Principal],
				json_value([Value], '$."billingContact"') [BillingContact]
	--    into [Sandbox].[dbo].[BQEProject]
		from openjson(@ResponseJSON)

		if @@ROWCOUNT > 0
			set @PageNumber = @PageNumber + 1
		else
			set @PageNumber = NULL
    

	end




	--  Get All Payments

	SET @contentType	= 'application/json';
	set @URL			= 'https://api.bqecore.com/api/payment?page=1,1000'

	set @PageNumber = 1

	truncate table [Sandbox].[dbo].[BQEPayment]

	-- Loop thru and increment @PageNumber until @@Rowcount = 1

	While @PageNumber is not NULL

	Begin

		set @URL		= 'https://api.bqecore.com/api/payment?page=' + convert(varchar, @PageNumber) +',1000'

		-- Open the connection.
		EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
		--Print @token
		IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

		-- Send the request.
		EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
		--print @res

		-- Handle the response.
		EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
		EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
		SET TEXTSIZE 2147483647
		delete from @ResponseText
		INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

		delete from @ResponseHeader
		SET TEXTSIZE 2147483647
		INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


		-- Show the response.
		--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
		--SELECT @status, responseText FROM @responseText
		--SELECT @status, responseHeader FROM @ResponseHeader


		-- Close the connection.
		EXEC @res = sp_OADestroy @token;
		--PRINT @res
		IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

		/*
		SELECT @status, responseText FROM @responseText
		*/

		select @ResponseJSON = responseText
		from @responseText

		insert into [Sandbox].[dbo].[BQEPayment]
		select [value],
				json_value([Value], '$."date"') PaymentDate,
				json_value([Value], '$."reference"') Reference,
				json_value([Value], '$."client"') Client,
				json_value([Value], '$."project"') Project,
				json_value([Value], '$."method"') Method,
				convert(money, json_value([Value], '$."amount"')) Amount
	--	into [Sandbox].[dbo].[BQEPayment]
		from openjson(@ResponseJSON)



		if @@ROWCOUNT > 0
			set @PageNumber = @PageNumber + 1
		else
			set @PageNumber = NULL
    

	end


/*

	--  Get All Groups

	SET @contentType	= 'application/json';
	set @URL			= 'https://api.bqecore.com/api/group?page=1,100'



	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--print @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
	--print @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--print @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--print @res

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	delete from @ResponseHeader
	SET TEXTSIZE 2147483647
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText
	--SELECT @status, responseHeader FROM @ResponseHeader


	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	--PRINT @res
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	/*
	SELECT @status, responseText FROM @responseText
	*/

	select @ResponseJSON = responseText
	from @responseText

	
	select [value]
	from openjson(@ResponseJSON)




	--  Get All Employees

	SET @contentType	= 'application/json';
	set @URL			= 'https://api.bqecore.com/api/employee?page=1,100'



	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--print @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
	--print @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--print @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--print @res

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	delete from @ResponseHeader
	SET TEXTSIZE 2147483647
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText
	--SELECT @status, responseHeader FROM @ResponseHeader


	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	--PRINT @res
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	/*
	SELECT @status, responseText FROM @responseText
	*/

	select @ResponseJSON = responseText
	from @responseText

	
	select [value]
	from openjson(@ResponseJSON)

	*/

	--  Get All Clients

	SET @contentType	= 'application/json';
	set @URL			= 'https://api.bqecore.com/api/client?page=1,100'

	set @PageNumber = 1

	truncate table [Sandbox].[dbo].[BQEClient]

	-- Loop thru and increment @PageNumber until @@Rowcount = 1

	While @PageNumber is not NULL
	--While @PageNumber = 1

	Begin

		set @URL		= 'https://api.bqecore.com/api/client?page=' + convert(varchar, @PageNumber) +',1000'



		-- Open the connection.
		EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
		--Print @token
		IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

		-- Send the request.
		EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
		--print @res

		-- Handle the response.
		EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
		EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
		SET TEXTSIZE 2147483647
		delete from @ResponseText
		INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

		delete from @ResponseHeader
		SET TEXTSIZE 2147483647
		INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


		-- Show the response.
		--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
		--SELECT @status, responseText FROM @responseText
		--SELECT @status, responseHeader FROM @ResponseHeader


		-- Close the connection.
		EXEC @res = sp_OADestroy @token;
		--PRINT @res
		IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

		/*
		SELECT @status, responseText FROM @responseText
		*/

		select @ResponseJSON = responseText
		from @responseText

	
		insert into [Sandbox].[dbo].[BQEClient]
		select [value],
				json_value([Value], '$."name"') ClientName,
				json_value([Value], '$."company"') CompanyName,
				json_value([Value], '$."firstName"') + ' ' + json_value([Value], '$."lastName"') CompanyContactName,
				json_value([Value], '$."manager"') Manager
	--	into [Sandbox].[dbo].[BQEClient]
		from openjson(@ResponseJSON)

		if @@ROWCOUNT > 0
			set @PageNumber = @PageNumber + 1
		else
			set @PageNumber = NULL
    

	end

	/*

	--  Get All Bills

	SET @contentType	= 'application/json';
	set @URL			= 'https://api.bqecore.com/api/bill?page=1,1000'



	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--print @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
	--print @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--print @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--print @res

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	delete from @ResponseHeader
	SET TEXTSIZE 2147483647
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText
	--SELECT @status, responseHeader FROM @ResponseHeader


	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	--PRINT @res
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	/*
	SELECT @status, responseText FROM @responseText
	*/

	select @ResponseJSON = responseText
	from @responseText

	
	select [value]
	from openjson(@ResponseJSON)



	--  Get All Activities

	SET @contentType	= 'application/json';
	set @URL			= 'https://api.bqecore.com/api/activity?page=1,1000'



	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--print @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
	--print @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--print @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--print @res

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	delete from @ResponseHeader
	SET TEXTSIZE 2147483647
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText
	--SELECT @status, responseHeader FROM @ResponseHeader


	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	--PRINT @res
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	/*
	SELECT @status, responseText FROM @responseText
	*/

	select @ResponseJSON = responseText
	from @responseText

	
	select [value]
	from openjson(@ResponseJSON)



	--  Get All Accounts

	SET @contentType	= 'application/json';
	set @URL			= 'https://api.bqecore.com/api/account?page=1,100'



	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--print @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
	--print @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--print @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--print @res

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	delete from @ResponseHeader
	SET TEXTSIZE 2147483647
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText
	--SELECT @status, responseHeader FROM @ResponseHeader


	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	--PRINT @res
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	/*
	SELECT @status, responseText FROM @responseText
	*/

	select @ResponseJSON = responseText
	from @responseText

	
	select [value]
	from openjson(@ResponseJSON)

	*/


	--  Get All Time Entries

	SET @contentType	= 'application/json';
	--set @URL			= 'https://api.bqecore.com/api/timeentry?page=1,1000'

	set @PageNumber = 1

	truncate table [Sandbox].[dbo].[BQETimeEntry]
	--drop table [Sandbox].[dbo].[BQETimeEntry]

	-- Loop thru and increment @PageNumber until @@Rowcount = 1

	While @PageNumber is not NULL
	--While @PageNumber = 1

	Begin

		set @URL		= 'https://api.bqecore.com/api/timeentry?page=' + convert(varchar, @PageNumber) +',1000'

		-- Open the connection.
		EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
		--Print @token
		IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

		-- Send the request.
		EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
		--print @res

		-- Handle the response.
		EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
		EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
		SET TEXTSIZE 2147483647
		delete from @ResponseText
		INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

		delete from @ResponseHeader
		SET TEXTSIZE 2147483647
		INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


		-- Show the response.
		--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
		--SELECT @status, responseText FROM @responseText
		--SELECT @status, responseHeader FROM @ResponseHeader


		-- Close the connection.
		EXEC @res = sp_OADestroy @token;
		--PRINT @res
		IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

		/*
		SELECT @status, responseText FROM @responseText
		*/

		select @ResponseJSON = responseText
		from @responseText

		insert into [Sandbox].[dbo].[BQETimeEntry]
		select [value], 
				json_value([Value], '$."id"') TimeEntryId,
				convert(date, json_value([Value], '$."date"')) ActivityDate, 
				json_value([Value], '$."client"') Client,
				json_value([Value], '$."invoiceId"') InvoiceId,
				json_value([Value], '$."invoiceNumber"') InvoiceNumber,
				json_value([Value], '$."activityId"') ActivityId, 
				json_value([Value], '$."activity"') Activity, 
				json_value([Value], '$."projectId"') ProjectId, 
				json_value([Value], '$."project"') Project, 
				json_value([Value], '$."resourceId"') ResourceId, 
				json_value([Value], '$."resource"') [Resource], 
				json_value([Value], '$."description"') [Description], 
				json_value([Value], '$."billable"') Billable, 
				json_value([Value], '$."billStatus"') BillStatus, 
				json_value([Value], '$."actualHours"') ActualHours, 
				json_value([Value], '$."clientHours"') ClientHours, 
				json_value([Value], '$."billRate"') BillRate, 
				json_value([Value], '$."classification"') [Classification], 
				convert(date, json_value([Value], '$."createdOn"')) CreatedOn, 
				convert(date, json_value([Value], '$."lastUpdated"')) LastUpdated
	--    into [Sandbox].[dbo].[BQETimeEntry]
		from openjson(@ResponseJSON)

		if @@ROWCOUNT > 0
			set @PageNumber = @PageNumber + 1
		else
			set @PageNumber = NULL
    

	end



	--  Get All Expense Entries

	SET @contentType	= 'application/json';
	--set @URL			= 'https://api.bqecore.com/api/expenseentry?page=1,1000'

	set @PageNumber = 1

	truncate table [Sandbox].[dbo].[BQEExpenseEntry]

	-- Loop thru and increment @PageNumber until @@Rowcount = 1

	While @PageNumber is not NULL
	--While @PageNumber = 1

	Begin

		set @URL		= 'https://api.bqecore.com/api/expenseentry?page=' + convert(varchar, @PageNumber) +',1000'

		-- Open the connection.
		EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
		--Print @token
		IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

		-- Send the request.
		EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
		--print @res

		-- Handle the response.
		EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
		EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
		SET TEXTSIZE 2147483647
		delete from @ResponseText
		INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

		delete from @ResponseHeader
		SET TEXTSIZE 2147483647
		INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


		-- Show the response.
		--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
		--SELECT @status, responseText FROM @responseText
		--SELECT @status, responseHeader FROM @ResponseHeader


		-- Close the connection.
		EXEC @res = sp_OADestroy @token;
		--PRINT @res
		IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

		/*
		SELECT @status, responseText FROM @responseText
		*/

		select @ResponseJSON = responseText
		from @responseText



		insert into [Sandbox].[dbo].[BQEExpenseEntry]
		select [value], 
				json_value([Value], '$."id"') ExpenseEntryId,
				convert(date, json_value([Value], '$."date"')) ActivityDate, 
				json_value([Value], '$."client"') Client,
				json_value([Value], '$."invoiceId"') InvoiceId,
				json_value([Value], '$."invoiceNumber"') InvoiceNumber,
				json_value([Value], '$."expenseId"') ActivityId, 
				json_value([Value], '$."expense"') Activity, 
				json_value([Value], '$."projectId"') ProjectId, 
				json_value([Value], '$."project"') Project, 
				json_value([Value], '$."resourceId"') ResourceId, 
				json_value([Value], '$."resource"') [Resource], 
				json_value([Value], '$."description"') [Description], 
				json_value([Value], '$."billable"') Billable, 
				json_value([Value], '$."billStatus"') BillStatus, 
				json_value([Value], '$."units"') Units, 
				json_value([Value], '$."costRate"') CostRate, 
				json_value([Value], '$."chargeAmount"') ChargeAmount, 
				json_value([Value], '$."classification"') [Classification], 
				convert(date, json_value([Value], '$."createdOn"')) CreatedOn, 
				convert(date, json_value([Value], '$."lastUpdated"')) LastUpdated
	--    into [Sandbox].[dbo].[BQEExpenseEntry]
		from openjson(@ResponseJSON)



		if @@ROWCOUNT > 0
			set @PageNumber = @PageNumber + 1
		else
			set @PageNumber = NULL
    

	end

	/*

	--  Get All Notes

	SET @contentType	= 'application/json';

	set @PageNumber = 1

	--truncate table [Sandbox].[dbo].[BQENote]

	-- Loop thru and increment @PageNumber until @@Rowcount = 1

	While @PageNumber is not NULL
	--While @PageNumber = 1

	Begin

		set @URL		= 'https://api.bqecore.com/api/group?page=' + convert(varchar, @PageNumber) +',1000'



		-- Open the connection.
		EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
		--Print @token
		IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

		-- Send the request.
		EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
		--print @res
		EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
		--print @res
		EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
		--print @res

		-- Handle the response.
		EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
		EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
		SET TEXTSIZE 2147483647
		delete from @ResponseText
		INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

		delete from @ResponseHeader
		SET TEXTSIZE 2147483647
		INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'


		-- Show the response.
		--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
		--SELECT @status, responseText FROM @responseText
		--SELECT @status, responseHeader FROM @ResponseHeader


		-- Close the connection.
		EXEC @res = sp_OADestroy @token;
		--PRINT @res
		IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

		/*
		SELECT @status, responseText FROM @responseText
		*/

		select @ResponseJSON = responseText
		from @responseText

		select *
		from openjson(@ResponseJSON)

		/*
	
		insert into [Sandbox].[dbo].[BQENote]
		select [value],
				json_value([Value], '$."name"') ClientName,
				json_value([Value], '$."company"') CompanyName,
				json_value([Value], '$."firstName"') + ' ' + json_value([Value], '$."lastName"') CompanyContactName,
				json_value([Value], '$."manager"') Manager
	--	into [Sandbox].[dbo].[BQENote]
		from openjson(@ResponseJSON)

		*/

		if @@ROWCOUNT > 0
			set @PageNumber = @PageNumber + 1
		else
			set @PageNumber = NULL
    

	end

	*/



end