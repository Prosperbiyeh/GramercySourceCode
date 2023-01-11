USE Sandbox


/*  Pre-OFAC call work to get new IMS and Flexi Entities  */

/* Load new IMS Entities */

insert into [dbo].[IMSOFACEntityList]
select *
from [dbo].[v_NewIMSOFACEntities]

/* Get OFAC-VendorRemit.txt file from Flexi SFTP site - Added 8/12/2022 logic to only load on the second of each month */

if datepart(day, GetDate()) = 2

begin


	exec master..xp_cmdshell 'E:\FlexiExport\GetOFACFileFromFlexiProd.bat'


/* Reload [dbo].[OFAC-VendorRemit] holding table */

	truncate table [dbo].[OFAC-VendorRemit]

	BULK INSERT [dbo].[OFAC-VendorRemit]
	FROM 'E:\FlexiExport\Import\OFAC-VendorRemit.txt'
	WITH (FIELDTERMINATOR = '","', 
		  ROWTERMINATOR = '",\n"',
		  FIRSTROW = 1);


	update [dbo].[OFAC-VendorRemit]
	set Header	= replace(Header, '"', ''),
		EIN		= replace(replace(EIN, '"', ''), ',', '')


/* Load new Flexi Entities */

	insert into [dbo].[FlexiOFACEntityList]
	select *
	from [dbo].[v_NewFlexiOFACEntities]

end


DECLARE @url			VarChar(MAX),
		@Username		nvarchar(50),
		@Password		nvarchar(50),
		@xmlOut			varchar(8000),
		@RequestText	varchar(8000),
		@Name			varchar(300),
		@Street			varchar(300),
		@City			varchar(300),
		@Country		varchar(300),
		@OCLID			int,
		@EntityID		varchar(50),
		@SystemName		varchar(50);

SET @url = 'https://www.intelligentsearch.com/ISTwatchWS/ISTWatchWebService.asmx?WSDL'

--  Get the Account Credentials to set @RequestText

--  Open Encryption Key

OPEN SYMMETRIC KEY WebserviceAPIPassword_Key11  
   DECRYPTION BY CERTIFICATE WebserviceAPIPassword;  

--  Once Encryption Key is open, now you can decrypt the password

select @Username	= AccountName,
       @Password	= CONVERT(varchar, DecryptByKey(Pwd_Encrypted))
from Sandbox.dbo.WebserviceAPICreds
where ServiceName = 'IntelligentSearch'
  and Environment = 'PROD'

/*

set @Name		= 'Joseph Biden'
set @Street		= 'White House'
set @City		= 'Washington DC'
set @Country	= 'USA'

*/

DECLARE Entity_Cursor CURSOR  
    FOR SELECT a.EntityID,
	           a.EntityName,
			   max(IsNull(a.Address1, '')) Address1,
			   max(IsNull(a.City, '')) City,
			   max(IsNull(a.ISOCountryCode, '')) ISOCountryCode,
			   a.SystemName
	    FROM v_AllOFACEntities a
		where not exists (select 1
							from [dbo].[OFACCallLog] b
							where a.EntityID = b.EntityID
							and a.SystemName = b.SystemType
							and b.ResponseDate > DATEADD(d, -90, GetDate()))  -- every 90 days for now
        group by a.EntityID,
	           a.EntityName,
			   a.SystemName
        order by 2, 1, 6


OPEN Entity_Cursor  


FETCH NEXT FROM Entity_Cursor into @EntityID,
								 @Name,
								 @Street,
								 @City,
								 @Country,
								 @SystemName;  

WHILE @@FETCH_STATUS = 0
Begin


		SET @RequestText = '<?xml version="1.0" encoding="utf-8"?>
		<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:hos="http://www.intelligentsearch.com/HostedWebServices/">
		   <soap:Header/>
		   <soap:Body>
			  <hos:wsISTWatch>
				 <!--Optional:-->
				 <hos:username>' + @Username + '</hos:username>
				 <!--Optional:-->
				 <hos:password>' + @Password + '</hos:password>
				 <!--Optional:-->
				 <hos:name>' + replace(@Name, '&', ' and ') + '</hos:name>
				 <!--Optional:-->
				 <hos:street>' + replace(@Street, '&', ' and ') + '</hos:street>
				 <!--Optional:-->
				 <hos:city>' + @City + '</hos:city>
				 <!--Optional:-->
				 <hos:country>' + @Country + '</hos:country>
				 <!--Optional:-->
				 <hos:score_threshold>90</hos:score_threshold>
				 <!--Optional:-->
				 <hos:maximum_results>5</hos:maximum_results>
				 <!--Optional:-->
				 <hos:search_lists>11000</hos:search_lists>
				 <!--Optional:-->
				 <hos:search_rulebase>True</hos:search_rulebase>
				 <!--Optional:-->
				 <hos:exclude_vessel>False</hos:exclude_vessel>
				 <!--Optional:-->
				 <hos:include_alias>True</hos:include_alias>
				 <!--Optional:-->
				 <hos:extended_search>False</hos:extended_search>
				 <!--Optional:-->
				 <hos:search_range>0</hos:search_range>
				 <!--Optional:-->
				 <hos:sanct_countries_search>True</hos:sanct_countries_search>
			  </hos:wsISTWatch>
		   </soap:Body>
		</soap:Envelope>'

/*  If the entity already exists in the OFACCallLog table, load its OCLID into @OCLID */

		set @OCLID = 0
		
		select @OCLID = OCLID
		from [dbo].[OFACCallLog]
		where @EntityID = EntityID
		  and @SystemName = SystemType
		
		if @OCLID = 0
			begin

/* If the entity does not exist in the OFACCallLog table, insert it and load its OCLID into @OCLID */

				insert into [dbo].[OFACCallLog]
				values(@SystemName, 
					   @EntityID, 
					   @Name,
					   @Street,
					   @City,
					   @Country,
					   @RequestText,
					   NULL,
					   NULL,
					   NULL,
					   NULL)

				SELECT @OCLID = SCOPE_IDENTITY()
			end


		exec spHTTPRequest  
		@url,  
		'Post',  
		@RequestText,  
		'http://www.intelligentsearch.com/HostedWebServices/wsISTWatch',   -- this is your SOAPAction:  
		'', '', @OCLID, @xmlOut out  

 
    FETCH NEXT FROM Entity_Cursor into @EntityID,
									   @Name,
									   @Street,
									   @City,
									   @Country,
									   @SystemName;  
END 
CLOSE Entity_Cursor;  
DEALLOCATE Entity_Cursor;