
USE Sandbox

/* First decode all new vins into the [Sandbox].[dbo].[IMSVehicleVINDecode] table */


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

DECLARE @status NVARCHAR(32)
DECLARE @statusText NVARCHAR(32);
DECLARE @responseText as table(responseText nvarchar(max))
DECLARE @ResponseHeader	as table(ResponseHeader nvarchar(max))
DECLARE @res as Int
DECLARE @VIN  NVARCHAR(32)




--  Get Vin Decode Data

SET @contentType	= 'application/json';
set @URL			= 'https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVin/' + @VIN + '?format=json'

-- set @PageNumber = 1

-- Loop thru and increment @PageNumber until @@Rowcount = 1

-- truncate table [Sandbox].[dbo].[IMSVehicleVINDecode]	 

DECLARE IMS_VIN CURSOR FOR
select VIN
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] a,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat] b,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin] c,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin_Vehic] d
where a.DateIssued is not NULL
  and a.NetRate_QuoteID = b.QuoteID
  and b.LocationID = c.LocationID
  and c.BusinessAutoID = d.BusinessAutoID
  and d.UnitNumber is not NULL
  and IsNull(d.[Transaction], '') <> 'Deleted'
  and d.VIN is not NULL
  and not exists (select 1
				  from [Sandbox].[dbo].[IMSVehicleVINDecode] b
				  where d.VIN = b.VIN)
group by VIN
order by VIN

OPEN IMS_VIN  
  
FETCH NEXT FROM IMS_VIN   
INTO @VIN


WHILE @@FETCH_STATUS = 0  

Begin

--    set @VIN        = '1GTW7FBA6E1139601'
	set @URL		= 'https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVin/' + @VIN + '?format=json'



	-- Open the connection.
	EXEC @res = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	--Print @token
	IF @res <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @res = sp_OAMethod @token, 'open', NULL, 'GET', @url, 'false';

--	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Accept', @contentType;
	--print @res
--	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'authorization', @authHeader;
	--print @res
--	EXEC @res = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', @contentType;
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
	

--	select @ResponseJSON = responseText
--	from @responseText

	insert into [Sandbox].[dbo].[IMSVehicleVINDecode]	
	select responseText,
	       @VIN VIN,
		   (select json_value(Value, '$."Value"') Value
		    from openjson(json_query(responseText, '$."Results"'))
		    where json_value(Value, '$."Variable"') = 'Model Year') ModelYear,
		   (select json_value(Value, '$."ValueId"') Value
		    from openjson(json_query(responseText, '$."Results"'))
		    where json_value(Value, '$."Variable"') = 'Make') MakeId,
		   (select json_value(Value, '$."Value"') Value
		    from openjson(json_query(responseText, '$."Results"'))
		    where json_value(Value, '$."Variable"') = 'Make') Make,
		   (select json_value(Value, '$."ValueId"') Value
		    from openjson(json_query(responseText, '$."Results"'))
		    where json_value(Value, '$."Variable"') = 'Model') ModelId,
		   (select json_value(Value, '$."Value"') Value
		    from openjson(json_query(responseText, '$."Results"'))
		    where json_value(Value, '$."Variable"') = 'Model') Model
--	into [Sandbox].[dbo].[IMSVehicleVINDecode]
	from @responseText


	FETCH NEXT FROM IMS_VIN   
	INTO @VIN

END

CLOSE IMS_VIN;  
DEALLOCATE IMS_VIN; 



DECLARE @PolicyNumber		varchar(100)
DECLARE @QuoteId			int

CREATE TABLE #FHEPolicyFeed_Formatted (
	[Tier 2 Company Name] [varchar](100) NOT NULL,
	[Tier 3 Company Name] [varchar](500) NULL,
	[Company ID] [varchar](10) NULL,
	[Policy Num] [varchar](50) NULL,
	[Primary Carrier ID] [varchar](10) NULL,
	[Policy Desc] [varchar](1000) NOT NULL,
	[Aggregate Limit Amount] [varchar](40) NOT NULL,
	[Holder Address 1] [varchar](250) NOT NULL,
	[Holder Address 2] [varchar](250) NOT NULL,
	[Holder City] [varchar](60) NOT NULL,
	[Holder State] [varchar](10) NULL,
	[Holder Zip Code] [varchar](20) NULL,
	[Holder Phone] [varchar](20) NOT NULL,
	[Holder Fax] [varchar](20) NOT NULL,
	[Policy Begin Date] [date] NULL,
	[Policy End Date] [date] NULL,
	[Policy Premium Amt] [decimal](12, 2) NULL,
	[Cancellation Date] [varchar](30) NOT NULL,
	[Lob ID] [varchar](10) NULL,
	[Claims Made Policy YN] [varchar](10) NULL,
	[Retro Date] [varchar](20) NULL,
	[ProducerName] [varchar](250) NOT NULL,
	[ProducerAddress1] [varchar](250) NOT NULL,
	[ProducerAddress2] [varchar](250) NULL,
	[ProducerCity] [varchar](60) NOT NULL,
	[ProducerState] [varchar](10) NULL,
	[ProducerZipCode] [varchar](20) NULL,
	[ProducerEmail] [varchar](60) NULL,
	[ProducerPhone] [varchar](25) NULL
) ON [PRIMARY]

CREATE TABLE #FHEPolicyCoverageFeed_Formatted (
--    [QuoteId] [int] NOT NULL,
	[Policy Num] [varchar](50) NULL,
	[Policy Begin Date] [date] NULL,
	[Policy End Date] [date] NULL,
	[Coverage ID] [varchar](100) NOT NULL,
	[Begin Coverage Amt] [int] NULL,
	[End Coverage Amt] [int] NULL,
	[Begin Date] [date] NULL,
	[End Date] [date] NULL,
	[Risk Description] [varchar](200) NOT NULL,
	[Cost New] [money] NULL,
	[Coverage Description] [varchar](200) NULL,
	[Model Year] [varchar](50) NULL,
	[Make] [varchar](100) NULL,
	[Model] [varchar](100) NULL,
	[VIN] [varchar](100) NULL,
	[lob_id] [varchar](10) NULL,
	[NHTSAMakeId] [nvarchar](4000) NULL,
	[NHTSAMake] [nvarchar](4000) NULL,
	[NHTSAModelId] [nvarchar](4000) NULL,
	[NHTSAModel] [nvarchar](4000) NULL,
	[sublob_id] [varchar](10) NULL
) ON [PRIMARY]




DECLARE policyTransactions CURSOR FOR
select a.PolicyNumber, a.QuoteId
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_PolicyRiskCoveragesforFHE] a
--where IsNull(a.DateIssued, a.DateBound) > '2/7/2023 12:00:00'
where not exists (select 1
				  from [FHE].[dbo].[IMSQuotesLoadedtoFHE] b
				  where a.QuoteId = b.QuoteId)
group by a.PolicyNumber, a.QuoteId
order by 1, 2 -- so we only load the last QuoteId for a policy into the feed file but
              -- still record all QuoteIds processed in the IMSQuotesLoadedtoFHE table

OPEN policyTransactions  
  
FETCH NEXT FROM policyTransactions   
INTO @PolicyNumber, @QuoteId


WHILE @@FETCH_STATUS = 0  
BEGIN  



		/* Policy Feed - Only load policy record if it hasn't been loaded previously, no updates */

		insert into #FHEPolicyFeed_Formatted
		select *
		from [FHE].[dbo].v_FHEPolicyFeed_Formatted pf
		where [Policy Num] = @PolicyNumber
          /* Don't load if policy/lob already in the fh_policy table */
		  and not exists (select 1
		  /*  Until we go live
						  from FHE.dbo.fh_policy p */
						  from [GRAMERCYFHE].FEGramercy.dbo.fh_policy p
						  where p.policy_num = pf.[Policy Num]
						    and p.lob_id = pf.[Lob ID])
          /* Don't load if policy/lob already in the temp table */
		  and not exists (select 1
						  from #FHEPolicyFeed_Formatted p
						  where p.[Policy Num] = pf.[Policy Num]
						    and p.[Lob ID] = pf.[Lob ID])




		/*  Risk/Coverage Feed */

	  /*  MH  12/22/2022 -  Delete any previously inserted records for a prior QuoteId loaded on the same day for one policy */

	    delete from #FHEPolicyCoverageFeed_Formatted
		where [Policy Num] = @PolicyNumber

		insert into #FHEPolicyCoverageFeed_Formatted
		select a.PolicyNumber [Policy Num],
			   a.EffectiveDate [Policy Begin Date],
			   a.ExpirationDate [Policy End Date],
			   IsNull(c.FHECoverageCode, a.Coverage + '***') [Coverage ID],
			   a.BeginCoverageAmt [Begin Coverage Amt],
			   a.EndCoverageAmt [End Coverage Amt],
			   convert(date, a.EndorsementEffective) [Begin Date],
		/*  MH  12/22/2022 - To have end dates for endorsements be one day prior to the next transaction's begin date
							 if this is not the last policy endorsement
			   convert(date, a.EndorsementExpiration) [End Date], */
			   case when convert(date, a.EndorsementExpiration) < a.ExpirationDate
					then dateadd(d, -1, convert(date, a.EndorsementExpiration))
					else convert(date, a.EndorsementExpiration) end [End Date],
			   a.RiskDescription [Risk Description],
			   a.CostNew [Cost New],
			   a.CoverageDescription [Coverage Description],
			   a.ModelYear [Model Year],
			   a.Make [Make],
			   a.Model [Model],
			   a.VIN [VIN],
			   case when b.FHELineID in ('AL', 'AP')
					then 'CA'
					else b.FHELineID end lob_id, /*,
			   a.LineName */
			   d.[MakeId] NHTSAMakeId,
			   d.[Make] NHTSAMake,
			   d.[ModelId] NHTSAModelId,
			   d.[Model] NHTSAModel,
			   b.FHELineID sublob_id
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_PolicyRiskCoveragesforFHE] a
			 left join [Sandbox].[dbo].[IMSFHECoverageMapping] c
			   on a.Coverage = c.IMSGroupedCoverageCode
			  and a.LineName = c.LineName
			  left join [Sandbox].[dbo].[IMSVehicleVINDecode] d
			   on a.VIN = d.VIN,
			 [Sandbox].[dbo].[PolicyClaimLines] b
		where a.PolicyNumber = @PolicyNumber
		  and a.LineName = b.IMSLineName
		  and convert(date, a.EndorsementEffective) < convert(date, a.EndorsementExpiration)
	  /*  MH   2/10/2023 - Just in case there is still a duplicate  */
		group by a.PolicyNumber,
			   a.EffectiveDate,
			   a.ExpirationDate,
			   IsNull(c.FHECoverageCode, a.Coverage + '***'),
			   a.BeginCoverageAmt,
			   a.EndCoverageAmt,
			   convert(date, a.EndorsementEffective),
		/*  MH  12/22/2022 - To have end dates for endorsements be one day prior to the next transaction's begin date
							 if this is not the last policy endorsement
			   convert(date, a.EndorsementExpiration) [End Date], */
			   case when convert(date, a.EndorsementExpiration) < a.ExpirationDate
					then dateadd(d, -1, convert(date, a.EndorsementExpiration))
					else convert(date, a.EndorsementExpiration) end,
			   a.RiskDescription,
			   a.CostNew,
			   a.CoverageDescription,
			   a.ModelYear,
			   a.Make,
			   a.Model,
			   a.VIN,
			   case when b.FHELineID in ('AL', 'AP')
					then 'CA'
					else b.FHELineID end, /*,
			   a.LineName */
			   d.[MakeId],
			   d.[Make],
			   d.[ModelId],
			   d.[Model],
			   b.FHELineID

    
	insert into [FHE].[dbo].[IMSQuotesLoadedtoFHE]
	select @QuoteId, GetDate()


	FETCH NEXT FROM policyTransactions   
	INTO @PolicyNumber, @QuoteId


end


select *
into FHE.dbo.FHEPolicyFeed_Formatted
from #FHEPolicyFeed_Formatted

/* Fix the commas */

update FHE.dbo.FHEPolicyFeed_Formatted
set  [Tier 2 Company Name] = '"' + [Tier 2 Company Name] + '"',
 [Tier 3 Company Name] = '"' + [Tier 3 Company Name] + '"',
 [Company ID] = '"' + [Company ID] + '"',
 [Policy Num] = '"' + [Policy Num] + '"',
 [Primary Carrier ID] = '"' + [Primary Carrier ID] + '"',
 [Policy Desc] = '"' + [Policy Desc] + '"',
 [Aggregate Limit Amount] = '"' + [Aggregate Limit Amount] + '"',
 [Holder Address 1] = '"' + [Holder Address 1] + '"',
 [Holder Address 2] = '"' + [Holder Address 2] + '"',
 [Holder City] = '"' + [Holder City] + '"',
 [Holder State] = '"' + [Holder State] + '"',
 [Holder Zip Code] = '"' + [Holder Zip Code] + '"',
 [Holder Phone] = '"' + [Holder Phone] + '"',
 [Holder Fax] = '"' + [Holder Fax] + '"',
 [Lob ID] = '"' + [Lob ID] + '"',
 [Claims Made Policy YN] = '"' + [Claims Made Policy YN] + '"',
 [ProducerName] = '"' + [ProducerName] + '"',
 [ProducerAddress1] = '"' + [ProducerAddress1] + '"',
 [ProducerAddress2] = '"' + [ProducerAddress2] + '"',
 [ProducerCity] = '"' + [ProducerCity] + '"',
 [ProducerState] = '"' + [ProducerState] + '"',
 [ProducerZipCode] = '"' + [ProducerZipCode] + '"',
 [ProducerEmail] = '"' + [ProducerEmail] + '"',
 [ProducerPhone] = '"' + [ProducerPhone] + '"'

select *
into FHE.dbo.FHEPolicyCoverageFeed_Formatted
from #FHEPolicyCoverageFeed_Formatted

update FHE.dbo.FHEPolicyCoverageFeed_Formatted
set  [Policy Num] = '"' + [Policy Num] + '"',
 [Coverage ID] = '"' + [Coverage ID] + '"',
 [Risk Description] = '"' + [Risk Description] + '"',
 [Coverage Description] = '"' + [Coverage Description] + '"',
 [Model Year] = '"' + [Model Year] + '"',
 [Make] = '"' + [Make] + '"',
 [Model] = '"' + [Model] + '"',
 [VIN] = '"' + [VIN] + '"',
 [lob_id] = '"' + [lob_id] + '"',
 [NHTSAMakeId] = '"' + [NHTSAMakeId] + '"',
 [NHTSAMake] = '"' + [NHTSAMake] + '"',
 [NHTSAModelId] = '"' + [NHTSAModelId] + '"',
 [NHTSAModel] = '"' + [NHTSAModel] + '"',
 [sublob_id] = '"' + [sublob_id] + '"'

declare @PolicyRecordCount		int
declare @CoverageRecordCount	int


select @PolicyRecordCount = count(*)
from FHE.dbo.FHEPolicyFeed_Formatted


if @PolicyRecordCount > 0

	begin

		exec master..xp_cmdshell 'sqlcmd -s, -W -Q "set nocount on; select * from FHE.dbo.FHEPolicyFeed_Formatted " | findstr /v /c:"-" /b > "E:\FHEExport\Policy.csv"'
		exec master..xp_cmdshell 'ren E:\FHEExport\"Policy.csv" "Policy_%date:~4,2%%date:~7,2%%date:~10,4%000000.csv"'
	end


select @CoverageRecordCount = count(*)
from FHE.dbo.FHEPolicyCoverageFeed_Formatted

if @CoverageRecordCount > 0

	begin

		exec master..xp_cmdshell 'sqlcmd -s, -W -Q "set nocount on; select * from FHE.dbo.FHEPolicyCoverageFeed_Formatted " | findstr /v /c:"-" /b > "E:\FHEExport\Coverage.csv"'
		exec master..xp_cmdshell 'ren E:\FHEExport\"Coverage.csv" "Coverage_%date:~4,2%%date:~7,2%%date:~10,4%000000.csv"'
	end

if @CoverageRecordCount + @PolicyRecordCount > 0

	begin
		exec master..xp_cmdshell 'E:\FHEExport\SFTPtoFHEPROD.bat'
	end


drop table #FHEPolicyFeed_Formatted
drop table #FHEPolicyCoverageFeed_Formatted

drop table FHE.dbo.FHEPolicyFeed_Formatted
drop table FHE.dbo.FHEPolicyCoverageFeed_Formatted

CLOSE policyTransactions;  
DEALLOCATE policyTransactions; 
