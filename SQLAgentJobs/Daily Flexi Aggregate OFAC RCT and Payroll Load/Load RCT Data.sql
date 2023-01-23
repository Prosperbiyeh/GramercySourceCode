USE Sandbox

declare @httpMethod	nvarchar(10) 
declare @URL		nvarchar(200)
declare @Headers	nvarchar(max)
declare @JsonBody	nvarchar(max)
declare @Username	nvarchar(50)
declare @Password	nvarchar(50)

set @httpMethod = 'POST'
set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/authentication'
set @Headers	= '[{ "Name": "Accept", "Value" :"application/json", "Name": "Content-Type", "Value" :"application/json"}]'

/*
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

*/

--set @JsonBody	= '{"Username": "GramercyIT", "Password": "29KW9i1Zl3Dw"}'


--  Step 1 - Get Authentication



DECLARE @authHeader		NVARCHAR(max);
DECLARE @contentType	NVARCHAR(64);
DECLARE @postData		NVARCHAR(max);
DECLARE @token			INT;

DECLARE @status			NVARCHAR(32)
DECLARE @statusText		NVARCHAR(32);
DECLARE @responseText	as table(responseText nvarchar(max))
DECLARE @ResponseHeader	as table(rownum int identity(1, 1), ResponseHeader nvarchar(max))
DECLARE @res			as Int
declare @PageNumber		int

DECLARE @ResponseJSON	nvarchar(max)
DECLARE @ResponseHeaderText	nvarchar(max)

declare @CurlCommand		nvarchar(max)




--set @CurlCommand = N'EXEC master..xp_cmdshell ''curl -s -o /dev/null -D - POST "https://rdi6.riskcontrol.expert/gramercy/api/authentication?Lang=en" -H "accept: application/json" -H "X-Version: 1.1" -H "Content-Type: application/json" -d "{\"Username\":\"GramercyIT\",\"Password\":\"29KW9i1Zl3Dw\"}"'''
set @CurlCommand = N'EXEC master..xp_cmdshell ''curl -s -o /dev/null -D - POST "https://rdi6.riskcontrol.expert/gramercy/api/authentication?Lang=en" -H "accept: application/json" -H "X-Version: 1.1" -H "Content-Type: application/json" -d "{\"Username\":\"admin\",\"Password\":\"3Ac75UcoKVje\"}"'''


--PRINT @CurlCommand

SET TEXTSIZE 2147483647
delete from @ResponseHeader
insert into @ResponseHeader
EXEC sp_executesql @CurlCommand

--select * from @ResponseHeader

DECLARE @XXSRFTOKEN			nvarchar(max)
DECLARE @SetCookie			nvarchar(max)
DECLARE @NextCookieRow		int
DECLARE @LastCookieRow		int
DECLARE @RowCounter			int

set @XXSRFTOKEN		= (select substring(ResponseHeader, 15, len(ResponseHeader) - 14)
				       from @ResponseHeader
				       where ResponseHeader like 'X-XSRF-TOKEN:%')

set @NextCookieRow	= (select rownum + 1
					   from @ResponseHeader
				       where ResponseHeader like 'Set-Cookie: ACCESS-TOKEN=%')

set @SetCookie		= (select substring(ResponseHeader, 13, len(ResponseHeader) - 12)
				       from @ResponseHeader
				       where ResponseHeader like 'Set-Cookie: ACCESS-TOKEN=%')

set @LastCookieRow	= (select min(rownum) - 1
				       from @ResponseHeader
				       where ResponseHeader like 'Set-Cookie:%'
					     and rownum > @NextCookieRow)

--print @XXSRFTOKEN
--print @SetCookie
--print @NextCookieRow
--print @LastCookieRow



while @NextCookieRow <= @LastCookieRow

begin

	set @SetCookie = @SetCookie + (select ResponseHeader
								   from @ResponseHeader
								   where rownum = @NextCookieRow)

    set @NextCookieRow = @NextCookieRow + 1

end

--print @SetCookie


DECLARE @RctID			nvarchar(100)
DECLARE @IMSID			int
DECLARE @OpType			varchar(10)

------------------------------------------------
-- Daily Housekeeping




--  Get List IDs Names and Codes

SET @contentType = 'application/json';
set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/lists?OrderBy=Id&Lang=en'
--Print @URL


-- Open the connection.
EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
--Print @token
IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

-- Send the request.
EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
--set a custom header Authorization is the header key and VALUE is the value in the header
--PRINT @authHeader
--PRINT @res
--PRINT @contentType
--PRINT @res
EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
--PRINT @res
EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

-- Handle the response.
EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
SET TEXTSIZE 2147483647
delete from @ResponseText
INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

-- Show the response.
--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
--SELECT @status, responseText FROM @responseText

-- Close the connection.
EXEC @res = sp_OADestroy @token;
IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

--SELECT @status, responseText FROM @responseText

select @ResponseJSON = responseText
from @responseText

truncate table [Sandbox].[dbo].[RCTLists]

insert into [Sandbox].[dbo].[RCTLists]
select json_value([Value], '$."Id"') Id, 
       json_value([Value], '$."ListName"') ListName, 
       json_value([Value], '$."ListCode"') ListCode, 
       [value]
from openjson(@ResponseJSON)




--  Get all list items

declare @ListTypeId		int

SET @contentType = 'application/json';

DECLARE @j				INT = 1
DECLARE @count			INT
DECLARE @ListName		varchar(200)
DECLARE @ListCode		varchar(200)

SELECT @count =  Count(*) FROM [Sandbox].[dbo].[RCTLists]

truncate table [Sandbox].[dbo].[RCTListData]

WHILE @j <= @count
--WHILE @j = 1
BEGIN

	select @ListTypeId	= Id,
	       @ListName	= ListName,
	       @ListCode	= ListCode
	from (
	select RANK() over (order by convert(int, Id)) ListRank,
		   Id,
		   ListName,
		   ListCode
	from [Sandbox].[dbo].[RCTLists]) aa
	where ListRank = @j


	
	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/lists/' + convert(varchar, @ListTypeId) + '/items?OrderBy=Ordinal&Lang=en'
	--Print @URL


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);


	--SELECT @status, responseText FROM @responseText

	select @ResponseJSON = responseText
	from @responseText

	insert into [Sandbox].[dbo].[RCTListData]
	select @ListTypeId ListTypeId,
	       @ListName ListName,
		   @ListCode ListCode,
	       json_value([Value], '$."Id"') Id, 
		   json_value([Value], '$."Code"') Code, 
		   json_value([Value], '$."Caption"') Name,
		   [value]
--	into [Sandbox].[dbo].[RCTListData]
	from openjson(@ResponseJSON)

    SET @j = @j + 1;

END



--  Get all Provinces


SET @contentType = 'application/json';

truncate table [Sandbox].[dbo].[RCTProvinces]



--  Country code 124 in URL below is for US States
set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/countries/124/provinces?OrderBy=Id&Lang=en'
--Print @URL


-- Open the connection.
EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
--Print @token
IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

-- Send the request.
EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
--set a custom header Authorization is the header key and VALUE is the value in the header
--PRINT @authHeader
--PRINT @res
--PRINT @contentType
--PRINT @res
EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
--PRINT @res
EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

-- Handle the response.
EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
SET TEXTSIZE 2147483647
delete from @ResponseText
INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

-- Show the response.
--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
--SELECT @status, responseText FROM @responseText

-- Close the connection.
EXEC @res = sp_OADestroy @token;
IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);


--SELECT @status, responseText FROM @responseText

select @ResponseJSON = responseText
from @responseText

insert into [Sandbox].[dbo].[RCTProvinces]
select json_value([Value], '$."Id"') Id, 
		json_value([Value], '$."Code"') Code, 
		json_value([Value], '$."Name"') Name,
		[value]
--	into [Sandbox].[dbo].[RCTProvinces]
from openjson(@ResponseJSON)





--  Get the Extension Field Names and IDs



SET @contentType = 'application/json';

-- MH 6/28/2022 - To move sessionid to header
set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/accounts/extension-fields?OrderBy=Id&PageNumber=1&PageSize=100&Lang=en'
--Print @URL


-- Open the connection.
EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
--Print @token
IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

-- Send the request.
EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
--set a custom header Authorization is the header key and VALUE is the value in the header
--PRINT @authHeader
--PRINT @res
--PRINT @contentType
--PRINT @res
EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
--PRINT @res
EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

-- Handle the response.
EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
SET TEXTSIZE 2147483647

delete from @ResponseText
INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

-- Show the response.
--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
--SELECT @status, responseText FROM @responseText

-- Close the connection.
EXEC @res = sp_OADestroy @token;
IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);


--SELECT @status, responseText FROM @responseText

select @ResponseJSON = responseText
from @responseText


truncate table [Sandbox].[dbo].[RCTExtensionFields]

insert into [Sandbox].[dbo].[RCTExtensionFields]
select json_value([Value], '$."Id"') Id, 
       json_value([Value], '$."FieldName"') FieldName, 
       [value]
--into [Sandbox].[dbo].[RCTExtensionFields]
from openjson(@ResponseJSON)







--  Get the Task Extension Field Names and IDs


SET @contentType = 'application/json';

-- MH 6/28/2022 - To move sessionid to header
set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/tasks/extension-fields?OrderBy=Id&PageNumber=1&PageSize=100&Lang=en'
--Print @URL


-- Open the connection.
EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
--Print @token
IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

-- Send the request.
EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
--set a custom header Authorization is the header key and VALUE is the value in the header
--PRINT @authHeader
--PRINT @res
--PRINT @contentType
--PRINT @res
EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
--PRINT @res
EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

-- Handle the response.
EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
SET TEXTSIZE 2147483647

delete from @ResponseText
INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

-- Show the response.
--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
--SELECT @status, responseText FROM @responseText

-- Close the connection.
EXEC @res = sp_OADestroy @token;
IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);


--SELECT @status, responseText FROM @responseText

select @ResponseJSON = responseText
from @responseText


truncate table [Sandbox].[dbo].[RCTTaskExtensionFields]

insert into [Sandbox].[dbo].[RCTTaskExtensionFields]
select json_value([Value], '$."Id"') Id, 
       json_value([Value], '$."FieldName"') FieldName, 
       [value]
--into [Sandbox].[dbo].RCTTaskExtensionFields
from openjson(@ResponseJSON)





--------------------------------------------

--  Insert/Update Broker Info

DECLARE @BrokerIMSId		nvarchar(100)
DECLARE @BrokerRCTId		nvarchar(100)
DECLARE @BrokerName			nvarchar(100)
DECLARE @BrokerAddressLine	nvarchar(100)
DECLARE @BrokerCity			nvarchar(100)
DECLARE @BrokerProvince		int
DECLARE @BrokerZipCode		nvarchar(100)
DECLARE @BrokerPhone		nvarchar(100)
DECLARE @NextBrokerCode		nvarchar(100)



select @NextBrokerCode = IsNull(NextCode, '001')
from [Sandbox].[dbo].[v_RCTMaxBrokerCode]


DECLARE insert_update_brokers CURSOR FOR
select convert(nvarchar(36), IMSProducerID) IMSProducerID,
       RCTBrokerID,
       ProducerName,
	   AddressLine,
	   City,
	   Province,
	   ZipCode,
	   Phone
from [Sandbox].[dbo].[v_RCTBrokerInsertUpdate]

OPEN insert_update_brokers  
  
FETCH NEXT FROM insert_update_brokers   
INTO @BrokerIMSId, @BrokerRCTId, @BrokerName, @BrokerAddressLine, @BrokerCity, @BrokerProvince, @BrokerZipCode, @BrokerPhone


WHILE @@FETCH_STATUS = 0  
BEGIN  


if @BrokerRCTId is NULL  -- Add New Broker
begin

	SET @contentType = 'application/json';

	-- MH 6/28/2022 - To move sessionid to header
	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/companies?Lang=en'
	--Print @URL

	set @postData = '{
					  "ExternalUniqueId": "' + @BrokerIMSId + '",
					  "Type": 4,
					  "Address": {
						"ProvinceId": "' + convert(varchar, @BrokerProvince) + '",
						"AddressLine": "' + @BrokerAddressLine + '",
						"City": "' + @BrokerCity + '",
						"PostalCode": "' + @BrokerZipCode + '",
						"Longitude": 0,
						"Latitude": 0,
						"County": "-"
					  },
					  "Name": "' + @BrokerName + '",
					  "Phone": "' + @BrokerPhone + '",
					  "Fax": "",
					  "Notes": "",
					  "DivisionId": 2286,
					  "Code": "' + @NextBrokerCode + '"
					}'
	--Print @postData


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'POST', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res

	DELETE from @ResponseHeader
	SET TEXTSIZE 2147483647
	delete from @ResponseHeader
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'

/*	
	select ResponseHeader,
		   substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)) location,
		   substring(substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)), 
					 len(substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10))) - 22, 
					 23) RCTAccountID
	from @ResponseHeader
*/	

--  Get the newly created RCTId

/*

	select @RctID = substring(locationURL, charindex('accounts/', locationURL) + 9, len(locationURL) - charindex('accounts/', locationURL) + 9)
	from (
	select substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, 
					 (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)) locationURL
	from @ResponseHeader) aaa


	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText

*/

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	--select @ResponseJSON = responseText
	--from @responseText

	/*
	select json_value([Value], '$."Id"') JsonValue, 
		   json_value([Value], '$."FieldName"') JsonName, 
		   [value]
	from openjson(@ResponseJSON)
	*/

	set @NextBrokerCode = RIGHT(REPLICATE('0', 3) + convert(varchar, convert(int, @NextBrokerCode) + 1), 3)

end

else -- Replace Existing Broker
begin



	SET @contentType = 'application/json';

	set @OpType		= 'add'  --replace doesn't seem to work, maybe because there are multiple fields being replaced
								--add does a replace anyway

	-- MH 6/28/2022 - To move sessionid to header
	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/companies/' + @BrokerRCTId + '?Lang=en'
--	Print @URL

	

	--  Step 1 - Update all Fields

	set @postData = (
	select 
	(
	select a.*
	from (
	select b.ProducerName value,  
			'/Name/' path,
			@OpType op,
			'string' "from"
	from v_RCTBrokerInsertUpdate b
	where aa.RCTBrokerId = b.RCTBrokerId
	union all
	select b.AddressLine value,  
			'/Address/AddressLine/' path,
			@OpType op,
			'string' "from"
	from v_RCTBrokerInsertUpdate b
	where aa.RCTBrokerId = b.RCTBrokerId
	union all
	select b.City value,  
			'/Address/City/' path,
			@OpType op,
			'string' "from"
	from v_RCTBrokerInsertUpdate b
	where aa.RCTBrokerId = b.RCTBrokerId
	union all
	select convert(varchar, b.Province) value,  
			'/Address/ProvinceId/' path,
			@OpType op,
			'string' "from"
	from v_RCTBrokerInsertUpdate b
	where aa.RCTBrokerId = b.RCTBrokerId
	union all
	select b.ZipCode value,  
			'/Address/PostalCode/' path,
			@OpType op,
			'string' "from"
	from v_RCTBrokerInsertUpdate b
	where aa.RCTBrokerId = b.RCTBrokerId
	union all
	select b.Phone value,  
			'/Phone/' path,
			@OpType op,
			'string' "from"
	from v_RCTBrokerInsertUpdate b
	where aa.RCTBrokerId = b.RCTBrokerId
	) a
	for JSON PATH, INCLUDE_NULL_VALUES) As JSONData
	from [Sandbox].[dbo].[v_RCTBrokerInsertUpdate] aa
	where aa.RCTBrokerId = @BrokerRCTId)
--		Print @postData


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'PATCH', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res

	--	DELETE from @ResponseHeader
	--	SET TEXTSIZE 2147483647
	--  delete from @ResponseHeader
	--	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'
	--	select responseHeader FROM @ResponseHeader


	-- Handle the response.
	--	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	--	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	--	SET TEXTSIZE 2147483647
	--  delete from @ResponseText
	--	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--	PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--	SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	--select @ResponseJSON = responseText
	--from @responseText

	/*
	select json_value([Value], '$."Id"') JsonValue, 
			json_value([Value], '$."FieldName"') JsonName, 
			[value]
	from openjson(@ResponseJSON)
	*/



end



	FETCH NEXT FROM insert_update_brokers   
	INTO @BrokerIMSId, @BrokerRCTId, @BrokerName, @BrokerAddressLine, @BrokerCity, @BrokerProvince, @BrokerZipCode, @BrokerPhone

END

CLOSE insert_update_brokers;  
DEALLOCATE insert_update_brokers; 



--  Get Companies (Brokers)



set @PageNumber = 1


truncate table [Sandbox].[dbo].[RCTCompanies]

-- Loop thru and increment @PageNumber until @@Rowcount = 1

While @PageNumber is not NULL

Begin

	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/companies?OrderBy=Address.City%2CAddress.AddressLine&PageNumber=' + convert(varchar, @PageNumber) +'&PageSize=100&Lang=en'

	delete from @responseText
	set @ResponseJSON = ''
	set @postData = ''

	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	select @ResponseJSON = responseText
	from @responseText

	insert into [Sandbox].[dbo].[RCTCompanies]
	select value,
		   json_value([Value], '$."Id"') CompanyId, 
		   json_value([Value], '$."Type"') CompanyTypeId, 
		   json_value([Value], '$."Name"') CompanyName
--	into [Sandbox].[dbo].[RCTCompanies]
	from openjson(@ResponseJSON)

	if @@ROWCOUNT > 0
		set @PageNumber = @PageNumber + 1
	else
		set @PageNumber = NULL
    

end



--------------------------------------------

--  Insert/Update Broker Contact Info (add and update Users)

DECLARE @BrokerContactIMSId			nvarchar(100)
DECLARE @BrokerContactRCTId			nvarchar(100)
DECLARE @BrokerContactName			nvarchar(100)
DECLARE @BrokerContactBrokerRCTId	nvarchar(100)
DECLARE @BrokerContactEmail			nvarchar(100)
DECLARE @BrokerContactPhone			nvarchar(100)

DECLARE @BrokerFirstContactName		nvarchar(100)
DECLARE @BrokerLastContactName		nvarchar(100)

DECLARE insert_update_broker_contacts CURSOR FOR
select convert(nvarchar(36), IMSProducerContactID) IMSProducerContactID,
       RCTBrokerContactID,
       RCTBrokerID,
       ContactName,
	   ContactEmail,
	   ContactPhone
from [Sandbox].[dbo].[v_RCTBrokerContactInsertUpdate]
--where RCTBrokerContactID = '1662988644967567304'

OPEN insert_update_broker_contacts  
  
FETCH NEXT FROM insert_update_broker_contacts   
INTO @BrokerContactIMSId, @BrokerContactRCTId, @BrokerContactBrokerRCTId, @BrokerContactName, @BrokerContactEmail, @BrokerContactPhone


WHILE @@FETCH_STATUS = 0  
BEGIN  


if @BrokerContactRCTId is NULL  -- Add New Broker Contact
begin

	SET @contentType = 'application/json';

	select @BrokerFirstContactName	= b.Fname,
		   @BrokerLastContactName	= b.Lname
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblProducerContacts b
	where @BrokerContactIMSId = b.ProducerContactGUID

	-- MH 6/28/2022 - To move sessionid to header
	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/users?Lang=en'


/*
{
	"UserRoleType": "Broker",
	"Name": {
		"NameType": "Individual",
		"FirstName": "Connor",
		"LastName": "Baker"
	},
	"CompanyId": "1662739908813220687",
	"UseCompanyAddress": true,
	"ExternalUniqueId": "9BFCC0CE-50AC-421A-A720-5D87F0027BF4",
	"ContactNumber": "9BFCC0CE-50AC-421A-A720-5D87F0027BF4",
	"Phone": "516-279-9621",
	"Email": "Connor.Baker@alliant.com"
}
*/


	--Print @URL

	set @postData = '{
					  "UserRoleType": "Broker",
					  "Name": {
						"NameType": "Individual",
						"FirstName": "' + @BrokerFirstContactName  + '", 
						"LastName": "' + @BrokerLastContactName  + '"
					  },
					  "CompanyId": "' + @BrokerContactBrokerRCTId + '", 
					  "UseCompanyAddress": true,
					  "ExternalUniqueId": "' + @BrokerContactIMSId + '", 
					  "ContactNumber": "' + @BrokerContactIMSId + '", 
					  "Phone": "' + IsNull(@BrokerContactPhone, '') + '", 
					  "Email": "' + IsNull(@BrokerContactEmail, '') + '"
					}'
	--Print @postData


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'POST', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res

/*	
	DELETE from @ResponseHeader
	SET TEXTSIZE 2147483647
	delete from @ResponseHeader
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'

	
	select ResponseHeader,
		   substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)) location,
		   substring(substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)), 
					 len(substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10))) - 22, 
					 23) RCTAccountID
	from @ResponseHeader
*/	

--  Get the newly created RCTId

/*

	select @RctID = substring(locationURL, charindex('accounts/', locationURL) + 9, len(locationURL) - charindex('accounts/', locationURL) + 9)
	from (
	select substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, 
					 (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)) locationURL
	from @ResponseHeader) aaa





	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText

*/

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	--select @ResponseJSON = responseText
	--from @responseText

	/*
	select json_value([Value], '$."Id"') JsonValue, 
		   json_value([Value], '$."FieldName"') JsonName, 
		   [value]
	from openjson(@ResponseJSON)
	*/

end

else -- Replace Existing Broker Contact
begin

	select @BrokerFirstContactName	= b.Fname,
		   @BrokerLastContactName	= b.Lname
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblProducerContacts b
	where @BrokerContactIMSId = b.ProducerContactGUID



	SET @contentType = 'application/json';

	set @OpType		= 'add'  --replace doesn't seem to work, maybe because there are multiple fields being replaced
								--add does a replace anyway

	-- MH 6/28/2022 - To move sessionid to header
	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/users/' + @BrokerContactRCTId + '?Lang=en'
--	Print @URL

	

	--  Step 1 - Update all Fields

	set @postData = (
		select 
	(
	select a.*
	from (
	select @BrokerFirstContactName value,  
			'/Name/FirstName/' path,
			@OpType op,
			'string' "from"
	from v_RCTBrokerContactInsertUpdate b
	where aa.RCTBrokerContactId = b.RCTBrokerContactId
	union all
	select @BrokerLastContactName value,  
			'/Name/LastName/' path,
			@OpType op,
			'string' "from"
	from v_RCTBrokerContactInsertUpdate b
	where aa.RCTBrokerContactId = b.RCTBrokerContactId
	union all
	select b.ContactPhone value,  
			'/Phone/' path,
			@OpType op,
			'string' "from"
	from v_RCTBrokerContactInsertUpdate b
	where aa.RCTBrokerContactId = b.RCTBrokerContactId
	union all
	select b.ContactEmail value,  
			'/Email/' path,
			@OpType op,
			'string' "from"
	from v_RCTBrokerContactInsertUpdate b
	where aa.RCTBrokerContactId = b.RCTBrokerContactId
	) a
	for JSON PATH, INCLUDE_NULL_VALUES) As JSONData
	from [Sandbox].[dbo].[v_RCTBrokerContactInsertUpdate] aa
	where aa.RCTBrokerContactId = @BrokerContactRCTId)
--		Print @postData


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'PATCH', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res

	--	DELETE from @ResponseHeader
	--	SET TEXTSIZE 2147483647
	--  delete from @ResponseHeader
	--	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'
	--	select responseHeader FROM @ResponseHeader


	-- Handle the response.
	--	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	--	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	--	SET TEXTSIZE 2147483647
	--  delete from @ResponseText
	--	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--	PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--	SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	--select @ResponseJSON = responseText
	--from @responseText

	/*
	select json_value([Value], '$."Id"') JsonValue, 
			json_value([Value], '$."FieldName"') JsonName, 
			[value]
	from openjson(@ResponseJSON)
	*/



end



	FETCH NEXT FROM insert_update_broker_contacts   
	INTO @BrokerContactIMSId, @BrokerContactRCTId, @BrokerContactBrokerRCTId, @BrokerContactName, @BrokerContactEmail, @BrokerContactPhone

END

CLOSE insert_update_broker_contacts;  
DEALLOCATE insert_update_broker_contacts; 

--------------------------------


--  Get Users


SET @contentType = 'application/json';


set @PageNumber = 1



truncate table [Sandbox].[dbo].[RCTUsers]

-- Loop thru and increment @PageNumber until @@Rowcount = 1

While @PageNumber is not NULL

Begin


-- MH 6/28/2022 - To move sessionid to header
	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/users?OrderBy=Name&PageNumber=' + convert(varchar, @PageNumber) +'&PageSize=100&Lang=en'
	
	--Print @URL


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647

	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);


	--SELECT @status, responseText FROM @responseText

	select @ResponseJSON = responseText
	from @responseText

	insert into [Sandbox].[dbo].[RCTUsers]
	select json_value([Value], '$."Id"') UserId, 
		   json_value([Value], '$."Name"') UserName, 
		   json_value([Value], '$."Email"') Email, /*
		   case when json_value(json_query([Value], '$."Company"'), '$."Name"')  = 'Gramercy Underwriters'
				then 1 end IsUnderwriter, */
		   case when json_value(json_query([Value], '$."UserType"'), '$."Caption"')  = 'Underwriter'
				then 1 end IsUnderwriter,
		   case when json_value(json_query([Value], '$."UserType"'), '$."Caption"')  = 'Inspector'
				then 1 end IsRiskManager,/*
		   case when json_value(json_query([Value], '$."UserType"'), '$."Caption"')  = 'Risk Management Professional '
				then 1 end IsRiskManager,*/
	--       json_value(json_query([Value], '$."UserType"'), '$."Caption"') UserType, 
		   [value]
	--into [Sandbox].[dbo].[RCTUsers]
	from openjson(@ResponseJSON)
	--where json_value(json_query([Value], '$."UserType"'), '$."Caption"') = 'User'



	if @@ROWCOUNT > 0
		set @PageNumber = @PageNumber + 1
	else
		set @PageNumber = NULL
    
end



------------------------------

DECLARE @LocationID		int

DECLARE @SubCosts			int
DECLARE @TotalPremium		int
DECLARE @UnderwriterID		nvarchar(100)
DECLARE @UnderwriterEmail	nvarchar(100)
DECLARE @ConsultantID		nvarchar(100)
DECLARE @CustomAssigneeID	nvarchar(100)
DECLARE @BrokerID			nvarchar(100)
DECLARE @AgencyID			nvarchar(100)
DECLARE @PolicyNumber		nvarchar(100)

DECLARE @TaskID				nvarchar(100)

DECLARE @DocTypeID				nvarchar(10)


DECLARE @PathToFile				nvarchar(1000)
DECLARE @FileDesc				nvarchar(1000)
DECLARE @FileType				nvarchar(100)
DECLARE @EffectiveDate			date
DECLARE @LastESISCompletedDate	date
DECLARE @LastRTCompletedDate	date
DECLARE @TaskType				nvarchar(10)
DECLARE @TaskTypeID				int
DECLARE @DateCompleted			date

DECLARE @DocumentStoreGUID		varchar(max)
DECLARE @SQL					nvarchar(500)




--  Begin Daily account load



DECLARE load_account CURSOR FOR

select a.InsuredId,
       b.RCTId
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a
     left join [Sandbox].[dbo].[RCTAccounts] b
	   on a.InsuredId = b.IMSId
--where a.InsuredID in (121, 3913) 
where not exists (select 1
				  from [Sandbox].[dbo].[RCTAccounts] bb
				  where a.InsuredId = bb.IMSId
--				    and a.PolicyNumber = bb.PolicyNumber
					and a.EffectiveDate <= bb.EffectiveDate)
  and a.EffectiveDate > dateadd(d, -366, convert(date, GetDate()))
--  and convert(date, a.EffectiveDate) >= '9/19/2022'


/*  For a full update
select a.InsuredId,
       b.RCTId
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a,
     [Sandbox].[dbo].[RCTAccounts] b
where a.InsuredId = b.IMSId
*/


/*  MH  10/12/2022 - Didn't work when a GL policy came AFTER a Package policy

select a.InsuredId,
       b.RCTId
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a
     left join [Sandbox].[dbo].[RCTAccounts] b
	   on a.InsuredId = b.IMSId
--where a.InsuredID in (3921, 3913) /*
where not exists (select 1
				  from [Sandbox].[dbo].[RCTAccounts] bb
				  where a.InsuredId = bb.IMSId
				    and a.PolicyNumber = bb.PolicyNumber) --*/
  and a.EffectiveDate > dateadd(d, -366, convert(date, GetDate()))
--  and convert(date, a.EffectiveDate) >= '9/19/2022'

*/


OPEN load_account  
  
FETCH NEXT FROM load_account   
INTO @IMSID, @RctID


WHILE @@FETCH_STATUS = 0  
BEGIN  

--  First check if the account exists in RCT


if @RctID is not NULL

begin

--  Update the existing account

	SET @contentType = 'application/json';


	set @OpType		= 'add'  --replace doesn't seem to work, maybe because there are multiple fields being replaced
								--add does a replace anyway


	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/accounts/patchV2/' + @RCTID
	--	Print @URL

	

	--  Step 1 - Update the Major Fields

	set @postData = (
	select 
	(
	select a.*
	from (
	select max(u.UserId) value,  
			'/UnderwriterId/' path,
			@OpType op,
			'string' "from"
	from [Sandbox].[dbo].[RCTUsers] u
	where aa.UnderwriterEmail = u.Email
		and u.IsUnderwriter = 1
	union all
	select case when left(aa.InsuredPolicyName, 1) < 'I'
				then (select max(u.UserId)
						from [Sandbox].[dbo].[RCTUsers] u
						where 'anelson@gramercyrisk.com' = u.Email
						and u.IsRiskManager = 1)
	/* PB 1/23/2023 Assigning all accounts with insured policy name First letter greater than H to Will keller
				when left(aa.InsuredPolicyName, 1) < 'Q'
				then (select max(u.UserId)
						from [Sandbox].[dbo].[RCTUsers] u
						where 'wkeller@gramercyrisk.com' = u.Email
						and u.IsRiskManager = 1)
				else (select max(u.UserId)
						from [Sandbox].[dbo].[RCTUsers] u
						where 'rbambino@gramercyrisk.com' = u.Email
						and u.IsRiskManager = 1) end value,*/
				else (select max(u.UserId)
						from [Sandbox].[dbo].[RCTUsers] u
						where 'wkeller@gramercyrisk.com' = u.Email
						and u.IsRiskManager = 1) end value,
			'/ConsultantId/' path,
			@OpType op,
			'string' "from"
	union all
	select b.Id value,  
			'/MailingAddress/ProvinceId/' path,
			@OpType op,
			'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a,
			[Sandbox].[dbo].[RCTProvinces] b
	where a.InsuredID = @IMSID
		and a.State = b.Code
	union all
	select Address1 + ' ' + IsNull(Address2, '') value,  
			'/MailingAddress/AddressLine/' path,
			@OpType op,
			'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a
	where a.InsuredID = @IMSID
	union all
	select City value,  
			'/MailingAddress/City/' path,
			@OpType op,
			'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a
	where a.InsuredID = @IMSID
	union all
	select ZipCode value,  
			'/MailingAddress/PostalCode/' path,
			@OpType op,
			'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a
	where a.InsuredID = @IMSID
	union all
	select InsuredPolicyName value,  
			'/Name' path,
			@OpType op,
			'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a
	where a.InsuredID = @IMSID
	union all
--  MH  10/14/2022 - Change Contact Number from InsuredID to Policy Number
--	select convert(varchar, InsuredID) value,  
	select PolicyNumber value,  
			'/ContactNumber/' path,
			@OpType op,
			'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a
	where a.InsuredID = @IMSID
	union all
	select RCTBrokerId value,  
			'/AgencyId/' path,
			@OpType op,
			'string' "from"
	from [Sandbox].[dbo].[v_RCTBrokers] aaa
	where trim(aa.Broker) = trim(aaa.BrokerName)
	) a
	for JSON PATH, INCLUDE_NULL_VALUES) As JSONData
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID)
--		Print @postData


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'PATCH', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res

	--	DELETE from @ResponseHeader
	--	SET TEXTSIZE 2147483647
	--  delete from @ResponseHeader
	--	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'
	--	select responseHeader FROM @ResponseHeader


	-- Handle the response.
	--	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	--	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	--	SET TEXTSIZE 2147483647
	--  delete from @ResponseText
	--	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--	PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--	SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	--select @ResponseJSON = responseText
	--from @responseText

	/*
	select json_value([Value], '$."Id"') JsonValue, 
			json_value([Value], '$."FieldName"') JsonName, 
			[value]
	from openjson(@ResponseJSON)
	*/


--  Step 2 - Update the Extension Fields

	set @postData = (
	select (
	select a.*
	from (
	select 5 [value.Id],  
		   convert(varchar, IsNull(format(TotalPremium, 'C'), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 10 [value.Id],  
		   PolicyNumber [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 22 [value.Id],  
		   InspectionContactName [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 24 [value.Id],  
		   InspectionContactPhone [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 25 [value.Id],  
		   InspectionContactEmail [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 31 [value.Id],  
		   ProducerContactName [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 32 [value.Id],  
		   ProducerContactPhone [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 33 [value.Id],  
		   ProducerContactEmail [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 95 [value.Id],  
		   convert(nvarchar, EffectiveDate, 101) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 96 [value.Id],  
		   convert(nvarchar, ExpirationDate, 101) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID 
	union all
	select 97 [value.Id],  
		   ContractorType [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 125 [value.Id],  
		   convert(varchar, IsNull(format(TotalSubCosts, 'C'), format(0, 'C'))) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 133 [value.Id],  
		   aa.Broker [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 138 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLinePrevTermLossRatioData] aa
	where aa.InsuredID = @IMSID
	union all
	select 139 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLine5YearLossRatioData] aa
	where aa.InsuredID = @IMSID
	union all
	select 140 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLinePrevTermLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName = 'Commercial General Liability'
	union all
	select 141 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLine5YearLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName = 'Commercial General Liability'
	union all
	select 142 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLinePrevTermLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName = 'Commercial Property'
	union all
	select 143 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLine5YearLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName = 'Commercial Property'
	union all
	select 144 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLinePrevTermLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName = 'Commercial Crime'
	union all
	select 145 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLine5YearLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName = 'Commercial Crime'
	union all
	select 146 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLinePrevTermLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName = 'Commercial Inland Marine'
	union all
	select 147 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLine5YearLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName = 'Commercial Inland Marine'
	union all
	select 148 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLinePrevTermLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName in ('Commercial Auto Liability', 'Commercial Auto PD')
	union all
	select 149 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLine5YearLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName in ('Commercial Auto Liability', 'Commercial Auto PD')
	union all
	select 150 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLinePrevTermLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName = 'Umbrella'
	union all
	select 151 [value.Id],  
		   convert(varchar, IsNull(round(sum(IncurredLoss) / sum(EP), 4), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[v_RCTPolicyLine5YearLossRatioData] aa
	where aa.InsuredID = @IMSID
	  and aa.LineName = 'Umbrella'
	union all 
	select 153 [value.Id],  
		   convert(varchar, IsNull(format(PropertyLimit, 'C'), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all 
	select 158 [value.Id],  
		   convert(varchar, IsNull(format(BuildingLimit, 'C'), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all 
	select 160 [value.Id],  
		   convert(varchar, IsNull(format(ContentsLimit, 'C'), 0)) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID

-- PB 11/4/2022 - Added writing Producer Contact information - Not Live Yet
	union all
	select 175 [value.Id],  
		   WritingProducerContactName [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 176 [value.Id],  
		   WritingProducerContactPhone [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	union all
	select 177 [value.Id],  
		   WritingProducerContactEmail [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID

	


/*  MH  9/22/2022 - Don't need this for prod since the fields will be loaded during initial load process
	union all 
	select 172 [value.Id],  
		   convert(nvarchar, ESISCompletedDate, 101) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[RCTCompletedDates] aa
	where aa.IMSId = @IMSID
	union all 
	select 173 [value.Id],  
		   convert(nvarchar, RTCompletedDate, 101) [value.Value],
		   '/ExtensionFields/-' path,
		   @OpType op,
		   'string' "from"
	from [Sandbox].[dbo].[RCTCompletedDates] aa
	where aa.IMSId = @IMSID*/) a
	for JSON PATH, INCLUDE_NULL_VALUES) As JSONData
	)
--	Print @postData

	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'PATCH', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res

--	DELETE from @ResponseHeader
--	SET TEXTSIZE 2147483647
--  delete from @ResponseHeader
--	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'
--	select responseHeader FROM @ResponseHeader


	-- Handle the response.
--	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
--	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
--	SET TEXTSIZE 2147483647
--  delete from @ResponseText
--	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
--	PRINT 'Status: ' + @status + ' (' + @statusText + ')';
--	SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	--select @ResponseJSON = responseText
	--from @responseText

	/*
	select json_value([Value], '$."Id"') JsonValue, 
		   json_value([Value], '$."FieldName"') JsonName, 
		   [value]
	from openjson(@ResponseJSON)
	*/




--  Step 3 - Update the Location

	select @LocationID = (select json_value(value, '$.Location.Id') LocationId
						  from [Sandbox].[dbo].[RCTAccounts]
						  where IMSId = @IMSID)

	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/locations/' + convert(nvarchar, @LocationID) + '?Lang=en'
--	print @URL

	set @postData = (
	select 
	(
	select a.*
	from (
	select b.Id value,  
		   '/Address/ProvinceId/' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a,
	     [Sandbox].[dbo].[RCTProvinces] b
	where a.InsuredID = @IMSID
	  and a.State = b.Code
	union all
	select Address1 + ' ' + IsNull(Address2, '') value,  
		   '/Address/AddressLine/' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a
	where a.InsuredID = @IMSID
	union all
	select City value,  
		   '/Address/City/' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a
	where a.InsuredID = @IMSID
	union all
	select ZipCode value,  
		   '/Address/PostalCode/' path,
		   @OpType op,
		   'string' "from"
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a
	where a.InsuredID = @IMSID
	) a
	for JSON PATH, INCLUDE_NULL_VALUES) As JSONData
	from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] aa
	where aa.InsuredID = @IMSID
	)
--	Print @postData

	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'PATCH', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res

--	DELETE from @ResponseHeader
--	SET TEXTSIZE 2147483647
--  delete from @ResponseHeader
--	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'
--	select responseHeader FROM @ResponseHeader


	-- Handle the response.
--	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
--	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
--	SET TEXTSIZE 2147483647
--  delete from @ResponseText
--	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
--	PRINT 'Status: ' + @status + ' (' + @statusText + ')';
--	SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	--select @ResponseJSON = responseText
	--from @responseText

	/*
	select json_value([Value], '$."Id"') JsonValue, 
		   json_value([Value], '$."FieldName"') JsonName, 
		   [value]
	from openjson(@ResponseJSON)
	*/

end
else
begin

-- Post the new account


	SET @contentType = 'application/json';

	-- MH 6/28/2022 - To move sessionid to header
	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/accounts'
	--Print @URL

	set @postData = (select JSONData
					 from [Sandbox].[dbo].[v_RCTAccountJSONData]
					 where InsuredID = @IMSId)
	--Print @postData


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'POST', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res

	DELETE from @ResponseHeader
	SET TEXTSIZE 2147483647
	delete from @ResponseHeader
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'

/*	
	select ResponseHeader,
		   substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)) location,
		   substring(substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)), 
					 len(substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10))) - 22, 
					 23) RCTAccountID
	from @ResponseHeader
*/	

--  Get the newly created RCTId

	select @RctID = substring(locationURL, charindex('accounts/', locationURL) + 9, len(locationURL) - charindex('accounts/', locationURL) + 9)
	from (
	select substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, 
					 (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)) locationURL
	from @ResponseHeader) aaa





	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	--select @ResponseJSON = responseText
	--from @responseText

	/*
	select json_value([Value], '$."Id"') JsonValue, 
		   json_value([Value], '$."FieldName"') JsonName, 
		   [value]
	from openjson(@ResponseJSON)
	*/


end

--  Update/load account information to RCTAccounts table


delete from [Sandbox].[dbo].[RCTAccounts]
where IMSId = @IMSID

set @URL = 'https://rdi6.riskcontrol.expert/gramercy/api/accounts/' + @RctID

-- Open the connection.
EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
--Print @token
IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

-- Send the request.
EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
--set a custom header Authorization is the header key and VALUE is the value in the header
--PRINT @authHeader
--PRINT @res
--PRINT @contentType
--PRINT @res
EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
--PRINT @res
EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

-- Handle the response.
EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
SET TEXTSIZE 2147483647
delete from @ResponseText
INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

-- Show the response.
--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
--SELECT @status, responseText FROM @responseText

-- Close the connection.
EXEC @res = sp_OADestroy @token;
IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

insert into [Sandbox].[dbo].[RCTAccounts]
select responseText,
		json_value(responseText, '$."Id"') RCTId,
		json_value(responseText, '$."ExternalUniqueId"') IMSId, 
		json_value(responseText, '$."Name"') InsuredName, /*
		json_value(json_query(responseText, '$."MailingAddress"'), '$."AddressLine"') AddressLine,
		json_value(json_query(responseText, '$."MailingAddress"'), '$."City"') City,
		json_value(json_query(json_query(responseText, '$."MailingAddress"'), '$."Province"'), '$."Code"') StateCode,
		json_value(json_query(responseText, '$."MailingAddress"'), '$."PostalCode"') PostalCode,
--	   json_query([Value], '$."ExtensionFields"') ExtensionFields, */
		(select json_value(Value, '$."Value"') Value
		from openjson(json_query(responseText, '$."ExtensionFields"'))
		where json_value(Value, '$."Id"') = 10) PolicyNumber,
		convert(date,
		(select json_value(Value, '$."Value"') Value
		from openjson(json_query(responseText, '$."ExtensionFields"'))
		where json_value(Value, '$."Id"') = 95)) EffectiveDate/*,
		(select json_value(Value, '$."Value"') Value
		from openjson(json_query([Value], '$."ExtensionFields"'))
		where json_value(Value, '$."Id"') = 5) TotalPremium,
		(select json_value(Value, '$."Value"') Value
		from openjson(json_query([Value], '$."ExtensionFields"'))
		where json_value(Value, '$."Id"') = 22) InspectionContactName */
--	into [Sandbox].[dbo].[RCTAccounts]
from @responseText




--  Now create the tasks

 --  Comment/Uncomment to run


--  Post new Tasks (Field Assignment and Risk Transfer)

SET @contentType = 'application/json';


set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/tasks?Lang=en'
--Print @URL




select  @SubCosts			= IsNull(a.TotalSubCosts, 0),
		@TotalPremium		= IsNull(a.TotalPremium, 0),
		@PolicyNumber		= a.PolicyNumber,
		@TaskType			= case when right(a.PolicyNumber, 2) = '00'
								   then '2311'
								   else '2314' end,
		@UnderwriterEmail	= a.UnderwriterEmail,
		@LocationID			=  (select json_value(Location, '$.Id')
								from (
								select json_query(aa.value, '$.Location') Location
								from [Sandbox].[dbo].[RCTAccounts] aa
								where aa.IMSId = @IMSId) aa),
		@UnderwriterID		= (select json_value(value, '$.Underwriter.Id')
								from [Sandbox].[dbo].[RCTAccounts] aa
								where aa.IMSId = @IMSId), /*
		@ConsultantID		= (select json_value(value, '$.Consultant.Id')
								from [Sandbox].[dbo].[RCTAccounts] aa
								where aa.IMSId = @IMSId), */
		@ConsultantID		= (select UserId
								from RCTUsers
								where json_value(value, '$.IsArchived') = 'false'
								  and json_value(value, '$.UserType.Caption') = 'Inspector'
								  and UserName = 'Unassigned'),
		@AgencyID			= (select RCTBrokerId
								from [Sandbox].[dbo].[v_RCTBrokers] aa
								where trim(aa.BrokerName) = trim(a.Broker)), /*
		@BrokerID			= (select min(bb.UserId)
								from [Sandbox].[dbo].[v_RCTBrokers] aa,
									 [Sandbox].[dbo].[RCTUsers] bb
								where trim(aa.BrokerName) = trim(a.Broker)
								  and aa.RCTBrokerID = json_value(bb.value, '$.Company.Id')), */
        @BrokerID			= (select max(u.UserId)
								 from [Sandbox].[dbo].[RCTUsers] u
								 where u.Email = a.ProducerContactEmail
								   and json_value(u.value, '$.UserType.Caption') = 'Broker'
								 ),
        @CustomAssigneeID	= (select case when left(a.InsuredPolicyName, 1) < 'I'
										   then (select max(u.UserId)
												 from [Sandbox].[dbo].[RCTUsers] u
												 where json_value(value, '$.IsArchived') = 'false'
												   and json_value(value, '$.UserType.Caption') = 'Risk Management Professional '
												   and 'anelson@gramercyrisk.com' = u.Email)
  /* PB 1/23/2023 Assigning all accounts with insured policy name First letter greater than H to Will keller
										   when left(a.InsuredPolicyName, 1) < 'Q'
										   then (select max(u.UserId)
												 from [Sandbox].[dbo].[RCTUsers] u
												 where json_value(value, '$.IsArchived') = 'false'
												   and json_value(value, '$.UserType.Caption') = 'Risk Management Professional '
												   and 'wkeller@gramercyrisk.com' = u.Email)
										   else (select max(u.UserId)
												 from [Sandbox].[dbo].[RCTUsers] u
												 where json_value(value, '$.IsArchived') = 'false'
												   and json_value(value, '$.UserType.Caption') = 'Risk Management Professional '
												   and 'rbambino@gramercyrisk.com' = u.Email) end) */
											else (select max(u.UserId)
												 from [Sandbox].[dbo].[RCTUsers] u
												 where json_value(value, '$.IsArchived') = 'false'
												   and json_value(value, '$.UserType.Caption') = 'Risk Management Professional '
												   and 'wkeller@gramercyrisk.com' = u.Email) end)
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_RCTLoadDataCurr] a
where InsuredID = @IMSID

select @LastESISCompletedDate	= [Last ESIS Visit Completed],
       @LastRTCompletedDate		= [Last RT Revised Agreement]
from [Sandbox].[dbo].[v_RCTAccounts] a
where a.IMSId = @IMSID

/*
-- For Testing
set @LastESISCompletedDate	=  '10/1/2022'
set @LastRTCompletedDate	=  '10/1/2022'
*/


/*
print @SubCosts
print @TotalPremium
print @UnderwriterID
print @UnderwriterEmail
print @ConsultantID
print @BrokerID
print @AgencyID
print @CustomAssigneeID
*/



if @TotalPremium >= 150000 and IsNull(@LastESISCompletedDate, '1/1/2000') < dateadd(yyyy, -3, convert(date, GetDate())) -- If we haven't completed one in the last 3 years

begin


set @postData = '{
				  "TaskStatusId": 2642,
				  "TaskTypeId": 2648,
				  "ExternalUniqueId": "' + @PolicyNumber + '2648' + '",
				  "AccountId": "' + @RctID + '", ' +
				  case when @UnderwriterID is NULL
				       then 
				  '"UnderwriterId": null,'
				       else
				  '"UnderwriterId": "' + @UnderwriterID + '",' end +
				  '"ConsultantId": "' + @ConsultantID + '",
				  "BrokerId": "' + @BrokerID + '",
				  "LocationId": ' + convert(varchar, @LocationID) + ',
				  "ExtensionFields": [
					{
					  "Id": 1,
					  "Value": ' + @TaskType + ',
					}
				  ], 
				  "PolicyNumber": "' + @PolicyNumber + '",
				  "Description": null,
				  "AgencyId": "' + @AgencyId + '",
				  "CustomAssigneeId": "' + @CustomAssigneeID + '",
				  "WritingCompanyId": null,
				  "RegionId": null,
				  "Notes": null,
				  "PriorityId": 100,
				  "DateRequired": "'+ convert(nvarchar, dateadd(d, 45, GetDate()), 101) +'",
				}'


--	Print @postData


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'POST', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res

	DELETE from @ResponseHeader
	SET TEXTSIZE 2147483647
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'

	--  Get the TaskId to use later to attach documents

/*
	select *
	from @ResponseHeader
*/

	select @TaskID = substring(locationURL, charindex('tasks/', locationURL) + 6, len(locationURL) - charindex('accounts/', locationURL) + 9)
	from (
	select substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, 
					 (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)) locationURL
	from @ResponseHeader) aaa

--	print @TaskID

/*

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText
*/

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

/*
	select @ResponseJSON = responseText
	from @responseText

	
	select json_value([Value], '$."Id"') JsonValue, 
		   json_value([Value], '$."FieldName"') JsonName, 
		   [value]
	from openjson(@ResponseJSON)
	
*/


--  Attach Documents to the task

	SET @contentType	= 'multipart/form-data'
	SET @DocTypeID      = ''

	select @EffectiveDate = EffectiveDate
	from [Sandbox].[dbo].[RCTAccounts]
	where RCTId = @RctID



	DECLARE attachment_cursor CURSOR FOR
	select a.DocumentStoreGUID, a.Description, 'E:\PDFExport\Extract\' + a.FileName, FileType, 
		   case when a.FolderName in ('Prior Carrier Loss Runs', 'Gramercy Loss Runs')
				then 2667
				when a.FolderName = 'Gramercy Application'
				then 2670
				when a.FolderName = 'Applications'
				then 2669
				when a.FolderName = 'Safety Manual'
				then 2668
	--  Update with WIP logic
				else 2677 end DocType
	from [MGADS0005.NY.MGASYSTEMS.COM].GramercyRisk.ReportReference.v_RCTAttachments a
	where a.InsuredID = @IMSID
	  and a.PolicyEffectiveDate = @EffectiveDate
	order by a.FolderName, a.DocumentStoreGuid

	OPEN attachment_cursor  
  
	FETCH NEXT FROM attachment_cursor   
	INTO @DocumentStoreGUID, @FileDesc, @PathToFile, @FileType, @DocTypeID

	

	WHILE @@FETCH_STATUS = 0  
	BEGIN  

		set @PathToFile = replace(
						  replace(
						  replace(@PathToFile, ',', ''), 
						  '''', ''), 
						  ';', '')
		set @FileDesc	= replace(
						  replace(
						  replace(
						  replace(@FileDesc, '''', ''''''), 
						  '(', ' '), 
						  ')', ' '), 
						  ';', ' ')
	--	PRINT @PathToFile
	 
		SET @SQL
			= N'master.dbo.xp_cmdshell ''BCP "select a.Document from [MGADS0005.NY.MGASYSTEMS.COM].GramercyRisk.dbo.tblDocumentStore a where a.DocumentStoreGUID = ''''' + @DocumentStoreGUID + '''''" queryout E:\PDFExport\File.zip -T -f E:\PdfExport\bcpfile.fmt''';
		--PRINT @SQL
		EXEC sp_executesql @SQL

		set @SQL
			= N'EXEC master..xp_cmdshell ''tar -xf E:\PDFExport\File.zip  -C E:\PDFExport\Extract'''

		--PRINT @SQL

		EXEC sp_executesql @SQL

	
		set @SQL
			= N'EXEC master..xp_cmdshell ''E:\PDFExport\removechars.bat'''

		--PRINT @SQL
		EXEC sp_executesql @SQL


  -- Uncomment to run


		set @CurlCommand = N'EXEC master..xp_cmdshell ''curl -X POST "https://rdi6.riskcontrol.expert/gramercy/api/tasks/' + 
										  @TaskID +
										  '/files?Lang=en" -H "accept: */*" -H "X-Version: 1.1" -H "X-XSRF-TOKEN: ' + 
										  @XXSRFTOKEN +
										  '" -H "Cookie: ' +
										  @SetCookie +
										  '" -H "Content-Type: multipart/form-data" -F "Description=' +
										  @FileDesc +
										  '" -F "DocTypeId=' +
										  @DocTypeID +
										  '" -F "File=@' +
										  @PathToFile +
										  ';type=' +
										  @FileType +
										  '"'''
	--	PRINT @CurlCommand


  --  Uncomment to run


		EXEC sp_executesql @CurlCommand

		FETCH NEXT FROM attachment_cursor   
		INTO @DocumentStoreGUID, @FileDesc, @PathToFile, @FileType, @DocTypeID

	END

	set @SQL
		= N'EXEC master..xp_cmdshell ''del /q E:\PDFExport\Extract\*.*'''

	--PRINT @SQL
	EXEC sp_executesql @SQL
 
	CLOSE attachment_cursor;  
	DEALLOCATE attachment_cursor;  



--  Add code to attach ESIS Field Assignment and UW Request Forms

	SET @contentType = 'application/json';

	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/tasks/' + @TaskID + '/forms?Lang=en'

--	print @URL

--  ESIS Field Assignment Form

	set @postData = '{
					  "FormTemplateId": "1659023258327275337",
					  "LocationId": "' + convert(varchar, @LocationID) + '",
					  "ExternalUniqueId": "1659023258327275337' + convert(varchar, @LocationID) + '",
					  "Description": "ESIS Field Assignment Form"
					}'

--    print @postData

		-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'POST', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
--	PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
--	PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
--	PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
--	PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
--	PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
--	PRINT @res

/*	
	DELETE from @responseText
	SET TEXTSIZE 2147483647
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'

	select *
	from @ResponseText

	DELETE from @ResponseHeader
	SET TEXTSIZE 2147483647
	delete from @ResponseHeader
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'

	--  Get the TaskId to use later to attach documents


	select @TaskID = substring(locationURL, charindex('tasks/', locationURL) + 6, len(locationURL) - charindex('accounts/', locationURL) + 9)
	from (
	select substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, 
					 (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)) locationURL
	from @ResponseHeader) aaa

--	print @TaskID


	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText
*/

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

/*
	select @ResponseJSON = responseText
	from @responseText

	
	select json_value([Value], '$."Id"') JsonValue, 
		   json_value([Value], '$."FieldName"') JsonName, 
		   [value]
	from openjson(@ResponseJSON)
	
*/





-- UW Request Form

	set @postData = '{
					  "FormTemplateId": "1658411812695447258",
					  "LocationId": "' + convert(varchar, @LocationID) + '",
					  "ExternalUniqueId": "1658411812695447258' + convert(varchar, @LocationID) + '",
					  "Description": "UW Request Form"
					}'

--    print @postData

		-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'POST', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res
/*
	DELETE from @responseText
	SET TEXTSIZE 2147483647
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	select *
	from @ResponseText



	DELETE from @ResponseHeader
	SET TEXTSIZE 2147483647
	delete from @ResponseHeader
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'

	--  Get the TaskId to use later to attach documents


	select @TaskID = substring(locationURL, charindex('tasks/', locationURL) + 6, len(locationURL) - charindex('accounts/', locationURL) + 9)
	from (
	select substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, 
					 (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)) locationURL
	from @ResponseHeader) aaa

--	print @TaskID


	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText
*/

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

/*
	select @ResponseJSON = responseText
	from @responseText

	
	select json_value([Value], '$."Id"') JsonValue, 
		   json_value([Value], '$."FieldName"') JsonName, 
		   [value]
	from openjson(@ResponseJSON)
	
*/



end

if @SubCosts >= 75000 and IsNull(@LastRTCompletedDate, '1/1/2000') = '1/1/2000' -- If we never completed one before

begin	

--  Reset after Attachments are loaded from Field Assignment above
	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/tasks?Lang=en'
	SET @contentType = 'application/json';
	set @postData = '{
				  "TaskStatusId": 2642,
				  "TaskTypeId": 2649,
				  "ExternalUniqueId": "' + @PolicyNumber + '2649' + '",
				  "AccountId": "' + @RctID + '", ' +
				  case when @UnderwriterID is NULL
				       then 
				  '"UnderwriterId": null,'
				       else
				  '"UnderwriterId": "' + @UnderwriterID + '",' end +
				  '"ConsultantId": "' + @ConsultantID + '",
				  "BrokerId": "' + @BrokerID + '",
				  "LocationId": ' + convert(varchar, @LocationID) + ',
				  "ExtensionFields": [
					{
					  "Id": 1,
					  "Value": ' + @TaskType + ',
					}
				  ], 
				  "PolicyNumber": "' + @PolicyNumber + '",
				  "Description": null,
				  "AgencyId": "' + @AgencyId + '",
				  "CustomAssigneeId": "' + @CustomAssigneeID + '",
				  "WritingCompanyId": null,
				  "RegionId": null,
				  "Notes": null,
				  "PriorityId": 100,
				  "DateRequired": "'+ convert(nvarchar, dateadd(d, 60, GetDate()), 101) +'",
				}'


--	Print @postData


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'POST', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res



	DELETE from @ResponseHeader
	SET TEXTSIZE 2147483647
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'

	--  Get the TaskId to use later to attach documents
/*	

	select *
	from @ResponseHeader

	*/

	select @TaskID = substring(locationURL, charindex('tasks/', locationURL) + 6, len(locationURL) - charindex('accounts/', locationURL) + 9)
	from (
	select substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, 
					 (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)) locationURL
	from @ResponseHeader) aaa

--	print @TaskID


/*
	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
--	SELECT @status, responseText FROM @responseText
*/

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

/*
	select @ResponseJSON = responseText
	from @responseText

	
	select json_value([Value], '$."Id"') JsonValue, 
		   json_value([Value], '$."FieldName"') JsonName, 
		   [value]
	from openjson(@ResponseJSON)
	
*/


--  Add code to attach Subcontractor Review Checklist

	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/tasks/' + @TaskID + '/forms?Lang=en'

--  ESIS Field Assignment Form

	set @postData = '{                   
					  "FormTemplateId": "1663592350895250082",
					  "LocationId": "' + convert(varchar, @LocationID) + '",
					  "ExternalUniqueId":  "1663592350895250082' + convert(varchar, @LocationID) + '",
					  "Description": "Subcontractor Review Checklist"
					}'

		-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'POST', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res

/*

	DELETE from @ResponseHeader
	SET TEXTSIZE 2147483647
	delete from @ResponseHeader
	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'

	--  Get the TaskId to use later to attach documents


	select @TaskID = substring(locationURL, charindex('tasks/', locationURL) + 6, len(locationURL) - charindex('accounts/', locationURL) + 9)
	from (
	select substring(ResponseHeader, charindex('Location:', ResponseHeader) + 10, 
					 (charindex('Server:', ResponseHeader) - 2) - (charindex('Location:', ResponseHeader) + 10)) locationURL
	from @ResponseHeader) aaa

--	print @TaskID


	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText
*/

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

/*
	select @ResponseJSON = responseText
	from @responseText

	
	select json_value([Value], '$."Id"') JsonValue, 
		   json_value([Value], '$."FieldName"') JsonName, 
		   [value]
	from openjson(@ResponseJSON)
	
*/


end

FETCH NEXT FROM load_account   
INTO @IMSID, @RctID

END


 
CLOSE load_account;  
DEALLOCATE load_account;  



--  End Daily account load


-------------------------------------------


--  Get all Accounts  PageSize = 100 is the max allowed value, PageNumber 1 = 1-100, 2 = 101-200, 3 = 201 - 300, etc

set @PageNumber = 1



truncate table [Sandbox].[dbo].[RCTAccounts]

-- Loop thru and increment @PageNumber until @@Rowcount = 1

While @PageNumber is not NULL

Begin

	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/accounts?OrderBy=Name&PageNumber=' + convert(varchar, @PageNumber) +'&PageSize=100&Lang=en'

	delete from @responseText
	set @ResponseJSON = ''
	set @postData = ''

	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	select @ResponseJSON = responseText
	from @responseText

	insert into [Sandbox].[dbo].[RCTAccounts]
	select value,
		   json_value([Value], '$."Id"') RCTId, 
		   json_value([Value], '$."ExternalUniqueId"') IMSId, 
		   json_value([Value], '$."Name"') InsuredName,/*
		   json_value(json_query([Value], '$."MailingAddress"'), '$."AddressLine"') AddressLine,
		   json_value(json_query([Value], '$."MailingAddress"'), '$."City"') City,
		   json_value(json_query(json_query([Value], '$."MailingAddress"'), '$."Province"'), '$."Code"') StateCode,
		   json_value(json_query([Value], '$."MailingAddress"'), '$."PostalCode"') PostalCode,
	--	   json_query([Value], '$."ExtensionFields"') ExtensionFields, */
		   (select json_value(Value, '$."Value"') Value
			from openjson(json_query([Value], '$."ExtensionFields"'))
			where json_value(Value, '$."Id"') = 10) PolicyNumber,
		   convert(date,
		   (select json_value(Value, '$."Value"') Value
			from openjson(json_query([Value], '$."ExtensionFields"'))
			where json_value(Value, '$."Id"') = 95)) EffectiveDate/*,
		   (select json_value(Value, '$."Value"') Value
			from openjson(json_query([Value], '$."ExtensionFields"'))
			where json_value(Value, '$."Id"') = 5) TotalPremium,
		   (select json_value(Value, '$."Value"') Value
			from openjson(json_query([Value], '$."ExtensionFields"'))
			where json_value(Value, '$."Id"') = 22) InspectionContactName */
--	into [Sandbox].[dbo].[RCTAccounts]
	from openjson(@ResponseJSON)

	if @@ROWCOUNT > 0
		set @PageNumber = @PageNumber + 1
	else
		set @PageNumber = NULL
    

end

delete [Sandbox].[dbo].[RCTAccounts]
where IsNull(PolicyNumber, '') = ''




--  Get all Account Tasks  PageSize = 100 is the max allowed value, PageNumber 1 = 1-100, 2 = 101-200, 3 = 201 - 300, etc

set @PageNumber = 1


truncate table [Sandbox].[dbo].[RCTAccountTasks]

-- Loop thru and increment @PageNumber until @@Rowcount = 1

While @PageNumber is not NULL

Begin

	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/tasks?OrderBy=ReferenceNumber%20desc&PageNumber=' + convert(varchar, @PageNumber) +'&PageSize=100&Lang=en'

	delete from @responseText
	set @ResponseJSON = ''
	set @postData = ''

	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	select @ResponseJSON = responseText
	from @responseText

	insert into [Sandbox].[dbo].[RCTAccountTasks]
	select value,
		   json_value([Value], '$."Id"') TaskId, 
		   json_value([Value], '$."AccountId"') RCTId, 
		   json_value([Value], '$."PolicyNumber"') PolicyNumber, 
		   json_value(json_query([Value], '$."Consultant"'), '$."Name"') ConsultantName,
		   json_value(json_query([Value], '$."TaskType"'), '$."Id"') TaskTypeID,
		   json_value(json_query([Value], '$."TaskType"'), '$."Caption"') TaskType,
		   json_value(json_query([Value], '$."TaskStatus"'), '$."Caption"') TaskStatus,
		   json_value([Value], '$."DateAssigned"') DateAssigned,
		   convert(date, json_value([Value], '$."DateCompleted"')) DateCompleted
--	into [Sandbox].[dbo].[RCTAccountTasks]
	from openjson(@ResponseJSON)

	if @@ROWCOUNT > 0
		set @PageNumber = @PageNumber + 1
	else
		set @PageNumber = NULL
    

end

/*

delete from [Sandbox].[dbo].[RCTAccounts]
where PolicyNumber is NULL

*/


--Update Account Level Completed Task Dates

DECLARE update_account_completed_task_dates CURSOR FOR
select RCTId,
	   TaskTypeId,
	   DateCompleted
from [Sandbox].[dbo].[v_RCTCompletedTaskDateUpdates]

OPEN update_account_completed_task_dates  
  
FETCH NEXT FROM update_account_completed_task_dates   
INTO @RctID, @TaskTypeID, @DateCompleted


WHILE @@FETCH_STATUS = 0  
BEGIN  


	SET @contentType = 'application/json';


	set @OpType		= 'add'  --replace doesn't seem to work, maybe because there are multiple fields being replaced
								--add does a replace anyway


	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/accounts/patchV2/' + @RCTID
	--	Print @URL


    if @TaskTypeID = 2648
	begin
		set @postData = '[
							{
								"value": {
									"Id": 172,
									"Value": "' + convert(nvarchar, @DateCompleted, 101) + '"
								},
								"path": "/ExtensionFields/-",
								"op": "add",
								"from": "string"
							}
							]'
    end
	else
	begin 
		set @postData = '[
							{
								"value": {
									"Id": 173,
									"Value": "' + convert(nvarchar, @DateCompleted, 101) + '"
								},
								"path": "/ExtensionFields/-",
								"op": "add",
								"from": "string"
							}
							]'
	
	end
	
	--	Print @postData


	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'PATCH', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @XXSRFTOKEN
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-Version', '""';
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'X-XSRF-TOKEN', @XXSRFTOKEN;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;
	--PRINT @res

	--	DELETE from @ResponseHeader
	--	SET TEXTSIZE 2147483647
	--  delete from @ResponseHeader
	--	INSERT INTO @ResponseHeader (ResponseHeader) EXEC @res = sp_OAGetProperty @token, 'getAllResponseHeaders'
	--	select responseHeader FROM @ResponseHeader


	-- Handle the response.
	--	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	--PRINT @res
	--	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	--PRINT @res
	--	SET TEXTSIZE 2147483647
	--  delete from @ResponseText
	--	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'ResponseText'
	-- Show the response.
	--	PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--	SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	--select @ResponseJSON = responseText
	--from @responseText

	/*
	select json_value([Value], '$."Id"') JsonValue, 
			json_value([Value], '$."FieldName"') JsonName, 
			[value]
	from openjson(@ResponseJSON)
	*/

	--  Update/load account information to RCTAccounts table


	delete from [Sandbox].[dbo].[RCTAccounts]
	where RCTId = @RctID

	set @URL = 'https://rdi6.riskcontrol.expert/gramercy/api/accounts/' + @RctID

	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	insert into [Sandbox].[dbo].[RCTAccounts]
	select responseText,
			json_value(responseText, '$."Id"') RCTId,
			json_value(responseText, '$."ExternalUniqueId"') IMSId, 
			json_value(responseText, '$."Name"') InsuredName, /*
			json_value(json_query(responseText, '$."MailingAddress"'), '$."AddressLine"') AddressLine,
			json_value(json_query(responseText, '$."MailingAddress"'), '$."City"') City,
			json_value(json_query(json_query(responseText, '$."MailingAddress"'), '$."Province"'), '$."Code"') StateCode,
			json_value(json_query(responseText, '$."MailingAddress"'), '$."PostalCode"') PostalCode,
	--	   json_query([Value], '$."ExtensionFields"') ExtensionFields, */
			(select json_value(Value, '$."Value"') Value
			from openjson(json_query(responseText, '$."ExtensionFields"'))
			where json_value(Value, '$."Id"') = 10) PolicyNumber,
			convert(date,
			(select json_value(Value, '$."Value"') Value
			from openjson(json_query(responseText, '$."ExtensionFields"'))
			where json_value(Value, '$."Id"') = 95)) EffectiveDate/*,
			(select json_value(Value, '$."Value"') Value
			from openjson(json_query([Value], '$."ExtensionFields"'))
			where json_value(Value, '$."Id"') = 5) TotalPremium,
			(select json_value(Value, '$."Value"') Value
			from openjson(json_query([Value], '$."ExtensionFields"'))
			where json_value(Value, '$."Id"') = 22) InspectionContactName */
	--	into [Sandbox].[dbo].[RCTAccounts]
	from @responseText




	FETCH NEXT FROM update_account_completed_task_dates   
	INTO @RctID, @TaskTypeID, @DateCompleted

END

CLOSE update_account_completed_task_dates;  
DEALLOCATE update_account_completed_task_dates;  

-- PB 11/14/2022 - Added Code to load Recommendations
------------------------------------------------
-- Load Recommendations

-------------------------------------------


--  Get all Recomendations PageSize = 100 is the max allowed value, PageNumber 1 = 1-100, 2 = 101-200, 3 = 201 - 300, etc

set @PageNumber = 1



truncate table [Sandbox].[dbo].[RCTRecommendations]

-- Loop thru and increment @PageNumber until @@Rowcount = 1

While @PageNumber is not NULL


Begin

	set @URL		= 'https://rdi6.riskcontrol.expert/gramercy/api/recommendations?OrderBy=Id&PageNumber=' + convert(varchar, @PageNumber) +'&PageSize=100&Lang=en'
	
	delete from @responseText
	set @ResponseJSON = ''
	set @postData = ''

	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';
	--set a custom header Authorization is the header key and VALUE is the value in the header
	--PRINT @authHeader
	--PRINT @res
	--PRINT @contentType
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Cookie', @SetCookie;
	--PRINT @res
	EXEC @res = sp_OAMethod @token, 'send', NULL, @postData;

	-- Handle the response.
	EXEC @res = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @res = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	SET TEXTSIZE 2147483647
	delete from @ResponseText
	INSERT INTO @ResponseText (ResponseText) EXEC sp_OAGetProperty @token, 'responseText'

	-- Show the response.
	--PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	--SELECT @status, responseText FROM @responseText

	-- Close the connection.
	EXEC @res = sp_OADestroy @token;
	IF @res <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);

	--SELECT @status, responseText FROM @responseText

	select @ResponseJSON = responseText
	from @responseText

	insert into [Sandbox].[dbo].[RCTRecommendations]
	select value,
		   json_value([Value], '$."Id"') RecId,  
		   json_value([Value], '$."RecommendationNumber"') RecNumber,
		   json_value(json_query([Value], '$."Task"'), '$."Id"') TaskId,
		   json_value(json_query(json_query([Value], '$."Task"'), '$."Account"'), '$."Id"') RCTId,
		   json_value(json_query(json_query([Value], '$."Task"'), '$."Account"'), '$."Name"') AccountName,
		   json_value(json_query(json_query([Value], '$."Task"'), '$."Underwriter"'), '$."Id"') UnderWriterId,
		   json_value(json_query(json_query([Value], '$."Task"'), '$."Consultant"'), '$."Id"') ConsultantId,
		   json_value(json_query([Value], '$."Status"'), '$."Caption"') Status,
		   json_value(json_query([Value], '$."Severity"'), '$."Caption"') Severity,
		   json_value([Value], '$."Description"') Description,
		   json_value([Value], '$."CompleteBy"') CompleteBy,
		   json_value([Value], '$."DateCompleted"') DateCompleted
	from openjson(@ResponseJSON)
	
	if @@ROWCOUNT > 0
		set @PageNumber = @PageNumber + 1
	else
		set @PageNumber = NULL
    

end