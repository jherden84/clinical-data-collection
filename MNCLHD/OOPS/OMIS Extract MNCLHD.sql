
/************************************************************************************************************
* Description: 	OMIS extract - Mosaiq - Coffs Harbour
* Version:	1.1
* Author:	William Su
* Hospital code: H208, facility code: C070
* 
* BRAD NOTE: This script must be run one facility at a time
* 
* Updates	
* 20171020: updated 
* 20171023: update 1571 to 1570, QA added.
* 20171120: update countries map, referral/mdt/consult/trial/palliative dates, tnm filter
* 20171121: update output field length and debug field lengths
* 20171221: remove double ireland, cancer/morph code version id, added CPL_ID/CPlan_Name/Regimen, debugging cancer site code not in (B,C,D,L),
			consult before referral, new consult codes, status/supression flag for schedule table, referral/consult by pat id and grp id, added treatments with no end date,
* 20180119: null all notification fields for eviq, CancerSiteCodeID: CNNN - ICDO3, CNN.NN - ICD10, update drug admin amt >= 0, "Maintenance" added for episodeintent, C50 for ICD10V2 -> ICD10V3 
* 20180122: notification freqency to N(3), change name to "MEDONC...", TStage "is (DCIS)" -> "is", 
* 20180123: remove " from aliasurname, consults and referrals only for medonc inst., CancerSiteCodeIDVersion dx times, cancersitecode_x if primary not exist then take re-occurence, 
			Trial name is not null / blank, remove "screening" trials,  
* 20180124: tstage *dcis* updated, updated trial to '%scr%'
* 20180202: hosp / facility code from charge table, 
* 20180208: added 2nd ecog code, 
* 20180301: TNM remove collation default, cancerdiagnosis default to 3 (for null, unknow, other), stage date, 
* 20180305: Stagedate only = stage date (no dx), Histogradeid = null for c81-c98, 
* 20180320: added no lock, update 1570 where clause
* 20180322: updated Nstage, 
* 20180326: update initial_treament logic, 
* 20180413: added @enddate for TNMstage selection, 
* 20180418: remove date param for initial_treatment, update ClinicalTrialName, added space in WayfareAddress, 
* 20180612: remove commas in names
* 20180704: added @eviq: eviq and 1570/1571 map for retrospective and prospective protocol number mapping.
* 20180705: @eviq split for trials. Episode end date update to last completed treatment date.
* 20180706: resolve collation for @eviq
* 20180710: episode start/end date updated to actual first/last day of administration for chemo/antineoplastic drugs.
* 20180725: first and last actual admin date updated to group id level, episode updated to consider diagnose and plan start date, episode end date to consider discontinue date. 
			AntiNeoplasticCycles to inline with last admin cycle.
* 20180727: added test patient surname filter
* 20180731: update @eviq mappings logic
* 20180801: trial date update to reg date not start date, remove chemo drug type ref for first/last admin date
* 20180808: update last admin date logic to < (@enddate - cycle length*2), remove reference to discontinue/plan end date. Antineoplastic cycle in line with last admin date
			@enddate set to today if in the future, last admin date logic remove "approved" status, first/last admin date updated status types
* 20180822: remove test patients
* 20180824: null 1 char alias name and givenname2
* 20180903: default degreeofspead to 9
* 20190919: added schedule.version = 0
* 28092021: -- BRAD NOTE - I have doubled the size of the allowed variables for all table components for lines 1875 and 1876 - "declare @eviq table" and "declare @eviq2 table" as the report was complaining about having to truncate some collected data		
 **************************************************************************************************************/


declare @startdate date, @enddate date, @debug char(1), @hospital varchar(20) , @QA char(1), @showfilenameonly varchar(1), @hosp_code varchar(10), @facility_code varchar(10)

set @startdate = '2022-10-01'		-- start of month
set @enddate = '2022-12-31'			-- end of month
-- BRAD NOTE: Multiple Hospital codes may be run at once
set @hosp_code = ('''H208'', ''H214'', ''H223'', ''H210'', ''H272''')    -- BRAD NOTE: MNC and NNSW hospital codes: Coffs = ''H208'', Port = ''H272'', Tweed = ''H223'', Grafton = ''H210'', Lismore ''H214''
set @QA = 'n'						-- Y = QA mode, N = final output for upload to CI
set @showfilenameonly = 'n'				-- Y = show output file name only, N = run main code
   


set nocount on

-- BRAD NOTE: I don't know why the below line is commented out
--set @hosp_code = 'H208'				-- Hospital code:   
-- BRAD NOTE: Multiple Facilitie Codes may be run at once
set @facility_code = ('''H208'', ''H214'', ''H223'', ''H210'', ''H272''') -- BRAD NOTE: MNC and NNSW facility codes: CH MO: ''H933'', PB MO: ''H934'', LB MO: ''F298'', TH MO: ''H981'', GB MO: ''H982''

set @debug = @QA

declare @dt varchar(12)

if @showfilenameonly = 'Y'
begin
	set @dt = right('0'+cast(datepart(d, getdate()) as varchar(2)),2)+right('0'+cast(datepart(m, getdate()) as varchar(2)),2)+right('0'+cast(datepart(yyyy, getdate()) as varchar(4)),4)+right('0'+cast(datepart(hh, getdate()) as varchar(2)),2)+right('0'+cast(datepart(mi, getdate()) as varchar(2)),2) 
	select 'MEDONC_'+@hosp_code+'_'+@dt+'.csv' as Output_File_Name
	return;
end 
if  @enddate > cast(getdate() as date)
  set @enddate = cast(getdate() as date)


declare @countries table (code int, name varchar(200))
declare @states table (code varchar(3), name varchar(200))
declare @indigenious table (code varchar(3), name varchar(200))
declare @cancerdiagnosis table (code varchar(3), name varchar(200))
declare @laterality table (code varchar(3), name varchar(200))
declare @episodeintent table (code varchar(3), name varchar(200))
declare @drugadminroute table (code int, name int)
declare @stagegroup table (name varchar(20))

insert into @stagegroup values ('0')
insert into @stagegroup values ('0a')
insert into @stagegroup values ('0is')
insert into @stagegroup values ('I')
insert into @stagegroup values ('IS')
insert into @stagegroup values ('IA')
insert into @stagegroup values ('IA1')
insert into @stagegroup values ('IA2')
insert into @stagegroup values ('IB')
insert into @stagegroup values ('IB1')
insert into @stagegroup values ('IB2')
insert into @stagegroup values ('IC')
insert into @stagegroup values ('II')
insert into @stagegroup values ('IIA')
insert into @stagegroup values ('IIA1')
insert into @stagegroup values ('IIA2')
insert into @stagegroup values ('IIB')
insert into @stagegroup values ('IIC')
insert into @stagegroup values ('III')
insert into @stagegroup values ('IIIA')
insert into @stagegroup values ('IIIB')
insert into @stagegroup values ('IIIC')
insert into @stagegroup values ('IIIC1')
insert into @stagegroup values ('IIIC2')
insert into @stagegroup values ('IV')
insert into @stagegroup values ('IVA')
insert into @stagegroup values ('IVA1')
insert into @stagegroup values ('IVA2')
insert into @stagegroup values ('IVB')
insert into @stagegroup values ('IVC')
insert into @stagegroup values ('Not Applicable')
insert into @stagegroup values ('Occult Carcinoma')
insert into @stagegroup values ('Unknown')
insert into @stagegroup values ('Unstaged')
insert into @stagegroup values ('REVIEW')

 

insert into @drugadminroute values (98,694)
insert into @drugadminroute values (12,701)
insert into @drugadminroute values (98,704)
insert into @drugadminroute values (98,706)
insert into @drugadminroute values (13,707)
insert into @drugadminroute values (19,710)
insert into @drugadminroute values (20,711)
insert into @drugadminroute values (30,713)
insert into @drugadminroute values (13,2867)
insert into @drugadminroute values (17,2875)
insert into @drugadminroute values (18,2876)
insert into @drugadminroute values (11,3883)
insert into @drugadminroute values (3,6515)
insert into @drugadminroute values (7,7012)
insert into @drugadminroute values (6,7013)
insert into @drugadminroute values (1,7031)
insert into @drugadminroute values (20,7110)
insert into @drugadminroute values (98,7114)
insert into @drugadminroute values (13,7115)
insert into @drugadminroute values (9,10715)
insert into @drugadminroute values (7,11453)
insert into @drugadminroute values (2,23638)
insert into @drugadminroute values (13,24592)
insert into @drugadminroute values (18,28390)
insert into @drugadminroute values (18,28399)
insert into @drugadminroute values (3,28430)
insert into @drugadminroute values (98,28500)
insert into @drugadminroute values (98,28501)
insert into @drugadminroute values (98,28520)
insert into @drugadminroute values (13,28523)
insert into @drugadminroute values (12,28524)
insert into @drugadminroute values (98,28550)

 
insert into @episodeintent values (2,'Curative')
insert into @episodeintent values (21,'Curative - adjvant')
insert into @episodeintent values (22,'Curative - Neoadjuvant')
insert into @episodeintent values (23,'Curative - Recurrent')
insert into @episodeintent values (3,'Palliative')
insert into @episodeintent values (1,'Prophylactic')
insert into @episodeintent values (4,'Diagnostic')
insert into @episodeintent values (4,'Staging')
insert into @episodeintent values (9,'Non-Cancer') 
insert into @episodeintent values (9,'Not Known') 
insert into @episodeintent values (1,'Maintenance') 


insert into @laterality values (2,' Right')
insert into @laterality values (2,'Right')
insert into @laterality values (9,'0')
insert into @laterality values (3,'0 - Not a paired sit')
insert into @laterality values (3,'0 - Not paired')
insert into @laterality values (3,'0 - Not paired site')
insert into @laterality values (9,'1')
insert into @laterality values (2,'1 - Right')
insert into @laterality values (2,'1 - Right - origin o')
insert into @laterality values (2,'1 - Right lobe only')
insert into @laterality values (9,'2')
insert into @laterality values (1,'2 - Left')
insert into @laterality values (1,'2 - Left - origin of')
insert into @laterality values (9,'3 - One side')
insert into @laterality values (9,'3 - One side involve')
insert into @laterality values (3,'4')
insert into @laterality values (3,'4 - Bilateral')
insert into @laterality values (3,'4 - Bilateral involv')
insert into @laterality values (9,'9 - Unknown side')
insert into @laterality values (9,'9 - Unknown side, Pa')
insert into @laterality values (3,'Bilateral           ')
insert into @laterality values (3,'Bilateral - Simultan')
insert into @laterality values (1,'Left                ')
insert into @laterality values (1,'Left')
insert into @laterality values (1,'left frontal lobe')
insert into @laterality values (3,'Left nasal ala')
insert into @laterality values (3,'left nose')
insert into @laterality values (1,'Left side')
insert into @laterality values (3,'midline')
insert into @laterality values (9,'Not a paired site')
insert into @laterality values (9,'Not a paired site - ')
insert into @laterality values (1,'Origin left side')
insert into @laterality values (1,'Origin left side - L')
insert into @laterality values (2,'Origin right side -')
insert into @laterality values (2,'Right               ')
insert into @laterality values (3,'Right cheek')
insert into @laterality values (3,'Right forehead')
insert into @laterality values (2,'Rt')

   

insert into @cancerdiagnosis values (5,'Cytology')
insert into @cancerdiagnosis values (8,'histopath')
insert into @cancerdiagnosis values (4,'Lab or marker study ')
insert into @cancerdiagnosis values (4,'Lab or marker study')
insert into @cancerdiagnosis values (3,'Unknown             ')
insert into @cancerdiagnosis values (3,'Unknown')
insert into @cancerdiagnosis values (3,'other') 
insert into @cancerdiagnosis values (2,'Clinical diagnosis  ')
insert into @cancerdiagnosis values (2,'Clinical diagnosis')
insert into @cancerdiagnosis values (Null,'limited stage')
insert into @cancerdiagnosis values (5,'Exfoliative cytology')
insert into @cancerdiagnosis values (2,'Direct visualization')
insert into @cancerdiagnosis values (8,'Histology           ')
insert into @cancerdiagnosis values (8,'Histology')
insert into @cancerdiagnosis values (4,'Microscopic confirm ')
insert into @cancerdiagnosis values (2,'Radiography         ')
insert into @cancerdiagnosis values (2,'Radiography')
insert into @cancerdiagnosis values (Null,'')


insert into @indigenious values (9,'Unknown')
insert into @indigenious values (2,'Torres Strait Island')
insert into @indigenious values (9,'Not Stated')
insert into @indigenious values (1,'Aboriginal')
insert into @indigenious values (9,'Other')
insert into @indigenious values (2,'Torres Starit Island')
insert into @indigenious values (9,'Unknown             ')
insert into @indigenious values (9,'Not Stated          ')
insert into @indigenious values (3,'Both (Aboriginal&TSI')
insert into @indigenious values (3,'Both Aboriginal/TSI ')
insert into @indigenious values (1,'Aboriginal          ')
insert into @indigenious values (9,'Australian          ')
insert into @indigenious values (9,'Australian')
insert into @indigenious values (9,null)


 
insert into @states values ('0','Overseas')
insert into @states values ('1','New South Wales')
insert into @states values ('2','Victoria')
insert into @states values ('3','Queensland')
insert into @states values ('4','South Australia')
insert into @states values ('5','Western Australia')
insert into @states values ('6','Tasmania')
insert into @states values ('7','Northern Territory')
insert into @states values ('8','Australian Capital Territory')
insert into @states values ('98','Australia')
insert into @states values ('99','Unknown') 
insert into @states values ('0','Auckland')
insert into @states values ('0','OS')
insert into @states values ('1','NSW')
insert into @states values ('2','VIC')
insert into @states values ('3','QLD')
insert into @states values ('4','SA')
insert into @states values ('5','WA')
insert into @states values ('7','NT')
insert into @states values ('8','ACT')
insert into @states values ('6','TAS')
insert into @states values ('99','PRESENT')
insert into @states values ('99','NR14 8TX')
insert into @states values ('99','SQL')
insert into @states values ('99','STATE') 
 

insert into @countries values (1, '0001 At Sea')
insert into @countries values (3, '0003 Not Stated')
insert into @countries values (4, '0004 Unknown')
insert into @countries values (5, '0005 Unidentified')
insert into @countries values (911, '0911 Europe')
insert into @countries values (912, '0912 USSR - former')
insert into @countries values (913, '0913 Former Yugoslavia')
insert into @countries values (914, '0914 Czechoslovakia')
insert into @countries values (915, '0915 Kurdistan')
insert into @countries values (916, '0916 East Asia')
insert into @countries values (917, '0917 Asia')
insert into @countries values (918, '0918 Africa')
insert into @countries values (921, '0921 Serbia and Montenegro')
insert into @countries values (1000, '1000 Oceania and Antarctica')
insert into @countries values (1100, '1100 Australia (incl External Ter)')
insert into @countries values (1101, '1101 Australia')
insert into @countries values (1102, '1102 Norfolk Island')
insert into @countries values (1199, '1199 Australian External Territories nec')
insert into @countries values (1201, '1201 New Zealand')
insert into @countries values (1300, '1300 Melanesia')
insert into @countries values (1301, '1301 New Caledonia')
insert into @countries values (1302, '1302 Papua New Guinea')
insert into @countries values (1303, '1303 Solomon Islands')
insert into @countries values (1304, '1304 Vanuatu')
insert into @countries values (1400, '1400 Micronesia')
insert into @countries values (1401, '1401 Guam')
insert into @countries values (1402, '1402 Kiribati')
insert into @countries values (1403, '1403 Marshall Islands')
insert into @countries values (1404, '1404 Micronesia Federated States of')
insert into @countries values (1405, '1405 Nauru')
insert into @countries values (1406, '1406 Northern Mariana Islands')
insert into @countries values (1407, '1407 Palau')
insert into @countries values (1500, '1500 Polynesia (excludes Hawaii)')
insert into @countries values (1501, '1501 Cook Islands')
insert into @countries values (1502, '1502 Fiji')
insert into @countries values (1503, '1503 French Polynesia')
insert into @countries values (1504, '1504 Niue')
insert into @countries values (1505, '1505 Samoa')
insert into @countries values (1506, '1506 Samoa American')
insert into @countries values (1507, '1507 Tokelau')
insert into @countries values (1508, '1508 Tonga')
insert into @countries values (1511, '1511 Tuvalu')
insert into @countries values (1512, '1512 Wallis and Futuna')
insert into @countries values (1599, '1599 Polynesia (not Hawaii) nec')
insert into @countries values (1600, '1600 Antarctica')
insert into @countries values (1601, '1601 Antarctica Adelie Land (France)')
insert into @countries values (1602, '1602 Antarctica Argentinian Territory')
insert into @countries values (1603, '1603 Antarctica Australian Territory')
insert into @countries values (1604, '1604 Antarctica British Territory')
insert into @countries values (1605, '1605 Antarctica Chilean Territory')
insert into @countries values (1606, '1606 Queen Maud Land (Norway)')
insert into @countries values (1607, '1607 Ross Dependency (New Zealand)')
insert into @countries values (2000, '2000 North-West Europe')
insert into @countries values (2100, '2100 United Kingdom')
insert into @countries values (2101, '2101 Channel Islands')
insert into @countries values (2102, '2102 England')
insert into @countries values (2103, '2103 Isle of Man')
insert into @countries values (2104, '2104 Northern Ireland')
insert into @countries values (2105, '2105 Scotland')
insert into @countries values (2106, '2106 Wales')
--insert into @countries values (2200, '2200 Ireland')
insert into @countries values (2201, '2201 Ireland')
insert into @countries values (2300, '2300 Western Europe')
insert into @countries values (2301, '2301 Austria')
insert into @countries values (2302, '2302 Belgium')
insert into @countries values (2303, '2303 France')
insert into @countries values (2304, '2304 Germany')
insert into @countries values (2305, '2305 Liechtenstein')
insert into @countries values (2306, '2306 Luxembourg')
insert into @countries values (2307, '2307 Monaco')
insert into @countries values (2308, '2308 Netherlands')
insert into @countries values (2311, '2311 Switzerland')
insert into @countries values (2400, '2400 Northern Europe')
insert into @countries values (2401, '2401 Denmark')
insert into @countries values (2402, '2402 Faeroe Islands')
insert into @countries values (2403, '2403 Finland')
insert into @countries values (2404, '2404 Greenland')
insert into @countries values (2405, '2405 Iceland')
insert into @countries values (2406, '2406 Norway')
insert into @countries values (2407, '2407 Sweden')
insert into @countries values (3000, '3000 Southern and Eastern Europe')
insert into @countries values (3100, '3100 Southern Europe')
insert into @countries values (3101, '3101 Andorra')
insert into @countries values (3102, '3102 Gibraltar')
insert into @countries values (3103, '3103 Holy See')
insert into @countries values (3104, '3104 Italy')
insert into @countries values (3105, '3105 Malta')
insert into @countries values (3106, '3106 Portugal')
insert into @countries values (3107, '3107 San Marino')
insert into @countries values (3108, '3108 Spain')
insert into @countries values (3200, '3200 South Eastern Europe')
insert into @countries values (3201, '3201 Albania')
insert into @countries values (3202, '3202 Bosnia and Herzegovina')
insert into @countries values (3203, '3203 Bulgaria')
insert into @countries values (3204, '3204 Croatia')
insert into @countries values (3205, '3205 Cyprus')
insert into @countries values (3206, '3206 Macedonia (FYROM)')
insert into @countries values (3207, '3207 Greece')
insert into @countries values (3208, '3208 Moldova')
insert into @countries values (3211, '3211 Romania')
insert into @countries values (3212, '3212 Slovenia')
insert into @countries values (3214, '3214 Montenegro')
insert into @countries values (3215, '3215 Serbia')
insert into @countries values (3300, '3300 Eastern Europe')
insert into @countries values (3301, '3301 Belarus')
insert into @countries values (3302, '3302 Czech Republic')
insert into @countries values (3303, '3303 Estonia')
insert into @countries values (3304, '3304 Hungary')
insert into @countries values (3305, '3305 Latvia')
insert into @countries values (3306, '3306 Lithuania')
insert into @countries values (3307, '3307 Poland')
insert into @countries values (3308, '3308 Russia')
insert into @countries values (3311, '3311 Slovakia')
insert into @countries values (3312, '3312 Ukraine')
insert into @countries values (4000, '4000 Nth Africa & Middle East')
insert into @countries values (4100, '4100 North Africa')
insert into @countries values (4101, '4101 Algeria')
insert into @countries values (4102, '4102 Egypt')
insert into @countries values (4103, '4103 Libya')
insert into @countries values (4104, '4104 Morocco')
insert into @countries values (4105, '4105 Sudan')
insert into @countries values (4106, '4106 Tunisia')
insert into @countries values (4107, '4107 Western Sahara')
insert into @countries values (4199, '4199 North Africa nec')
insert into @countries values (4200, '4200 Middle East')
insert into @countries values (4201, '4201 Bahrain')
insert into @countries values (4202, '4202 Gaza Strip and West Bank')
insert into @countries values (4203, '4203 Iran')
insert into @countries values (4204, '4204 Iraq')
insert into @countries values (4205, '4205 Israel')
insert into @countries values (4206, '4206 Jordan')
insert into @countries values (4207, '4207 Kuwait')
insert into @countries values (4208, '4208 Lebanon')
insert into @countries values (4211, '4211 Oman')
insert into @countries values (4212, '4212 Qatar')
insert into @countries values (4213, '4213 Saudi Arabia')
insert into @countries values (4214, '4214 Syria')
insert into @countries values (4215, '4215 Turkey')
insert into @countries values (4216, '4216 United Arab Emirates')
insert into @countries values (4217, '4217 Yemen')
insert into @countries values (5000, '5000 South-East Asia')
insert into @countries values (5100, '5100 Mainland Sth-East Asia')
insert into @countries values (5101, '5101 Burma (Myanmar)')
insert into @countries values (5102, '5102 Cambodia')
insert into @countries values (5103, '5103 Laos')
insert into @countries values (5104, '5104 Thailand')
insert into @countries values (5105, '5105 Vietnam')
insert into @countries values (5200, '5200 Maritime Sth-East Asia')
insert into @countries values (5201, '5201 Brunei Darussalam')
insert into @countries values (5202, '5202 Indonesia')
insert into @countries values (5203, '5203 Malaysia')
insert into @countries values (5204, '5204 Philippines')
insert into @countries values (5205, '5205 Singapore')
insert into @countries values (5206, '5206 East Timor')
insert into @countries values (6000, '6000 North-East Asia')
insert into @countries values (6100, '6100 Chinese Asia (incl Mongolia)')
insert into @countries values (6101, '6101 China (excl SARs and Taiwan)')
insert into @countries values (6102, '6102 Hong Kong (SAR of China)')
insert into @countries values (6103, '6103 Macau (SAR of China)')
insert into @countries values (6104, '6104 Mongolia')
insert into @countries values (6105, '6105 Taiwan')
insert into @countries values (6200, '6200 Japan and the Koreas')
insert into @countries values (6201, '6201 Japan')
insert into @countries values (6202, '6202 Korea North')
insert into @countries values (6203, '6203 Korea South')
insert into @countries values (7000, '7000 Southern and Central Asia')
insert into @countries values (7100, '7100 Southern Asia')
insert into @countries values (7101, '7101 Bangladesh')
insert into @countries values (7102, '7102 Bhutan')
insert into @countries values (7103, '7103 India')
insert into @countries values (7104, '7104 Maldives')
insert into @countries values (7105, '7105 Nepal')
insert into @countries values (7106, '7106 Pakistan')
insert into @countries values (7107, '7107 Sri Lanka')
insert into @countries values (7200, '7200 Central Asia')
insert into @countries values (7201, '7201 Afghanistan')
insert into @countries values (7202, '7202 Armenia')
insert into @countries values (7203, '7203 Azerbaijan')
insert into @countries values (7204, '7204 Georgia')
insert into @countries values (7205, '7205 Kazakhstan')
insert into @countries values (7206, '7206 Kyrgyz Republic')
insert into @countries values (7207, '7207 Tajikistan')
insert into @countries values (7208, '7208 Turkmenistan')
insert into @countries values (7211, '7211 Uzbekistan')
insert into @countries values (8000, '8000 Americas')
insert into @countries values (8100, '8100 Northern America')
insert into @countries values (8101, '8101 Bermuda')
insert into @countries values (8102, '8102 Canada')
insert into @countries values (8103, '8103 St Pierre and Miquelon')
insert into @countries values (8104, '8104 United States of America')
insert into @countries values (8200, '8200 South America')
insert into @countries values (8201, '8201 Argentina')
insert into @countries values (8202, '8202 Bolivia')
insert into @countries values (8203, '8203 Brazil')
insert into @countries values (8204, '8204 Chile')
insert into @countries values (8205, '8205 Colombia')
insert into @countries values (8206, '8206 Ecuador')
insert into @countries values (8207, '8207 Falkland Islands')
insert into @countries values (8208, '8208 French Guiana')
insert into @countries values (8211, '8211 Guyana')
insert into @countries values (8212, '8212 Paraguay')
insert into @countries values (8213, '8213 Peru')
insert into @countries values (8214, '8214 Suriname')
insert into @countries values (8215, '8215 Uruguay')
insert into @countries values (8216, '8216 Venezuela')
insert into @countries values (8299, '8299 South America nec')
insert into @countries values (8300, '8300 Central America')
insert into @countries values (8301, '8301 Belize')
insert into @countries values (8302, '8302 Costa Rica')
insert into @countries values (8303, '8303 El Salvador')
insert into @countries values (8304, '8304 Guatemala')
insert into @countries values (8305, '8305 Honduras')
insert into @countries values (8306, '8306 Mexico')
insert into @countries values (8307, '8307 Nicaragua')
insert into @countries values (8308, '8308 Panama')
insert into @countries values (8400, '8400 Caribbean')
insert into @countries values (8401, '8401 Anguilla')
insert into @countries values (8402, '8402 Antigua and Barbuda')
insert into @countries values (8403, '8403 Aruba')
insert into @countries values (8404, '8404 Bahamas')
insert into @countries values (8405, '8405 Barbados')
insert into @countries values (8406, '8406 Cayman Islands')
insert into @countries values (8407, '8407 Cuba')
insert into @countries values (8408, '8408 Dominica')
insert into @countries values (8411, '8411 Dominican Republic')
insert into @countries values (8412, '8412 Grenada')
insert into @countries values (8413, '8413 Guadeloupe')
insert into @countries values (8414, '8414 Haiti')
insert into @countries values (8415, '8415 Jamaica')
insert into @countries values (8416, '8416 Martinique')
insert into @countries values (8417, '8417 Montserrat')
insert into @countries values (8418, '8418 Netherlands Antilles')
insert into @countries values (8421, '8421 Puerto Rico')
insert into @countries values (8422, '8422 St Kitts and Nevis')
insert into @countries values (8423, '8423 St Lucia')
insert into @countries values (8424, '8424 St Vincent and the Grenadines')
insert into @countries values (8425, '8425 Trinidad and Tobago')
insert into @countries values (8426, '8426 Turks and Caicos Islands')
insert into @countries values (8427, '8427 Virgin Islands British')
insert into @countries values (8428, '8428 Virgin Islands United States')
insert into @countries values (9000, '9000 Sub-Saharan Africa')
insert into @countries values (9100, '9100 Central and West Africa')
insert into @countries values (9101, '9101 Benin')
insert into @countries values (9102, '9102 Burkina Faso')
insert into @countries values (9103, '9103 Cameroon')
insert into @countries values (9104, '9104 Cape Verdi')
insert into @countries values (9105, '9105 Central African Republic')
insert into @countries values (9106, '9106 Chad')
insert into @countries values (9107, '9107 Congo')
insert into @countries values (9108, '9108 Congo Democratic Republic of')
insert into @countries values (9111, '9111 Cote d''Ivoire')
insert into @countries values (9112, '9112 Equatorial Guinea')
insert into @countries values (9113, '9113 Gabon')
insert into @countries values (9114, '9114 Gambia')
insert into @countries values (9115, '9115 Ghana')
insert into @countries values (9116, '9116 Guinea')
insert into @countries values (9117, '9117 Guinea Bissau')
insert into @countries values (9118, '9118 Liberia')
insert into @countries values (9121, '9121 Mali')
insert into @countries values (9122, '9122 Mauritania')
insert into @countries values (9123, '9123 Niger')
insert into @countries values (9124, '9124 Nigeria')
insert into @countries values (9125, '9125 Sao Tome and Principe')
insert into @countries values (9126, '9126 Senegal')
insert into @countries values (9127, '9127 Sierra Leone')
insert into @countries values (9128, '9128 Togo')
insert into @countries values (9200, '9200 Southern and East Africa')
insert into @countries values (9201, '9201 Angola')
insert into @countries values (9202, '9202 Botswana')
insert into @countries values (9203, '9203 Burundi')
insert into @countries values (9204, '9204 Comoros')
insert into @countries values (9205, '9205 Djibouti')
insert into @countries values (9206, '9206 Eritrea')
insert into @countries values (9207, '9207 Ethiopia')
insert into @countries values (9208, '9208 Kenya')
insert into @countries values (9211, '9211 Lesotho')
insert into @countries values (9212, '9212 Madagascar')
insert into @countries values (9213, '9213 Malawi')
insert into @countries values (9214, '9214 Mauritius')
insert into @countries values (9215, '9215 Mayotte')
insert into @countries values (9216, '9216 Mozambique')
insert into @countries values (9217, '9217 Namibia')
insert into @countries values (9218, '9218 Reunion')
insert into @countries values (9221, '9221 Rwanda')
insert into @countries values (9222, '9222 St Helena')
insert into @countries values (9223, '9223 Seychelles')
insert into @countries values (9224, '9224 Somalia')
insert into @countries values (9225, '9225 South Africa')
insert into @countries values (9226, '9226 Swaziland')
insert into @countries values (9227, '9227 Tanzania')
insert into @countries values (9228, '9228 Uganda')
insert into @countries values (9231, '9231 Zambia')
insert into @countries values (9232, '9232 Zimbabwe')
insert into @countries values (9299, '9299 Africa South and East')
insert into @countries values (1, 'At Sea')
insert into @countries values (3, 'Not Stated')
insert into @countries values (4, 'Unknown')
insert into @countries values (5, 'Unidentified')
insert into @countries values (911, 'Europe')
insert into @countries values (912, 'USSR - former')
insert into @countries values (913, 'Former Yugoslavia')
insert into @countries values (914, 'Czechoslovakia')
insert into @countries values (915, 'Kurdistan')
insert into @countries values (916, 'East Asia')
insert into @countries values (917, 'Asia')
insert into @countries values (918, 'Africa')
insert into @countries values (921, 'Serbia and Montenegro')
insert into @countries values (1000, 'Oceania and Antarctica')
insert into @countries values (1100, 'Australia (incl External Ter)')
insert into @countries values (1101, 'Australia')
insert into @countries values (1102, 'Norfolk Island')
insert into @countries values (1199, 'Australian External Territories nec')
insert into @countries values (1201, 'New Zealand')
insert into @countries values (1300, 'Melanesia')
insert into @countries values (1301, 'New Caledonia')
insert into @countries values (1302, 'Papua New Guinea')
insert into @countries values (1303, 'Solomon Islands')
insert into @countries values (1304, 'Vanuatu')
insert into @countries values (1400, 'Micronesia')
insert into @countries values (1401, 'Guam')
insert into @countries values (1402, 'Kiribati')
insert into @countries values (1403, 'Marshall Islands')
insert into @countries values (1404, 'Micronesia Federated States of')
insert into @countries values (1405, 'Nauru')
insert into @countries values (1406, 'Northern Mariana Islands')
insert into @countries values (1407, 'Palau')
insert into @countries values (1500, 'Polynesia (excludes Hawaii)')
insert into @countries values (1501, 'Cook Islands')
insert into @countries values (1502, 'Fiji')
insert into @countries values (1503, 'French Polynesia')
insert into @countries values (1504, 'Niue')
insert into @countries values (1505, 'Samoa')
insert into @countries values (1506, 'Samoa American')
insert into @countries values (1507, 'Tokelau')
insert into @countries values (1508, 'Tonga')
insert into @countries values (1511, 'Tuvalu')
insert into @countries values (1512, 'Wallis and Futuna')
insert into @countries values (1599, 'Polynesia (not Hawaii) nec')
insert into @countries values (1600, 'Antarctica')
insert into @countries values (1601, 'Antarctica Adelie Land (France)')
insert into @countries values (1602, 'Antarctica Argentinian Territory')
insert into @countries values (1603, 'Antarctica Australian Territory')
insert into @countries values (1604, 'Antarctica British Territory')
insert into @countries values (1605, 'Antarctica Chilean Territory')
insert into @countries values (1606, 'Queen Maud Land (Norway)')
insert into @countries values (1607, 'Ross Dependency (New Zealand)')
insert into @countries values (2000, 'North-West Europe')
insert into @countries values (2100, 'United Kingdom')
insert into @countries values (2101, 'Channel Islands')
insert into @countries values (2102, 'England')
insert into @countries values (2103, 'Isle of Man')
insert into @countries values (2104, 'Northern Ireland')
insert into @countries values (2105, 'Scotland')
insert into @countries values (2106, 'Wales')
--insert into @countries values (2200, 'Ireland')
insert into @countries values (2201, 'Ireland')
insert into @countries values (2300, 'Western Europe')
insert into @countries values (2301, 'Austria')
insert into @countries values (2302, 'Belgium')
insert into @countries values (2303, 'France')
insert into @countries values (2304, 'Germany')
insert into @countries values (2305, 'Liechtenstein')
insert into @countries values (2306, 'Luxembourg')
insert into @countries values (2307, 'Monaco')
insert into @countries values (2308, 'Netherlands')
insert into @countries values (2311, 'Switzerland')
insert into @countries values (2400, 'Northern Europe')
insert into @countries values (2401, 'Denmark')
insert into @countries values (2402, 'Faeroe Islands')
insert into @countries values (2403, 'Finland')
insert into @countries values (2404, 'Greenland')
insert into @countries values (2405, 'Iceland')
insert into @countries values (2406, 'Norway')
insert into @countries values (2407, 'Sweden')
insert into @countries values (3000, 'Southern and Eastern Europe')
insert into @countries values (3100, 'Southern Europe')
insert into @countries values (3101, 'Andorra')
insert into @countries values (3102, 'Gibraltar')
insert into @countries values (3103, 'Holy See')
insert into @countries values (3104, 'Italy')
insert into @countries values (3105, 'Malta')
insert into @countries values (3106, 'Portugal')
insert into @countries values (3107, 'San Marino')
insert into @countries values (3108, 'Spain')
insert into @countries values (3200, 'South Eastern Europe')
insert into @countries values (3201, 'Albania')
insert into @countries values (3202, 'Bosnia and Herzegovina')
insert into @countries values (3203, 'Bulgaria')
insert into @countries values (3204, 'Croatia')
insert into @countries values (3205, 'Cyprus')
insert into @countries values (3206, 'Macedonia (FYROM)')
insert into @countries values (3207, 'Greece')
insert into @countries values (3208, 'Moldova')
insert into @countries values (3211, 'Romania')
insert into @countries values (3212, 'Slovenia')
insert into @countries values (3214, 'Montenegro')
insert into @countries values (3215, 'Serbia')
insert into @countries values (3300, 'Eastern Europe')
insert into @countries values (3301, 'Belarus')
insert into @countries values (3302, 'Czech Republic')
insert into @countries values (3303, 'Estonia')
insert into @countries values (3304, 'Hungary')
insert into @countries values (3305, 'Latvia')
insert into @countries values (3306, 'Lithuania')
insert into @countries values (3307, 'Poland')
insert into @countries values (3308, 'Russia')
insert into @countries values (3311, 'Slovakia')
insert into @countries values (3312, 'Ukraine')
insert into @countries values (4000, 'Nth Africa & Middle East')
insert into @countries values (4100, 'North Africa')
insert into @countries values (4101, 'Algeria')
insert into @countries values (4102, 'Egypt')
insert into @countries values (4103, 'Libya')
insert into @countries values (4104, 'Morocco')
insert into @countries values (4105, 'Sudan')
insert into @countries values (4106, 'Tunisia')
insert into @countries values (4107, 'Western Sahara')
insert into @countries values (4199, 'North Africa nec')
insert into @countries values (4200, 'Middle East')
insert into @countries values (4201, 'Bahrain')
insert into @countries values (4202, 'Gaza Strip and West Bank')
insert into @countries values (4203, 'Iran')
insert into @countries values (4204, 'Iraq')
insert into @countries values (4205, 'Israel')
insert into @countries values (4206, 'Jordan')
insert into @countries values (4207, 'Kuwait')
insert into @countries values (4208, 'Lebanon')
insert into @countries values (4211, 'Oman')
insert into @countries values (4212, 'Qatar')
insert into @countries values (4213, 'Saudi Arabia')
insert into @countries values (4214, 'Syria')
insert into @countries values (4215, 'Turkey')
insert into @countries values (4216, 'United Arab Emirates')
insert into @countries values (4217, 'Yemen')
insert into @countries values (5000, 'South-East Asia')
insert into @countries values (5100, 'Mainland Sth-East Asia')
insert into @countries values (5101, 'Burma (Myanmar)')
insert into @countries values (5102, 'Cambodia')
insert into @countries values (5103, 'Laos')
insert into @countries values (5104, 'Thailand')
insert into @countries values (5105, 'Vietnam')
insert into @countries values (5200, 'Maritime Sth-East Asia')
insert into @countries values (5201, 'Brunei Darussalam')
insert into @countries values (5202, 'Indonesia')
insert into @countries values (5203, 'Malaysia')
insert into @countries values (5204, 'Philippines')
insert into @countries values (5205, 'Singapore')
insert into @countries values (5206, 'East Timor')
insert into @countries values (6000, 'North-East Asia')
insert into @countries values (6100, 'Chinese Asia (incl Mongolia)')
insert into @countries values (6101, 'China (excl SARs and Taiwan)')
insert into @countries values (6102, 'Hong Kong (SAR of China)')
insert into @countries values (6103, 'Macau (SAR of China)')
insert into @countries values (6104, 'Mongolia')
insert into @countries values (6105, 'Taiwan')
insert into @countries values (6200, 'Japan and the Koreas')
insert into @countries values (6201, 'Japan')
insert into @countries values (6202, 'Korea North')
insert into @countries values (6203, 'Korea South')
insert into @countries values (7000, 'Southern and Central Asia')
insert into @countries values (7100, 'Southern Asia')
insert into @countries values (7101, 'Bangladesh')
insert into @countries values (7102, 'Bhutan')
insert into @countries values (7103, 'India')
insert into @countries values (7104, 'Maldives')
insert into @countries values (7105, 'Nepal')
insert into @countries values (7106, 'Pakistan')
insert into @countries values (7107, 'Sri Lanka')
insert into @countries values (7200, 'Central Asia')
insert into @countries values (7201, 'Afghanistan')
insert into @countries values (7202, 'Armenia')
insert into @countries values (7203, 'Azerbaijan')
insert into @countries values (7204, 'Georgia')
insert into @countries values (7205, 'Kazakhstan')
insert into @countries values (7206, 'Kyrgyz Republic')
insert into @countries values (7207, 'Tajikistan')
insert into @countries values (7208, 'Turkmenistan')
insert into @countries values (7211, 'Uzbekistan')
insert into @countries values (8000, 'Americas')
insert into @countries values (8100, 'Northern America')
insert into @countries values (8101, 'Bermuda')
insert into @countries values (8102, 'Canada')
insert into @countries values (8103, 'St Pierre and Miquelon')
insert into @countries values (8104, 'United States of America')
insert into @countries values (8200, 'South America')
insert into @countries values (8201, 'Argentina')
insert into @countries values (8202, 'Bolivia')
insert into @countries values (8203, 'Brazil')
insert into @countries values (8204, 'Chile')
insert into @countries values (8205, 'Colombia')
insert into @countries values (8206, 'Ecuador')
insert into @countries values (8207, 'Falkland Islands')
insert into @countries values (8208, 'French Guiana')
insert into @countries values (8211, 'Guyana')
insert into @countries values (8212, 'Paraguay')
insert into @countries values (8213, 'Peru')
insert into @countries values (8214, 'Suriname')
insert into @countries values (8215, 'Uruguay')
insert into @countries values (8216, 'Venezuela')
insert into @countries values (8299, 'South America nec')
insert into @countries values (8300, 'Central America')
insert into @countries values (8301, 'Belize')
insert into @countries values (8302, 'Costa Rica')
insert into @countries values (8303, 'El Salvador')
insert into @countries values (8304, 'Guatemala')
insert into @countries values (8305, 'Honduras')
insert into @countries values (8306, 'Mexico')
insert into @countries values (8307, 'Nicaragua')
insert into @countries values (8308, 'Panama')
insert into @countries values (8400, 'Caribbean')
insert into @countries values (8401, 'Anguilla')
insert into @countries values (8402, 'Antigua and Barbuda')
insert into @countries values (8403, 'Aruba')
insert into @countries values (8404, 'Bahamas')
insert into @countries values (8405, 'Barbados')
insert into @countries values (8406, 'Cayman Islands')
insert into @countries values (8407, 'Cuba')
insert into @countries values (8408, 'Dominica')
insert into @countries values (8411, 'Dominican Republic')
insert into @countries values (8412, 'Grenada')
insert into @countries values (8413, 'Guadeloupe')
insert into @countries values (8414, 'Haiti')
insert into @countries values (8415, 'Jamaica')
insert into @countries values (8416, 'Martinique')
insert into @countries values (8417, 'Montserrat')
insert into @countries values (8418, 'Netherlands Antilles')
insert into @countries values (8421, 'Puerto Rico')
insert into @countries values (8422, 'St Kitts and Nevis')
insert into @countries values (8423, 'St Lucia')
insert into @countries values (8424, 'St Vincent and the Grenadines')
insert into @countries values (8425, 'Trinidad and Tobago')
insert into @countries values (8426, 'Turks and Caicos Islands')
insert into @countries values (8427, 'Virgin Islands British')
insert into @countries values (8428, 'Virgin Islands United States')
insert into @countries values (9000, 'Sub-Saharan Africa')
insert into @countries values (9100, 'Central and West Africa')
insert into @countries values (9101, 'Benin')
insert into @countries values (9102, 'Burkina Faso')
insert into @countries values (9103, 'Cameroon')
insert into @countries values (9104, 'Cape Verdi')
insert into @countries values (9105, 'Central African Republic')
insert into @countries values (9106, 'Chad')
insert into @countries values (9107, 'Congo')
insert into @countries values (9108, 'Congo Democratic Republic of')
insert into @countries values (9111, 'Cote d''Ivoire')
insert into @countries values (9112, 'Equatorial Guinea')
insert into @countries values (9113, 'Gabon')
insert into @countries values (9114, 'Gambia')
insert into @countries values (9115, 'Ghana')
insert into @countries values (9116, 'Guinea')
insert into @countries values (9117, 'Guinea Bissau')
insert into @countries values (9118, 'Liberia')
insert into @countries values (9121, 'Mali')
insert into @countries values (9122, 'Mauritania')
insert into @countries values (9123, 'Niger')
insert into @countries values (9124, 'Nigeria')
insert into @countries values (9125, 'Sao Tome and Principe')
insert into @countries values (9126, 'Senegal')
insert into @countries values (9127, 'Sierra Leone')
insert into @countries values (9128, 'Togo')
insert into @countries values (9200, 'Southern and East Africa')
insert into @countries values (9201, 'Angola')
insert into @countries values (9202, 'Botswana')
insert into @countries values (9203, 'Burundi')
insert into @countries values (9204, 'Comoros')
insert into @countries values (9205, 'Djibouti')
insert into @countries values (9206, 'Eritrea')
insert into @countries values (9207, 'Ethiopia')
insert into @countries values (9208, 'Kenya')
insert into @countries values (9211, 'Lesotho')
insert into @countries values (9212, 'Madagascar')
insert into @countries values (9213, 'Malawi')
insert into @countries values (9214, 'Mauritius')
insert into @countries values (9215, 'Mayotte')
insert into @countries values (9216, 'Mozambique')
insert into @countries values (9217, 'Namibia')
insert into @countries values (9218, 'Reunion')
insert into @countries values (9221, 'Rwanda')
insert into @countries values (9222, 'St Helena')
insert into @countries values (9223, 'Seychelles')
insert into @countries values (9224, 'Somalia')
insert into @countries values (9225, 'South Africa')
insert into @countries values (9226, 'Swaziland')
insert into @countries values (9227, 'Tanzania')
insert into @countries values (9228, 'Uganda')
insert into @countries values (9231, 'Zambia')
insert into @countries values (9232, 'Zimbabwe')
insert into @countries values (9299, 'Africa South and East')

insert into @countries values (0918, '0918')
insert into @countries values (0922, '0922')
insert into @countries values (0923, '0923')
insert into @countries values (2101, '2101')
insert into @countries values (2108, '2108')
insert into @countries values (3213, '3213')
insert into @countries values (9208, '9208')
   
insert into @countries values (922,'0922 Channel Islands, nfd')
insert into @countries values (924,'0924 Netherlands Antilles, nfd')
insert into @countries values (1513,'1513 Pitcairn Islands')
insert into @countries values (2107,'2107 Guernsey')
insert into @countries values (2108,'2108 Jersey')
insert into @countries values (2408,'2408 Aland Islands')
insert into @countries values (3216,'3216 Kosovo')
insert into @countries values (4108,'4108 Spanish North Africa')
insert into @countries values (4111,'4111 South Sudan')
insert into @countries values (8431,'8431 St Barthelemy')
insert into @countries values (8432,'8432 St Martin (French part)')
insert into @countries values (8433,'8433 Bonaire, Sint Eustatius and Saba')
insert into @countries values (8434,'8434 Curacao')
insert into @countries values (8435,'8435 Sint Maarten (Dutch part)')
insert into @countries values (922,'Channel Islands, nfd')
insert into @countries values (924,'Netherlands Antilles, nfd')
insert into @countries values (1513,'Pitcairn Islands')
insert into @countries values (2107,'Guernsey')
insert into @countries values (2108,'Jersey')
insert into @countries values (2408,'Aland Islands')
insert into @countries values (3216,'Kosovo')
insert into @countries values (4108,'Spanish North Africa')
insert into @countries values (4111,'South Sudan')
insert into @countries values (8431,'St Barthelemy')
insert into @countries values (8432,'St Martin (French part)')
insert into @countries values (8433,'Bonaire, Sint Eustatius and Saba')
insert into @countries values (8434,'Curacao')
insert into @countries values (8435,'Sint Maarten (Dutch part)')


if object_id('tempdb..#omis') is not null
 drop table #omis
 

SELECT DISTINCT TreatmentEvents.Pat_ID1, 
	TreatmentEvents.PCP_GROUP_ID AS GroupID, 
    Demographics.SS_Number          AS MedicareNumber,			-- 001 medicare number
	CASE TreatmentEvents.Display_ID
        WHEN 2 THEN ident_partial.IDA
        WHEN 3 THEN ident_partial.IDB
        WHEN 4 THEN ident_partial.IDC
        WHEN 5 THEN ident_partial.IDD
        WHEN 6 THEN ident_partial.IDE
        WHEN 17 THEN ident_partial.IDF
    END AS MRN,
    ident_partial.IDA AS [UniqueIdentifier],  --AUID,

	ident_partial.IDA as MRN2 ,																	/********** CHANGE PER HOSPITAL *********/
	ident_partial.IDC AS [UniqueIdentifier2],    --AUID,  -- 003 patient area unique identifier  /********** CHANGE PER HOSPITAL *********/
	replace(Demographics.First_Name,',',' ')         AS GivenName1,   -- 004 first given name
    case when len(Demographics.Middle_Name) < 2 then null else replace(Demographics.Middle_Name,',',' ') end  AS GivenName2,   -- 005 second given name
    replace(Demographics.Last_Name,',',' ')           AS Surname, 
    case when len(Demographics.Alias_Name) < 2 then null else replace(replace(Demographics.Alias_Name,',',' '),'"','') end AS AliasSurname,	-- 007 alias surname
    case Demographics.Gender when 'M' then 1
		when 'Male' then 1
		when ' Male     ' then 1
		when 'F' then 2
		when 'Female' then 2 
		when 'Female    ' then 2 
		when ' Female   ' then 2 
		when 'Indetermin' then 3
		when 'Unknown' then 9
		when 'Unknown   ' then 9
		else 9
	end as   Sex,
    cast( Demographics.Birth_DtTm as date) AS DateOfBirth, 
	replace(Demographics.Birth_Place,',','')        AS Birth_Place_original, 
	isnull(Demographics.Birth_Place_SACC,3)        AS COBCodeSACC,   -- Demographics.Birth_Place        AS Birth_Place, 
    Demographics.Alias_Name         AS AliasGivenName1, 
    rtrim(replace(replace(Demographics.Pat_Adr1 +' '+ Demographics.Pat_Adr2,',',' - '),'.','')) AS WayfareAddress,  -- UsualResidentialAddress,
    replace(Demographics.Pat_City,',',' - ')           AS Locality,
    Demographics.Pat_Postal         AS Postcode,
	Demographics.Pat_State          AS WayfareStateID_original,
	Demographics.Pat_State_code          AS WayfareStateID,
	Demographics.indigenous_status               AS IndigenousStatusID_original,
	isnull(indigenious.code,9) as IndigenousStatusID,
	--external_staff.GPAHPRA			 AS AmoRegReferringNumber,   -- AMO_AHPRARegNumberGP, 
	--external_staff.GPName                      AS DoctorName,	-- 024 GP's name 
	staff_details.OncAHPRA	 AS AmoRegReferringNumber,    -- oncologist
	staff_details.OncName      AS DoctorName,			 -- oncologist
	--TreatmentEvents.address1 + ', ' + TreatmentEvents.address2 + ', ' + TreatmentEvents.locality + ', ' + TreatmentEvents.State_Province + ' ' + TreatmentEvents.Postal AS AddressOnc, 
    coalesce(drugs.hosp_code, rtrim(TreatmentEvents.CellPhone))  AS TreatingFacilityCode,  -- HospitalID,     -- Hospital number      /* User Defined Entries (Location Not Decided Yet)*/ 
    --TreatmentEvents.Pager           AS FacilityCode,   --  Phone_Ex as DepartmentID,   	-- 030 cancer department number        /* User Defined Entries (Location Not Decided Yet)*/ 
    coalesce(drugs.facility_code,(case TreatmentEvents.pager when 'H935' then 'H933' when 'H936' then 'H934' when 'H937' then 'F298' else TreatmentEvents.pager end))  AS FacilityCode,   -- move all rad onc to med onc equivalent
	cast( MedicalRecords.Dx_DtTm1 as date)     AS	DateOfDiagnosis,		 -- PrimaryDiagnosisDate, 
	MedicalRecords.Topography1       AS	CancerSiteCodeID,		-- PrimarySiteOfCancerCode,  
    CASE WHEN MedicalRecords.Diag_Type1 = 4 THEN 'ICDO3'-- TODO confirm this
		WHEN MedicalRecords.Diag_Type1 = 2 THEN (case when MedicalRecords.Dx_DtTm1 <= '28-feb-2016' then 'ICD10V6' else 'ICD10V9' end )
		ELSE 'ICD10V9'
	END AS CancerSiteCodeIDVersion,   ---PrimarySiteOfCancerVersion, --(MOSAIQ>=2.41)  
    CASE WHEN MedicalRecords.Histology is not null  THEN 'ICDO3' -- TODO confirm this    -- and MedicalRecords.Diag_Type1 in (2,4)
		ELSE NULL
	END AS MorphologyCodeIDVersion,   ---PrimarySiteOfCancerVersion, --(MOSAIQ>=2.41) 
	Diag_Confirm1     AS BestBasisOfDiagnosisID_original,  
	isnull(cancerdiagnosis.code, 3) as BestBasisOfDiagnosisID,
	MedicalRecords.Paired_Organ     AS Laterality_original,	-- 035 laterality of primary cancer
	laterality.code as Laterality,
	case isnumeric(MedicalRecords.Hist_Grade) when 1 then MedicalRecords.Hist_Grade else 9 end   AS HistopathologicalGradeID,	-- 036 histopathalogical grade 
    MedicalRecords.Histology        AS MorphologyCodeID,	-- 037 morphology code       --'ICDO3'  AS MorphologyCodeVersion, 
	9     AS DegreeOfSpreadID,		-- if Medical.Dist_Mets_1 != '' then 4  else 9 
	cast( staging.Dx_DtTm1 as date)          AS TNMStagingDate,
	staging.T_Stage1          AS TStageID_original,
	staging.N_Stage1          AS NStageID_original,
	staging.M_Stage1          AS MStageID_original,
	staging.T_Stage1          AS TStageID,
	staging.N_Stage1          AS NStageID,
	staging.M_Stage1          AS MStageID,
	staging.combined_stage    AS TNMStagingGroupID,
	case staging.StageType1 when 0 then 'C' when 1 then 'P' else null end  AS TNMStagingBasisID,
	null   AS OtherStagingDate,   --convert(varchar(10), isnull(everything.other_stage_DtTm ,'01-01-9999'),103)      AS OtherStagingDate,
	null    AS OtherStagingSchemeID,
	null     AS OtherStagingGroupID,	-- 059 other staging grouping code
	null     AS OtherStagingBasisID,
	TreatmentEvents.Tx_Intent    AS  EpisodeIntentID_original,  -- TreatmentReasonID,	-- 062 intention of treatment
	episodeintent.code as EpisodeIntentID,
	case TreatmentEvents.row when 1 then 1 else 2 end AS InitialTreatmentFlag,  --Indicator,
    CASE WHEN first_admin.first_admin_date is not null	THEN cast(first_admin.first_admin_date as date)
		 --WHEN TreatmentEvents.DI_DtTm < TreatmentEvents.Start_Date	THEN cast(TreatmentEvents.DI_DtTm as date)
		 ELSE cast(TreatmentEvents.Start_Date as date) 
    END as EpisodeStartDate,  --SystemicTherapyStartDate,		-- 067 treatment start date
	--cast(first_admin.first_admin_date as date) as EpisodeStartDate, 
  --  CASE WHEN  last_admin.last_admin_date is not null THEN cast(last_admin.last_admin_date as date)
		--when TreatmentEvents.Discontinue_DtTm is not null then cast(TreatmentEvents.Discontinue_DtTm as date)
		--ELSE cast(TreatmentEvents.End_Date as date) 
  --  END  AS EpisodeEndDate,   -- SystemicTherapyEndDate,  	-- 068 treatment end date
	cast(last_admin.last_admin_date as date) AS EpisodeEndDate,
   -- CASE WHEN TreatmentEvents.Discontinue_DtTm IS NOT NULL and last_admin.last_admin_date is not null and cast(TreatmentEvents.Discontinue_DtTm as date) < cast(last_admin.last_admin_date as date) THEN TreatmentEvents.delivered_instances 
		 --else last_admin.last_cycle_number
   -- END  AS AntiNeoplasticCycles,   -- SystemicTherapyEndDate,  	-- 068 treatment end date
   last_admin.last_cycle_number  AS AntiNeoplasticCycles,
	TreatmentEvents.Regimen         AS ProtocolID,   -- SystemicTherapyProtocolID, eviQ protocal ID
    drugs.regimen_cycle_number   AS NotificationEpisodeChemoCycle,   --SystemicTherapyProtocolCycleNo,	-- 071 reported cycle number   , drug number
	drugs.drug_name        AS OMISDrugName,   --SystemicTherapyDrug,		-- 072 systemic therapy drug name 
	drugs.dose1             AS NotificationEpisodeChemoDose,   --SystemicTherapyDose,	-- 073 Dose 
	drugs.route            AS NotificationEpisodeChemoRouteID_original,   --SystemicTherapyRoute,	-- 074 Route 
	drugadminroute.code  AS NotificationEpisodeChemoRouteID,
	cast(drugs.start_date1 as date)       AS NotificationEpisodeChemoStartDate,   --SystemicTherapyStart, 
	cast(drugs.end_date1 as date)        AS NotificationEpisodeChemoEndDate,   --SystemicTherapyEnd, 
	drugs.frequency1        AS NotificationEpisodeChemoFrequency,   --SystemicTherapyFrequency, 
	drugs.frequency_unit   AS NotificationEpisodeChemoFrequencyUnit,   --SystemicTherapyFrequencyUnit,
	drugs.day_of_week      AS NotificationEpisodeChemoDay,   --SystemicTherapyDay,
	 
    cast(coalesce(MedicalRecords.ReferralDate1,MedicalRecords.ReferralDate2) as date)     AS ReferralDate,
    cast(MedicalRecords.Diag_DtTm1 as date)        AS ConsultationDate,
    cast(MedicalRecords.DtTm_Reg as date)         AS ClinicalTrialDate,   --FirstClinicalTrialDate,
    MedicalRecords.Trial_Short_Desc AS ClinicalTrialName,	--FirstClinicalTrialName,	-- 106 name of trial
    cast(MedicalRecords.Act_DtTm1 as date)         AS MDTDate,	-- 107 date of MDT consultation 
    cast(MedicalRecords.PalativeDate as date)     AS ReferalToPalliativeCareDate,    --DateOfReferalToPalliativeCare, 
	cast(Assessment1.Obs_DtTm as date)                            AS PerformanceStatusDate, 
    MAX(Assessment1.ecog_value) OVER (PARTITION BY Demographics.Pat_ID1,TreatmentEvents.Start_DtTm1) AS PerformanceStatus,
	TreatmentEvents.CPL_ID,
	TreatmentEvents.CPlan_Name,
	TreatmentEvents.Regimen
into #omis
FROM
-- in each part of the query we get the Patient Demographic data, as that has to remain constant, and combine it with one of the other queries.
-- the three non-used queries are saved as null
-- hopefully the database is smart enough to only run the Demographic query once.
( 
  (
/* ------------------------------ Treatment Events Query ---------------------------------------- */
		(SELECT DISTINCT patient_care_plan.PCP_ID, 
			patient_care_plan.Pat_ID1, 
			patient_care_plan.Med_ID, 
			patient_care_plan.MD_ID, 
			patient_care_plan.CPL_ID, 
			patient_care_plan.Tx_Intent, 
			initial_treatment.row,
			patient_care_plan.Protocol, 
			patient_care_plan.Chemo, 
			patient_care_plan.Hormone, 
			patient_care_plan.Immuno, 
			patient_care_plan.Start_DtTm1, 
			patient_care_plan.End_DtTm1,
			patient_care_plan.Discontinue_DtTm, 
			patient_care_plan.PCP_GROUP_ID, 
			patient_care_plan.delivered_instances,
			patient_care_plan.CPlan_Name, 
			patient_care_plan.Regimen, 
			patient_care_plan.Start_Date, 
			patient_care_plan.End_Date, 
			patient_care_plan.DI_DtTm, --patient_care_plan.End_DtTm1, --Debug
			TreatmentLocation.Inst_ID, 
			TreatmentLocation.Phone_Ex, 
			TreatmentLocation.CellPhone, 
			TreatmentLocation.address1, 
			TreatmentLocation.address2, 
			TreatmentLocation.locality, 
			TreatmentLocation.State_Province, 
			TreatmentLocation.Postal, 
			TreatmentLocation.Display_ID,
			TreatmentLocation.pager
		FROM 
		(SELECT PatCPlan.PCP_ID, 
				PatCPlan.Pat_ID1, 
				PatCPlan.Med_ID, 
				--PatCPlan.MD_ID,
				doctors_id.MD_ID,
				PatCPlan.CPL_ID, 
				PatCPlan.Tx_Intent,
				PatCPlan.Protocol, 
				PatCPlan.Chemo, 
				PatCPlan.Hormone, 
				PatCPlan.Immuno,
				CycleEffDate.Start_DtTm1, 
				CycleEffDate.End_DtTm1, 
				PatCPlan.Discontinue_DtTm, 
				CycleEffDate.Start_Date, 
				CycleEffDate.End_Date, 
				CycleEffDate.DI_DtTm, 
				care_plan1.CPlan_Name, 
				care_plan1.Regimen, 
				CycleEffDate.PCP_GROUP_ID,
				MAX(CycleEffDate.This_Instance) OVER (PARTITION BY CycleEffDate.PCP_GROUP_ID) AS delivered_instances
			FROM PatCPlan with (nolock)
			join 
			(SELECT DISTINCT RealDate.PCP_ID, 
					RealDate.PCP_GROUP_ID, 
					RealDate.DI_DtTm,
					RealDate.This_Instance,
					MIN(RealDate.Adm_DtTm) OVER (PARTITION BY RealDate.PCP_ID) AS Start_DtTm1, 
					MAX(RealDate.End_DtTm1) OVER (PARTITION BY RealDate.PCP_ID) AS End_DtTm1,
					MIN(RealDate.Adm_DtTm) OVER (PARTITION BY RealDate.PCP_GROUP_ID) AS Start_Date,
					MAX(RealDate.End_DtTm) OVER  (PARTITION BY RealDate.PCP_GROUP_ID) AS End_Date
				FROM
				(SELECT MIN(PatCPlan.Eff_DtTm) OVER (PARTITION BY PatCPlan.PCP_GROUP_ID) AS DI_DtTm
						, PatCPlan.PCP_GROUP_ID
						, PatCPlan.PCP_ID
						, PatCPlan.End_DtTm
						, PatCPlan.This_Instance
						, pharmacy_administration.Adm_DtTm
						, CASE WHEN   care_plan_activity.Type1 & 1 = 1 and  CPItem.Day_Offset is not null THEN (pharmacy_administration.Adm_DtTm + (CPlan.Cycle_Length - CPItem.Day_Offset) - 1)
							when   care_plan_activity.Type1 & 1 = 1 then (pharmacy_administration.Adm_DtTm + CPlan.Cycle_Length - 1) 
							END AS End_DtTm1
						, CASE WHEN care_plan_activity.Type1 & 1 = 1  THEN pharmacy_administration.Adm_DtTm 
							END AS End_Date2
					FROM  PatCPlan with (nolock)
						INNER JOIN CPlan with (nolock) ON PatCPlan.CPL_ID = CPlan.CPL_ID 
						INNER JOIN Orders AS pharm_orders with (nolock) ON PatCPlan.Pat_ID1 = pharm_orders.Pat_ID1 and  pharm_orders.Cycle_Number IS NOT NULL
							AND pharm_orders.Cycle_Day IS NOT NULL 
							AND pharm_orders.PCI_ID IS NOT NULL  
							AND pharm_orders.Version = 0 
							AND pharm_orders.Status_Enum NOT IN (1)
						INNER JOIN PharmAdm AS pharmacy_administration with (nolock) ON PatCPlan.Pat_ID1 = pharmacy_administration.Pat_ID1 AND pharm_orders.ORC_SET_ID = pharmacy_administration.ORC_SET_ID
							and  pharmacy_administration.Version = 0 
							AND pharmacy_administration.Adm_DtTm IS NOT NULL 
							AND pharmacy_administration.Status_Enum NOT IN (1)
						INNER JOIN PatCItem AS patient_care_item with (nolock) ON PatCPlan.Pat_ID1 = patient_care_item.Pat_ID1 AND patient_care_item.PCI_ID = pharm_orders.PCI_ID AND patient_care_item.PCP_ID = PatCPlan.PCP_ID
						LEFT OUTER JOIN CPItem with (nolock) ON patient_care_item.CPI_ID = CPItem.CPI_ID
						INNER JOIN CPAct AS care_plan_activity with (nolock) ON care_plan_activity.CPA_ID = pharm_orders.CPA_ID
							and ((care_plan_activity.Type1 & 1) = 1   or (care_plan_activity.Type1 & 4) = 4)
				) AS RealDate
			) AS CycleEffDate on PatCPlan.PCP_ID = CycleEffDate.PCP_ID	and (CONVERT(date,CycleEffDate.End_DtTm1) BETWEEN @startdate AND dateadd(d,1,@enddate))			/* Start/End Date Of The Cycles & Protocols */                                
			join CPlan  AS care_plan1 with (nolock) on care_plan1.CPL_ID = PatCPlan.CPL_ID
			--join (SELECT PCP_ID, MAX(PCP_ID) OVER (PARTITION BY PCP_Group_ID) AS max_pcp_id, PCP_Group_ID, MD_ID FROM PatCPlan with (nolock)) AS doctors_id 
			join (SELECT PCP_ID, PCP_Group_ID, MD_ID FROM PatCPlan with (nolock) where This_Instance = 1) AS doctors_id 
				on doctors_id.PCP_Group_ID = PatCPlan.PCP_Group_ID --AND doctors_id.PCP_ID = doctors_id.max_pcp_id
			WHERE PatCPlan.Discontinue_DtTm IS NULL 
				OR PatCPlan.Discontinue_DtTm >= CycleEffDate.Start_DtTm1
		) AS patient_care_plan 
		LEFT OUTER JOIN 
				(SELECT attendance_table_2.Pat_ID1, 
					attendance_table_2.Inst_ID, 
					Config.Phone_Ex, 
					Config.CellPhone, 
					RTRIM(Config.Adr1) AS address1, 
					RTRIM(Config.Adr2) AS address2, 
					RTRIM(Config.City) AS locality, 
					Config.State_Province, 
					Config.Postal, 
					Config.Display_ID ,
					config.pager
				from (select Pat_ID1, Inst_ID, COUNT(Inst_ID) AS total, ROW_NUMBER() OVER (PARTITION BY Pat_ID1 ORDER BY COUNT(Inst_ID) DESC ) AS row
						FROM schedule with (nolock), Staff with (nolock)
						where Schedule.Location = Staff.Staff_ID
							and schedule.version = 0
						group by Pat_ID1, Inst_ID
					) AS attendance_table_2
					join Config with (nolock) on Config.Inst_ID = attendance_table_2.Inst_ID and attendance_table_2.row = 1 
			) AS TreatmentLocation ON TreatmentLocation.Pat_ID1 = patient_care_plan.Pat_ID1
		LEFT OUTER JOIN
		(select  PCP_Group_ID,  1 AS row  --p.Pat_ID1, p.MED_ID,
		from PatCPlan p  with (nolock)
			join (select p.Pat_ID1, p.MED_ID, min(p.Eff_DtTm) as Eff_DtTm
				from Medical m with (nolock)
					join PatCPlan p with (nolock) on m.MED_ID = p.MED_ID
					join CPlan c with (nolock) on p.CPL_ID = c.CPL_ID
				where m.Related_MED_ID is null
					and m.Diagnosis_Class = 1 
					and c.Intervention = 1
					and p.Status_Enum in (2,3,5,23)
				group by p.Pat_ID1, p.MED_ID
				--having  min(p.Eff_DtTm) between @startdate and dateadd(d,1,@enddate)
					) a on p.Pat_ID1 = a.Pat_ID1 and p.MED_ID = a.MED_ID and p.Eff_DtTm = a.Eff_DtTm 
		and p.Status_Enum in (2,3,5,23)
		) as initial_treatment ON initial_treatment.PCP_Group_ID = patient_care_plan.PCP_Group_ID
	) AS TreatmentEvents

	left join @episodeintent episodeintent on episodeintent.name = TreatmentEvents.Tx_Intent

	LEFT OUTER JOIN
	/* ------------------------------ Assessment Query --------------------------------------------- */
	(SELECT coalesce(PrePivotAssessment1.Pat_ID1,PrePivotAssessment2.Pat_ID1) as patient
		, PrePivotAssessment1.ChoiceValue AS ecog_value
		, PrePivotAssessment1.Obs_DtTm
		, PrePivotAssessment2.ChoiceValue AS Treatment_Outcome
		FROM 
		( SELECT observation_request.OBR_ID
				, observation_request.Pat_ID1
				, observation_definition.OBD_ID
				, observation_request.Obs_DtTm

				, observation_definition.Label
				, observation_definition2nd.Label AS ChoiceValue
				--, MAX(observation_definition2nd.ChoiceLabel) OVER (PARTITION BY observation_request.Pat_ID1,observation_definition.Label) AS RowNum
				, ROW_NUMBER() OVER (PARTITION BY observation_request.Pat_ID1,observation_definition.Label ORDER BY observation_definition2nd.Label DESC) AS RowNum
			FROM Observe AS Observe1 with (nolock)
				INNER JOIN ObsDef AS observation_definition with (nolock) ON Observe1.OBD_ID = observation_definition.OBD_ID and observation_definition.Label like '%ECOG%'
				INNER JOIN ObsDef AS observation_definition2nd with (nolock) ON Observe1.Obs_Choice = observation_definition2nd.OBD_ID
				INNER JOIN ObsReq AS observation_request with (nolock) ON observation_request.Pat_ID1 = Observe1.Pat_ID1 AND observation_request.OBR_ID = Observe1.OBR_SET_ID and observation_request.Version = 0 AND observation_request.Status_Enum NOT IN (1)
			WHERE  CONVERT(date,observation_request.Obs_DtTm) between @startdate AND dateadd(d,1,@enddate)
		) AS PrePivotAssessment1
		FULL OUTER JOIN 
		(SELECT observation_request.OBR_ID
				, observation_request.Pat_ID1
				, observation_definition.OBD_ID
				, observation_request.Obs_DtTm
				, observation_definition.Label
				, observation_definition2nd.Label AS ChoiceValue
				, ROW_NUMBER() OVER (PARTITION BY observation_request.Pat_ID1,observation_definition.Label ORDER BY observation_definition2nd.Label DESC) AS RowNum
			FROM  Observe AS Observe1 with (nolock)
				INNER JOIN  ObsDef AS observation_definition with (nolock) ON Observe1.OBD_ID = observation_definition.OBD_ID and observation_definition.Label in ('Def / Neo [Ch&RT]', 'Palliative')
				INNER JOIN  ObsDef AS observation_definition2nd with (nolock) ON Observe1.Obs_Choice = observation_definition2nd.OBD_ID
				INNER JOIN  ObsReq AS observation_request with (nolock) ON observation_request.Pat_ID1 = Observe1.Pat_ID1 AND observation_request.OBR_ID = Observe1.OBR_SET_ID and  observation_request.Version = 0 AND observation_request.Status_Enum NOT IN (1)
			WHERE CONVERT(date,observation_request.Obs_DtTm) between @startdate AND dateadd(d,1,@enddate)
		) AS PrePivotAssessment2 ON PrePivotAssessment2.pat_id1 = PrePivotAssessment1.Pat_ID1
		WHERE (PrePivotAssessment1.RowNum = 1 or PrePivotAssessment1.RowNum IS NULL)
			AND (PrePivotAssessment2.RowNum = 1 or PrePivotAssessment2.RowNum IS NULL)
	) AS Assessment1 ON TreatmentEvents.Pat_ID1 = Assessment1.patient
	/* ------------------------------ Demographic Query -------------------------------------------- */
	LEFT OUTER JOIN
	(SELECT patient_details.Pat_ID1, 
		patient_details.SS_Number, 
		patient_details.Salutation, 
		patient_details.First_Name, 
		patient_details.Middle_Name, 
		patient_details.Last_Name, 
		patient_details.Alias_Name, 
		patient_details.Birth_DtTm, 
		Admin1.Gender, 
		Admin1.Birth_Place, 
		isnull(cc.code,4) as Birth_Place_SACC,
		Admin1.Pat_Adr1, 
		Admin1.Pat_Adr2, 
		Admin1.Pat_City, 
		Admin1.Pat_State, 
		isnull(ss.code,'99') as Pat_State_code, 
		Admin1.Pat_Postal,		
		CASE WHEN Admin1.Race != '' THEN Admin1.Race ELSE CASE WHEN Race_prompt.Text IS NOT NULL THEN Race_prompt.Text ELSE Ethnicity_prompt.text END END AS indigenous_status,
		Admin1.Expired_DtTm, 
		Admin1.Ref_Md2_ID as GP_ID
	FROM Patient AS patient_details with (nolock)
		join Admin as admin1 with (nolock) on patient_details.Pat_ID1 = Admin1.Pat_ID1
		LEFT OUTER JOIN 
			( SELECT ADM_ID, MAX(PRO_ID) AS PRO_ID_m
				FROM Race with (nolock)
				GROUP BY ADM_ID
			) AS partial_race ON Admin1.ADM_ID = partial_race.ADM_ID
		LEFT OUTER JOIN Prompt AS Race_prompt with (nolock) ON Race_prompt.Pro_ID = partial_race.PRO_ID_m
		LEFT OUTER JOIN prompt AS Ethnicity_prompt with (nolock) ON Ethnicity_prompt.Pro_ID = Admin1.Ethnicity_PRO_ID
		left join @countries cc on cc.name = Admin1.Birth_Place
		left join @states ss on ss.name = Admin1.Pat_State
	) AS Demographics
	ON Demographics.Pat_ID1 = TreatmentEvents.Pat_ID1
	left join @indigenious indigenious on indigenious.name = Demographics.indigenous_status
	/* ------------------------------ Medical Records Query ---------------------------------------- */
	LEFT OUTER JOIN
	(
		SELECT Medical1.MED_ID, 
			Medical1.Pat_ID1, 
			Medical1.Diagnosis_Class, 
			PalativeDate.Encounter_DtTm AS PalativeDate, 
			MDT1.Act_DtTm1,
			Medical1.Topography1, 
			Medical1.Diag_Type1, 
			Medical1.Diag_Confirm1, 
			Medical1.Paired_Organ, 
			Medical1.Hist_Grade, 
			Medical1.Histology,
			Medical1.Dx_DtTm1, 
			Medical1.RDx_DtTm2, 
			--Medical1.Diag_DtTm1, 
			consultation.Act_DtTm1 AS Diag_DtTm1, 
			Medical1.RDiag_DtTm2, 
			Medical1.RDiag_Confirm2, 
			Medical1.RTopography2, 
			Medical1.RDiag_Type2,
			patient_trial.Trial_Short_Desc, 
			patient_trial.DtTm_Reg, 
			ReferralDateTable.Eff_DtTm1 AS ReferralDate1, 
			ReferralDateTable2.Eff_DtTm1 AS ReferralDate2, 
			ConsentDate.Encounter_DtTm AS ConsentDate, 
			Medical1.Dist_Mets_1
		FROM ( 
			SELECT Medical.MED_ID, 
				Medical.Pat_ID1, 
				Medical.Paired_Organ,
				Medical.Histology, 
				Medical.Hist_Grade, 
				Medical.Diagnosis_Class, 
				Medical.Dist_Mets_1, 
				CASE WHEN Medical.Diagnosis_Class in (5,2) THEN coalesce(MedicalPrimary.Dx_Partial_DtTm, Medical.Dx_Partial_DtTm)  ELSE Medical.Dx_Partial_DtTm END AS RDx_DtTm2,		-- class 5 = re-occurence
				CASE WHEN Medical.Diagnosis_Class in (5,2) THEN coalesce(MedicalPrimary.Diag_Confirm,Medical.Diag_Confirm)		ELSE Medical.Diag_Confirm END AS RDiag_Confirm2,
				CASE WHEN Medical.Diagnosis_Class in (5,2) THEN coalesce(MedicalPrimary.Dx_Partial_DtTm,Medical.Dx_Partial_DtTm)  ELSE Medical.Dx_Partial_DtTm END AS RDiag_DtTm2,
				CASE WHEN Medical.Diagnosis_Class in (5,2) THEN coalesce(TopogP.Diag_Code,Topog.Diag_Code)				ELSE Topog.Diag_Code  END AS RTopography2, --(MOSAIQ>=2.41)
				CASE WHEN Medical.Diagnosis_Class in (5,2) THEN coalesce(TopogP.Diag_Type,Topog.Diag_Type)				ELSE Topog.Diag_Type END AS RDiag_Type2, --(MOSAIQ>=2.41)
				CASE WHEN Medical.Diagnosis_Class in (5,2) THEN coalesce(MedicalPrimary.Dx_Partial_DtTm,Medical.Dx_Partial_DtTm)  ELSE Medical.Dx_Partial_DtTm  END AS Dx_DtTm1,
				CASE WHEN Medical.Diagnosis_Class in (5,2) THEN coalesce(MedicalPrimary.Diag_Confirm,Medical.Diag_Confirm)		ELSE Medical.Diag_Confirm  END AS Diag_Confirm1,
				CASE WHEN Medical.Diagnosis_Class in (5,2) THEN coalesce(MedicalPrimary.Dx_Partial_DtTm,Medical.Dx_Partial_DtTm)  ELSE Medical.Dx_Partial_DtTm  END AS Diag_DtTm1_old,
				CASE WHEN Medical.Diagnosis_Class in (5,2) THEN coalesce(MedicalPrimary.Diag_Partial_DtTm,Medical.Diag_Partial_DtTm)  ELSE  Medical.Diag_Partial_DtTm  END AS Diag_DtTm1,
				CASE WHEN Medical.Diagnosis_Class in (5,2) THEN coalesce(TopogP.Diag_Code,Topog.Diag_Code)	ELSE  Topog.Diag_Code END AS Topography1, --(MOSAIQ>=2.41)
				CASE WHEN Medical.Diagnosis_Class in (5,2) THEN coalesce(TopogP.Diag_Type,Topog.Diag_Type)	ELSE Topog.Diag_Type END AS Diag_Type1 --(MOSAIQ>=2.41) 
			FROM Medical  with (nolock)
			left join Medical AS MedicalPrimary with (nolock) ON MedicalPrimary.MED_ID = Medical.Related_MED_ID and MedicalPrimary.Related_MED_ID  is null and MedicalPrimary.Diagnosis_Class = 1  --- = MedicalPrimary.MED_ID and MedicalPrimary.Related_MED_ID IS NOT NULL
			left join Topog with (nolock) on Medical.TPG_ID = Topog.TPG_ID  
			left join Topog as TopogP with (nolock) on MedicalPrimary.TPG_ID = TopogP.TPG_ID  
			--where medical.Edit_DtTm BETWEEN @startdate AND dateadd(d,1,@enddate)
			--where Medical.Pat_ID1 =  85645
		) AS Medical1 
		LEFT OUTER JOIN 
		(SELECT PatTrial.Pat_ID1, Trial1.Trial_Short_Desc, min(PatTrial.DtTm_Reg) as DtTm_Reg
			FROM  PatTrial  with (nolock)
			join Trial  AS Trial1 with (nolock) on PatTrial.TRL_ID = Trial1.TRL_ID 
			where  PatTrial.Version = 0
				and Trial1.Trial_Short_Desc is not null 
				and Trial1.Trial_Short_Desc <> ''
				and trial1.Trial_Id not like '%scr%'
			group by PatTrial.Pat_ID1, Trial1.Trial_Short_Desc
		) AS patient_trial ON Medical1.Pat_ID1 = patient_trial.Pat_ID1 
		LEFT OUTER JOIN
		(SELECT Object.Pat_ID1, min(Object.Encounter_DtTm) as Eff_DtTm1  
			FROM Object with (nolock)
			WHERE Object.Status_Enum IN (5,7,9) 
				AND Object.Version = 0 
				AND Object.DocType IN (Select Prompt.Enum FROM Prompt with (nolock) WHERE Prompt.Text IN ('Referral Int. NCCI','Internal Referral','Referral Letter Recv')) 
			group by Object.Pat_ID1
		) AS ReferralDateTable ON Medical1.Pat_ID1 = ReferralDateTable.Pat_ID1 
		left join 
		(SELECT Pat_Pay.Pat_ID1,
                    MIN(Pat_Pay.Effective_DtTm) OVER (PARTITION BY Pat_Pay.Pat_ID1) AS Eff_DtTm1
             FROM Pat_Pay with (nolock)) AS ReferralDateTable2 ON Medical1.Pat_ID1 = ReferralDateTable2.Pat_ID1
		LEFT OUTER JOIN
		(SELECT Object.Pat_ID1, min(Object.Encounter_DtTm) as Encounter_DtTm 
			FROM Object with (nolock)
			WHERE Object.Status_Enum IN (3,5,7,8,9) 
				AND Object.Version = 0 
				AND Object.DocType IN (Select Prompt.Enum FROM Prompt with (nolock) WHERE Prompt.Text IN ('Chemo Consent Form'))
			group by Object.Pat_ID1
		) AS ConsentDate ON Medical1.Pat_ID1 = ConsentDate.Pat_ID1 
		LEFT OUTER JOIN
		--(SELECT Object.Pat_ID1, min(Object.Encounter_DtTm) as Encounter_DtTm 
		--	FROM Object
		--		INNER JOIN Staff ON Object.Review_ID = Staff.Staff_ID
		--	WHERE Object.Status_Enum IN (5,7,9)
		--		AND Object.Version = 0
		--		AND Object.DocType IN (Select Prompt.Enum FROM Prompt WHERE Prompt.Text like 'pall%')  --IN ('Referral Letter', 'Internal Referrals'))
		--		AND Staff.Type = 'Pall Care'
		--	group by Object.Pat_ID1
		--) AS PalativeDate ON Medical1.Pat_ID1 = PalativeDate.Pat_ID1 
		(select pat_id1, min(App_DtTm) as Encounter_DtTm from schedule with (nolock) where Activity in (select hsp_code from cpt with (nolock) where Description like '%pal%new%') group by pat_id1)  AS PalativeDate ON Medical1.Pat_ID1 = PalativeDate.Pat_ID1 
		LEFT OUTER JOIN

		(SELECT Schedule.Pat_ID1, min(Schedule.App_DtTm)  AS Act_DtTm1 
			FROM Schedule with (nolock)
			WHERE Schedule.Activity IN (select hsp_code from cpt with (nolock) where Description like '%mdt%') 
				and App_DtTm > (select isnull(dateadd(d,-30,min(Dx_Partial_DtTm)),'1900-01-01') from Medical with (nolock) where Diagnosis_Class = 1  and pat_id1=Schedule.Pat_ID1)  -- and Dx_Partial_DtTm is not null
			group by Schedule.Pat_ID1
		) AS MDT1 ON Medical1.Pat_ID1 = MDT1.Pat_ID1
		
		LEFT OUTER JOIN  
		(SELECT Schedule.Pat_ID1, min(Schedule.App_DtTm)  AS Act_DtTm1 
				FROM Schedule with (nolock)
				WHERE Schedule.Activity IN (select hsp_code from cpt with (nolock) where CGroup in ('con'))  -- 'mo' ,'haem', 'chiv'
					--and App_DtTm >= (select isnull(dateadd(d,0,min(Dx_DtTm)),'1900-01-01') from Medical where Diagnosis_Class = 1  and pat_id1=Schedule.Pat_ID1)  -- and Dx_DtTm is not null
				group by Schedule.Pat_ID1
			) AS Consultation ON Medical1.Pat_ID1 = Consultation.Pat_ID1
	) AS MedicalRecords
	ON MedicalRecords.PAT_ID1 = TreatmentEvents.Pat_ID1 AND MedicalRecords.MED_ID = TreatmentEvents.MED_ID

	left join @cancerdiagnosis cancerdiagnosis on cancerdiagnosis.name = MedicalRecords.Diag_Confirm1
	LEFT JOIN @laterality laterality on laterality.name = MedicalRecords.Paired_Organ 
/* ------------------------------ Doctor's information Query ----------------------------------- */
	LEFT OUTER JOIN
	( SELECT Staff.Staff_ID,
			(RTRIM(Staff.First_Name) + ' ' + RTRIM(Staff.Last_Name)) AS OncName, 
			Ext_ID.ID_Code AS OncAHPRA
		FROM Staff with (nolock)
			LEFT OUTER JOIN Ext_ID ON Staff.Staff_ID = Ext_ID.Staff_ID
		WHERE Ext_ID.Ext_Type = 'AHPRA'
	) AS staff_details ON staff_details.Staff_ID = TreatmentEvents.MD_ID	  
	/*(SELECT Staff.Staff_ID, 
		  Admin.Pat_ID1,
          RTRIM(Staff.First_Name) + ' ' + RTRIM(Staff.Last_Name) AS OncName,
          ed.ID_Code AS OncAHPRA
        FROM ADMIN
        INNER JOIN Staff ON Admin.STF_MD3_ID = Staff.Staff_ID
        LEFT OUTER JOIN  Ext_ID  ed on Staff.Staff_ID = ed.Staff_ID and ed.Ext_Type = 'AHPRA' 
	)	AS staff_details ON   staff_details.Pat_ID1  =  TreatmentEvents.Pat_ID1    -- staff_details.Staff_ID = TreatmentEvents.MD_ID	*/ 
	LEFT OUTER JOIN
	( SELECT CASE WHEN id_table.External_ID IS NULL 
				THEN ltrim(RTRIM(staff_details_table.Suffix) + ' ' +RTRIM(staff_details_table.First_Name) + ' ' + RTRIM(staff_details_table.Last_Name))
				ELSE ltrim(RTRIM(external_details_table.Suffix) + ' ' +RTRIM(external_details_table.First_Name) + ' ' + RTRIM(external_details_table.Last_Name))
			END AS GPName,
			CASE WHEN id_table.External_ID IS NULL 
				THEN (RTRIM(staff_details_table.Adr1) + ', '  + RTRIM(staff_details_table.Adr2) + ', '  + RTRIM(staff_details_table.City) + ', '  + RTRIM(staff_details_table.State_Province) + ' '  + RTRIM(staff_details_table.Postal))
				ELSE (RTRIM(external_details_table.Adr1) + ', '  + RTRIM(external_details_table.Adr2) + ', '  + RTRIM(external_details_table.City) + ', '  + RTRIM(external_details_table.State_Province) + ' '  + RTRIM(external_details_table.Postal))
			END AS GPAddr,
			referrer_table.Pat_ID1, 
			ahpra_table.ID_Code AS GPAHPRA
		FROM Admin AS referrer_table with (nolock)
			LEFT OUTER JOIN PNP  AS id_table with (nolock) ON id_table.PNP_ID = referrer_table.Ref_Md2_ID
			LEFT OUTER JOIN Staff AS staff_details_table with (nolock) ON staff_details_table.Staff_ID = id_table.Staff_ID
			LEFT OUTER JOIN [External]  AS external_details_table with (nolock) ON external_details_table.External_ID = id_table.External_ID
			LEFT OUTER JOIN Ext_ID AS ahpra_table with (nolock) ON staff_details_table.Staff_ID = ahpra_table.Staff_ID OR external_details_table.External_ID = ahpra_table.External_ID and ahpra_table.Ext_Type = 'ST LICENSE'
	) AS external_staff
	ON external_staff.Pat_ID1 = TreatmentEvents.PAT_ID1
	/* ---------------------------------- IDENT query ------------------------------------------------*/
	LEFT OUTER JOIN
	(SELECT ident_version.Pat_ID1, Ident.IDA, Ident.IDB, Ident.IDC, Ident.IDD, Ident.IDE, Ident.IDF
		FROM Ident with (nolock),
			( select Pat_id1, max(version) AS row_version from Ident with (nolock) group by Pat_Id1 ) AS ident_version
		where Ident.Pat_Id1 = ident_version.Pat_Id1 and Ident.Version = ident_version.row_version
		 --and  ident_version.Pat_ID1 = 85645
	) AS ident_partial
	ON ident_partial.Pat_ID1 = TreatmentEvents.Pat_ID1
	/* --------------------------------------------------------------------------------------------- */
) -- AS main_query

	left outer join	(
/* --------------------------------- Staging Details Query    ------------------------------ */
		select  
			TNMStage.Med_ID AS stage_Med_ID1, 
			TNMStage.StageType AS StageType1, 
			TNMStage.T_Stage AS T_Stage1, 
			TNMStage.N_Stage AS N_Stage1, 
			TNMStage.M_Stage AS M_Stage1, 
			TNMStage.Stage AS combined_stage, 
			TNMStage.Edition AS Edition1, 
			Medical.PAT_ID1 AS staging_pat_id, 
			CASE Medical.Diagnosis_Class WHEN 5 THEN 2 WHEN 4 THEN 2 ELSE 1 END AS Diagnosis_Class1, -- TODO need more sophisticated rules here
			--coalesce(TNMStage.Date_Staged_DtTm, Medical.Dx_partial_DtTm)  AS Dx_DtTm1
			TNMStage.Date_Staged_DtTm   AS Dx_DtTm1
		from TNMStage  with (nolock)
			join (select med_id, max(tnm_id) as tnm_id from TNMStage with (nolock) where Edit_DtTm <= @enddate group by med_id) b on TNMStage.med_id = b.med_id and TNMStage.tnm_id = b.tnm_id
			join Medical with (nolock) on TNMStage.Med_ID = Medical.Med_ID
			join @stagegroup ts on ts.name = TNMStage.Stage
		where StageType in (0,1) 
			--and  Medical.PAT_ID1  = 85645
		    --and (Medical.Dx_partial_DtTm  between @startdate AND dateadd(d,1,@enddate))
			--	or TNMStage.Edit_DtTm between @startdate AND dateadd(d,1,@enddate))
	) as Staging on staging.staging_pat_id = Demographics.Pat_ID1 AND staging.stage_Med_ID1 = TreatmentEvents.Med_ID

	left outer join	(
/* --------------------------------- Drug Details Query    ------------------------------ */
		SELECT  distinct
			stage1.Pat_ID1 AS regimen_pat_id,
			--stage1.This_Instance AS regimen_cycle_number,
			stage1.This_Instance AS regimen_cycle_number, 
			stage1.PCP_ID AS care_plan_id,
			stage5.drug_label AS drug_name, 
			--stage4.Adm_Code AS drug_name,
			rtrim(cast(stage4.Adm_Amount as varchar(12))+' '+isnull(d.Label,'')) AS dose1, 
			stage4.Admin_Route AS route,
			--END AS route, */
			stage4.Adm_DtTm AS start_date1, 
			stage4.Adm_End_DtTm AS end_date1, 
			stage8.Cycle_Length AS frequency1, 
			1 AS frequency_unit, 
			(stage7.Day_Offset + 1 ) AS day_of_week ,
			coalesce(loc1.work_phone, loc2.work_phone) as hosp_code,
			coalesce(Loc1.work_phone_ex,Loc2.work_phone_ex) as facility_code
		FROM PatCPlan  AS stage1 with (nolock)
			INNER JOIN PatCItem AS stage2 with (nolock) ON stage1.PCP_ID = stage2.PCP_ID
			INNER JOIN Orders  AS stage3 with (nolock) ON stage2.PCI_ID = stage3.PCI_ID and stage3.Order_Type in (2, 4, 5, 6) 
			INNER JOIN PharmAdm  AS stage4 with (nolock) ON stage3.ORC_ID = stage4.ORC_Set_ID
			left join charge ch with (nolock) on ch.ORC_Set_ID = stage4.ORC_Set_ID
			left join staff loc1 with (nolock) on loc1.Staff_ID = ch.Location_ID and loc1.type = 'Location' 
			left join Schedule sch with (nolock) on sch.Sch_Id = ch.SCH_ID 
			left join staff loc2 with (nolock) on loc2.Staff_ID = sch.Location and loc2.type = 'Location' 
			INNER JOIN Drug AS stage5 with (nolock) ON stage4.Adm_Code = stage5.DRG_ID
			INNER JOIN CPItem AS stage7 with (nolock) ON stage2.CPI_ID = stage7.CPI_ID
			INNER JOIN CPlan AS stage8 with (nolock) ON stage1.CPL_ID = stage8.CPL_ID 
			left join obsdef d with (nolock) on stage4.adm_units = d.OBD_ID
		WHERE stage4.Adm_Amount >= 0 and stage4.Status_Enum in (2,3,5) and stage1.status_enum in (2,3,5,23) 
			AND (stage2.CPI_ID is NULL OR CONVERT(date, (stage4.Adm_DtTm - stage7.Day_Offset + stage8.Cycle_Length)) BETWEEN @startdate AND dateadd(d,1,@enddate))
	)  as drugs on drugs.regimen_pat_id = Demographics.Pat_ID1  AND TreatmentEvents.PCP_ID = drugs.care_plan_id 
					 							
	left join @drugadminroute drugadminroute on  drugadminroute.name = drugs.route

	left join (SELECT stage1.Pat_ID1 AS regimen_pat_id, 
			stage1.PCP_GROUP_ID AS group_id,
			stage1.This_Instance AS last_cycle_number,  
			stage4.Adm_End_DtTm AS last_admin_date,
			stage8.Cycle_Length,
			case when cast(stage4.Adm_End_DtTm as date) < dateadd(d, stage8.Cycle_Length*-2,@enddate) then 1 else 0 end as isvalid,
			row_number() over (partition by stage1.Pat_ID1, stage1.PCP_GROUP_ID  order by stage4.Adm_End_DtTm desc) as roww
		FROM PatCPlan  AS stage1 with (nolock) 
			JOIN PatCItem AS stage2 with (nolock) ON stage1.PCP_ID = stage2.PCP_ID
			JOIN Orders  AS stage3 with (nolock) ON stage2.PCI_ID = stage3.PCI_ID and stage3.Order_Type in (2, 4, 5, 6) 
			JOIN PharmAdm  AS stage4 with (nolock) ON stage3.ORC_ID = stage4.ORC_Set_ID
			JOIN CPItem AS stage7 with (nolock) ON stage2.CPI_ID = stage7.CPI_ID
			JOIN CPlan AS stage8 with (nolock) ON stage1.CPL_ID = stage8.CPL_ID
			--join drug d with (nolock) on d.DRG_ID = stage4.Adm_Code 
		WHERE stage4.Adm_Amount >= 0 
			and stage4.Status_Enum in (0,2,3,5)		-- unknown, close, complete, approve  
			and stage1.status_enum in (0,2,3,5,23)	-- unknown, close, complete, approve, discontinue
			and stage4.Adm_End_DtTm is not null
			--and d.drug_type in (select obd_id from ObsDef where label like 'antineoplastic%' or label like 'chemo%')    -- around 15% difference if only select chemo types compare to all types
	) as last_admin on last_admin.regimen_pat_id = Demographics.Pat_ID1  AND TreatmentEvents.PCP_GROUP_ID = last_admin.group_id  and last_admin.roww = 1 and last_admin.isvalid = 1

	left join (SELECT stage1.Pat_ID1 AS regimen_pat_id, 
			stage1.PCP_GROUP_ID AS group_id,
			stage1.This_Instance AS first_cycle_number,  
			stage4.Adm_End_DtTm AS first_admin_date,
			row_number() over (partition by stage1.Pat_ID1, stage1.PCP_GROUP_ID  order by stage4.Adm_End_DtTm asc) as roww
		FROM PatCPlan  AS stage1 with (nolock) 
			JOIN PatCItem AS stage2 with (nolock) ON stage1.PCP_ID = stage2.PCP_ID
			JOIN Orders  AS stage3 with (nolock) ON stage2.PCI_ID = stage3.PCI_ID and stage3.Order_Type in (2, 4, 5, 6)  -- pharmcy orders only
			JOIN PharmAdm  AS stage4 with (nolock) ON stage3.ORC_ID = stage4.ORC_Set_ID
			--join drug d with (nolock) on d.DRG_ID = stage4.Adm_Code 
		WHERE stage4.Adm_Amount >= 0 
			and stage4.Status_Enum in (0,2,3,5)		-- unknown, close, complete, approve  
			and stage1.status_enum in (0,2,3,5,23)	-- unknown, close, complete, approve, discontinue
			and stage4.Adm_End_DtTm is not null
			--and d.drug_type in (select obd_id from ObsDef where label like 'antineoplastic%' or label like 'chemo%')	-- around 15% difference if only select chemo types compare to all types
	) as first_admin on first_admin.regimen_pat_id = Demographics.Pat_ID1  AND TreatmentEvents.PCP_GROUP_ID = first_admin.group_id  and first_admin.roww = 1
)
-- exclude Regimen details where it is a valid EviQ protocol
--WHERE ( TreatmentEvents.Regimen = '1570' or drugs.regimen_cycle_number is NULL or not TreatmentEvents.Regimen LIKE '[0-9][0-9]%' ) -- quick hack, need deeper access to the database to support regular expressions

order by 	TreatmentEvents.PCP_GROUP_ID, Demographics.SS_Number

/*
declare @startdate date, @enddate date
set @startdate = '2017-05-01'		-- start of month
set @enddate = '2017-05-31'			-- end of month
 */
 

 -- delete test patients
 delete #omis
 where GivenName1 in  ('AAA', 'Installer', 'TOBEDELETED', 'ZCH', 'ZGr', 'ZLB', 'ZPB', 'ZTH','ZZ', 'ZZZ') 
	or Surname in  ('AAA', 'Installer', 'TOBEDELETED', 'ZCH', 'ZGr', 'ZLB', 'ZPB', 'ZTH','ZZ', 'ZZZ') 


if object_id('tempdb..#consultation') is not null
 drop table #consultation
if object_id('tempdb..#diagnosedate') is not null
 drop table #diagnosedate
if object_id('tempdb..#episodedates') is not null
 drop table #episodedates
if object_id('tempdb..#episodedates2') is not null
 drop table #episodedates2
 

update #omis
set HistopathologicalGradeID = null
where CancerSiteCodeID like 'c%'
and isnumeric(substring(CancerSiteCodeID,2,2))=1
and cast(substring(CancerSiteCodeID,2,2) as int) between 81 and 98


 
update #omis
set EpisodeEndDate = null, AntiNeoplasticCycles = null
where EpisodeEndDate > getdate() or EpisodeEndDate = '' or EpisodeEndDate is null


-- upgrade cancer site version to +1 when site code is C50x
update #omis
set CancerSiteCodeIDVersion =  'ICD10V3'
where CancerSiteCodeID = 'C50'
	and  CancerSiteCodeIDVersion =  'ICD10V2'
	
update #omis
set CancerSiteCodeID  =  substring(CancerSiteCodeID,1,charindex(' ', CancerSiteCodeID,3)-1)
where  CancerSiteCodeIDVersion =  'ICDO3'
	and CancerSiteCodeID like '% %'
	
update #omis
set CancerSiteCodeID  =  cast(replace(CancerSiteCodeID,'.','') as varchar(4))
where  CancerSiteCodeIDVersion =  'ICDO3'
	 
update #omis
set CancerSiteCodeID  =  substring(CancerSiteCodeID,1,charindex(' ', CancerSiteCodeID,3)-1)
where  CancerSiteCodeIDVersion <>  'ICDO3'
	and CancerSiteCodeID like '% %'
	
update #omis
set CancerSiteCodeID  =  cast(replace(CancerSiteCodeID,'.','') as varchar(7))
where  CancerSiteCodeIDVersion =  'ICDO3'
 
update #omis
set InitialTreatmentFlag = 2

update a
set InitialTreatmentFlag = 1
from #omis a
	join (select  Pat_ID1,PCP_Group_ID, eff_dttm from patcplan with (nolock) where This_Instance = 1  and CPL_ID is not null and course = 1) b
	on a.Pat_ID1 = b.Pat_ID1 and a.GroupID = b.PCP_Group_ID and b.eff_dttm >=  a.DateOfDiagnosis and b.eff_dttm <= dateadd(m, 4, a.DateOfDiagnosis)

update a
set  InitialTreatmentFlag = 1
from #omis a
join (select a.pat_id1,  a.PCP_Group_ID
	from patcplan a with (nolock)
	join (select pat_id1, min(eff_dttm) as eff_dttm from patcplan with (nolock) where This_Instance = 1 and eff_dttm is not null and CPL_ID is not null group by pat_id1) b
		on a.Pat_ID1  = b.Pat_ID1 and a.Eff_DtTm = b.eff_dttm ) b on a.Pat_ID1  = b.Pat_ID1 and a.GroupID = b.PCP_Group_ID 
where a.DateOfDiagnosis is null


-- diagnose date
select a.PAT_ID1, a.MED_ID, a.Dx_DtTm
into #diagnosedate
from (select m.PAT_ID1, m.MED_ID, case when m.Diagnosis_Class in (5,2) THEN p.Dx_partial_DtTm  ELSE m.Dx_partial_DtTm  END AS Dx_DtTm
	from  Medical m with (nolock)
		join Medical p with (nolock) ON p.MED_ID = m.Related_MED_ID and p.Related_MED_ID  is null and p.Diagnosis_Class = 1) a
	join patient pt on pt.Pat_ID1 = a.PAT_ID1 and a.Dx_DtTm >= pt.Birth_DtTm





update #omis 
set ConsultationDate = null
--where  ConsultationDate  <  coalesce(ReferralDate, DateOfDiagnosis,DateOfBirth) or ConsultationDate > NotificationEpisodeChemoStartDate

-- consult date > (referral date, dx date)
SELECT s.Pat_ID1, e.groupID,  max(s.App_DtTm)  AS Act_DtTm1 
into #consultation
FROM Schedule  s with (nolock)
	join (select pat_id1, groupID, min(EpisodeStartDate) as dx_dttm,  isnull(min(NotificationEpisodeChemoStartDate),getdate()) as NotificationEpisodeChemoStartDate from #omis group by pat_id1, groupid) e on e.Pat_ID1 = s.Pat_ID1 and cast(s.App_DtTm as date) >= dateadd(yy,-1,e.dx_dttm) and cast(s.App_DtTm as date) <= e.dx_dttm
	join dbo.Schedule_ScheduleStatus_MTM ssm with (nolock) on s.Sch_ID = ssm.Sch_ID 
	join dbo.ScheduleStatus ss with (nolock) on ssm.ScheduleStatusID = ss.ScheduleStatusID and ss.SystemDefined = 1  and ss.ScheduleStatusID = 9 -- = charge
WHERE s.Suppressed =0 
	and s.version = 0
	and s.Activity IN (select hsp_code from cpt where CGroup in ('con' )) 
	and s.Inst_ID in (select inst_id from config where Inst_Name like '%medonc%')
group by s.Pat_ID1, e.groupID
   
update a
set a.ConsultationDate = b.Act_DtTm1
from #omis a 
	join #consultation b on a.Pat_ID1 = b.Pat_ID1 and a.GroupID = b.GroupID 
--where a.EpisodeStartDate < a.ConsultationDate 

 
 
update #omis
set ReferralDate = null
--where ReferralDate < coalesce(DateOfDiagnosis,DateOfBirth) 

-- referral date >= diagnose date and <= consult date
update a
set a.ReferralDate = b.Eff_DtTm1
from #omis a 
	join (SELECT o.Pat_ID1, c.GroupID, max(o.Encounter_DtTm) as Eff_DtTm1  
		FROM Object o with (nolock)
			join (select pat_id1, groupid,   min(EpisodeStartDate) as dx_dttm, min(ConsultationDate) as ConsultationDate  from #omis group by pat_id1, groupid) c on o.Pat_ID1 = c.Pat_ID1 and cast(o.Encounter_DtTm as date) <= c.ConsultationDate and cast(o.Encounter_DtTm as date) >= dateadd(yy,-1, c.dx_dttm)
		WHERE o.Status_Enum IN (3,5,7,8,9)  
			AND o.Version = 0 
			--and o.doctype = 18  -- internal referrals
			AND o.DocType IN (Select Prompt.Enum FROM Prompt with (nolock) WHERE Prompt.Text IN ('Referral Int. NCCI','Internal Referral','Referral Letter Recv'))
			--and (o.review_id in (select staff_id from staff where type in ('Inactive','Haematolgist','Haematologist','Med Onc Reg','MedOnc','Haem Reg'))
			--or o.Cosig_ID in (select staff_id from staff where type in ('Inactive','Haematolgist','Haematologist','Med Onc Reg','MedOnc','Haem Reg')))
			and o.Inst_ID in (select inst_id from config with (nolock) where Inst_Name like '%medonc%')
		group by o.Pat_ID1, c.GroupID) b on a.Pat_ID1 = b.Pat_ID1 and a.GroupID = b.GroupID

		 
update #omis 
set ClinicalTrialDate = null
where  ClinicalTrialDate  < coalesce(DateOfDiagnosis,DateOfBirth)  


-- ClinicalTrialDate > diagnose date
update a 
set a.ClinicalTrialDate = b.DtTm_Reg, a.ClinicalTrialName = case when b.Trial_Short_Desc = '' then  b.trial_id else b.Trial_Short_Desc end
from #omis a
	join (SELECT p.Pat_ID1, d.groupid, Trial1.Trial_Short_Desc, Trial1.TRL_ID, Trial1.trial_id,  p.DtTm_Reg, ROW_NUMBER() over (partition by p.Pat_ID1, d.groupid order by p.DtTm_Reg asc) as rownum
		FROM  PatTrial p with (nolock)
			join Trial  AS Trial1 with (nolock) on p.TRL_ID = Trial1.TRL_ID 
		--	join (select pat_id1, min(dx_dttm) as dx_dttm from #diagnosedate group by pat_id1) d on d.PAT_ID1 = p.Pat_ID1 and p.DtTm_Reg >= d.dx_dttm
			join (select pat_id1, groupid, max(coalesce(ReferralDate, DateOfDiagnosis,ConsultationDate)) as dx_dttm from #omis group by pat_id1, groupid) d on d.PAT_ID1 = p.Pat_ID1 and cast(p.DtTm_Reg as date)>= d.dx_dttm
		where  p.Version = 0 
		and trial1.trial_id not like '%scr%'
		and trial1.Trial_Short_Desc is not null
		and trial1.Trial_Short_Desc <> ''
		--group by p.Pat_ID1, d.groupid, Trial1.Trial_Short_Desc, Trial1.TRL_ID
		) b on a.Pat_ID1 = b.Pat_ID1 and b.GroupID = a.GroupID and b.rownum = 1
where b.Trial_Short_Desc is not null

update #omis 
set ReferalToPalliativeCareDate = null
where  ReferalToPalliativeCareDate  < coalesce(DateOfDiagnosis,DateOfBirth)  

-- ReferalToPalliativeCareDate
update a 
set a.ReferalToPalliativeCareDate = b.Encounter_DtTm
from #omis a
	join (select s.pat_id1, min(s.App_DtTm) as Encounter_DtTm 
		from schedule s	 with (nolock)
			join dbo.Schedule_ScheduleStatus_MTM ssm with (nolock) on s.Sch_ID = ssm.Sch_ID 
			join dbo.ScheduleStatus ss with (nolock) on ssm.ScheduleStatusID = ss.ScheduleStatusID and ss.SystemDefined = 1  and ss.ScheduleStatusID = 9 -- = charge
		--	join (select pat_id1, min(dx_dttm) as dx_dttm from #diagnosedate group by pat_id1) d on d.PAT_ID1 = s.Pat_ID1 and s.App_DtTm >= d.dx_dttm
			join (select pat_id1, min(dx_dttm) as dx_dttm from #diagnosedate group by pat_id1) d on d.PAT_ID1 = s.Pat_ID1 and cast(s.App_DtTm as date) >= d.dx_dttm
		where s.Suppressed =0 
			and s.version = 0
			and s.Activity in (select hsp_code from cpt with (nolock) where Description like '%pal%new%') 
		group by s.pat_id1) b on   a.Pat_ID1 = b.Pat_ID1
		
		 
	
update #omis 
set MDTDate = null
where  MDTDate  < coalesce(DateOfDiagnosis,DateOfBirth) 

-- MDTDate
update a 
set a.MDTDate = b.Act_DtTm1
from #omis a
	join (select Pat_ID1, groupid, max(Act_DtTm1) AS Act_DtTm1 
		  from (SELECT s.Pat_ID1, d.groupid, s.App_DtTm  AS Act_DtTm1 
			FROM Schedule s with (nolock)
				join dbo.Schedule_ScheduleStatus_MTM ssm with (nolock) on s.Sch_ID = ssm.Sch_ID 
				join dbo.ScheduleStatus ss with (nolock) on ssm.ScheduleStatusID = ss.ScheduleStatusID and ss.SystemDefined = 1  and ss.ScheduleStatusID <> 8 -- not cancel
			--		join (select pat_id1, min(dx_dttm) as dx_dttm from #diagnosedate group by pat_id1) d on d.PAT_ID1 = s.Pat_ID1 and s.App_DtTm >= d.dx_dttm
					join (select pat_id1, groupid, min(DateOfDiagnosis) as dx_dttm, isnull(min(EpisodeStartDate),getdate()) as EpisodeStartDate from #omis group by pat_id1, groupid) d on d.PAT_ID1 = s.Pat_ID1 and cast(s.App_DtTm as date)>= dateadd(dd,-30,d.dx_dttm) and cast(s.App_DtTm as date) <= EpisodeStartDate
			WHERE s.Suppressed =0 
				and s.version = 0
				and s.Activity IN (select hsp_code from cpt with (nolock) where Description like '%mdt%') 
			union all
			select s.Pat_ID1, d.groupid, s.Due_DtTm  AS Act_DtTm1 
				from Chklist s with (nolock)
					join (select pat_id1, groupid, min(DateOfDiagnosis) as dx_dttm, isnull(min(EpisodeStartDate),getdate()) as EpisodeStartDate from #omis group by pat_id1, groupid) d on d.PAT_ID1 = s.Pat_ID1 and cast(s.Due_DtTm as date)>= dateadd(dd,-30,d.dx_dttm) and cast(s.Due_DtTm as date) <= EpisodeStartDate 
					--join (select pat_id1, max(coalesce(ReferralDate, DateOfDiagnosis,ConsultationDate)) as dx_dttm, isnull(min(NotificationEpisodeChemoEndDate),getdate()) as NotificationEpisodeChemoEndDate from #omis group by pat_id1) d on d.PAT_ID1 = s.Pat_ID1 and s.Edit_DtTm >= d.dx_dttm and s.Edit_DtTm <= NotificationEpisodeChemoEndDate
				where tsk_id in (select tsk_id from QCLTask with (nolock) where Description like '%mdt%' ) 
			)a 
			group by Pat_ID1, groupid) b on   a.Pat_ID1 = b.Pat_ID1 and a.GroupID = b.GroupID
					
		 
update #omis
set PerformanceStatusDate = null, PerformanceStatus = null
--where PerformanceStatusDate < dateadd(yy, -1, EpisodeStartDate)

update l
set l.PerformanceStatusDate = b.Obs_DtTm
	,l.PerformanceStatus = b.ChoiceValue
from #omis l
	join ( SELECT observation_request.OBR_ID
				, observation_request.Pat_ID1
				,l.groupid
				, observation_definition.OBD_ID
				, observation_request.Obs_DtTm
				, observation_definition.Label
				, observation_definition2nd.Label AS ChoiceValue
				--, MAX(observation_definition2nd.ChoiceLabel) OVER (PARTITION BY observation_request.Pat_ID1,observation_definition.Label) AS RowNum
				, ROW_NUMBER() OVER (PARTITION BY observation_request.Pat_ID1,l.groupid ORDER BY observation_request.Obs_DtTm DESC) AS RowNum
			FROM  Observe AS Observe1 with (nolock)
				INNER JOIN ObsDef AS observation_definition with (nolock) ON Observe1.OBD_ID = observation_definition.OBD_ID and observation_definition.Label like '%ECOG%'
				INNER JOIN ObsDef AS observation_definition2nd with (nolock) ON Observe1.Obs_Choice = observation_definition2nd.OBD_ID
				INNER JOIN ObsReq AS observation_request with (nolock) ON observation_request.Pat_ID1 = Observe1.Pat_ID1 AND observation_request.OBR_ID = Observe1.OBR_SET_ID and observation_request.Version = 0 AND observation_request.Status_Enum NOT IN (1)
				join (select pat_id1, groupid, min(EpisodeStartDate) as EpisodeStartDate, case when min(isnull(DateOfDiagnosis,'1900-01-01')) > min(dateadd(yy, -1, EpisodeStartDate)) then min(DateOfDiagnosis) else dateadd(yy, -1, min(EpisodeStartDate)) end as minstartdate from #omis group by pat_id1, groupid) l on l.Pat_ID1 = observation_request.Pat_ID1 and cast(observation_request.Obs_DtTm as date) between l.minstartdate and l.EpisodeStartDate
		) b on l.Pat_ID1 = b.Pat_ID1 and b.GroupID = l.GroupID and b.RowNum = 1


-- episode start/end dates 			 
SELECT distinct PatCPlan.PCP_GROUP_ID
	, PatCPlan.PCP_ID
	, PatCPlan.Pat_ID1
	, PatCPlan.End_DtTm
	, PatCPlan.This_Instance
	, PatCPlan.Discontinue_DtTm
	, pharmacy_administration.Adm_DtTm  as Start_dttm
into #episodedates
FROM  dbo.PatCPlan with (nolock)
	INNER JOIN dbo.CPlan with (nolock) ON PatCPlan.CPL_ID = CPlan.CPL_ID 
	INNER JOIN dbo.Orders AS pharm_orders with (nolock) ON PatCPlan.Pat_ID1 = pharm_orders.Pat_ID1 and  pharm_orders.Cycle_Number IS NOT NULL
		AND pharm_orders.Cycle_Day IS NOT NULL 
		AND pharm_orders.PCI_ID IS NOT NULL  
		AND pharm_orders.Version = 0 
		AND pharm_orders.Status_Enum NOT IN (1)
	INNER JOIN dbo.PharmAdm AS pharmacy_administration with (nolock) ON PatCPlan.Pat_ID1 = pharmacy_administration.Pat_ID1 AND pharm_orders.ORC_SET_ID = pharmacy_administration.ORC_SET_ID
		and  pharmacy_administration.Version = 0 
		AND pharmacy_administration.Adm_DtTm IS NOT NULL 
		AND pharmacy_administration.Status_Enum NOT IN (1)
where pharmacy_administration.Adm_DtTm + CPlan.Cycle_Length between @startdate and dateadd(d,1,@enddate)
	or pharmacy_administration.Adm_DtTm between @startdate and dateadd(d,1,@enddate)
	 
select e.PCP_GROUP_ID, e.Pat_ID1, min(coalesce(e.Discontinue_DtTm, e.End_DtTm)) as End_DtTm, min(e.Start_dttm) as Start_dttm
into #episodedates2
from #episodedates e
	join #omis o on o.GroupID = e.PCP_Group_ID and o.Pat_ID1 = e.Pat_ID1 
		and e.Start_dttm >= coalesce(o.ConsultationDate, o.dateofdiagnosis) and coalesce(e.Discontinue_DtTm, e.End_DtTm) <= e.Start_dttm
where e.Start_dttm between @startdate and @enddate
group by e.PCP_GROUP_ID, e.Pat_ID1 
 
delete #episodedates2
where End_DtTm < Start_dttm

update a
set a.EpisodeStartDate = e.Start_dttm, a.EpisodeEndDate = e.End_DtTm
from #omis a
	join #episodedates2 e on a.GroupID = e.PCP_Group_ID and a.Pat_ID1 = e.Pat_ID1
where a.EpisodeStartDate <= coalesce(a.ConsultationDate, ReferralDate, dateofdiagnosis)

update a
set a.EpisodeStartDate = e.Start_dttm, a.EpisodeEndDate = e.End_DtTm
from #omis a
	join #episodedates2 e on a.GroupID = e.PCP_Group_ID and a.Pat_ID1 = e.Pat_ID1
where a.EpisodeStartDate < a.EpisodeEndDate
 
 
 

update #omis 
set TStageID = ''
where TStageID in ('SCAP', 'BRAIN','ELD','eld b','ELD P','id','IIB','M2','Med','metas','Mid','ox','Plt?','Plt<','su',
	'OUR B','pN0(mol-)','pN0(mol+)','pN1mi','WHOLE','88','-','3 FI','Chronic','e','e3 fi','Plt>','SD',
	'e4 fi','EI','ep','ePOP','ePOST','Int','LAden-','LAden?','LAden+','N,TUM','NB','NEI','31','2-Mar','unk',
	'b2','Blast','BRAI','ELVIS','Ext','hylac','iativ','Int','LCyt-','LCyt?','LCyt+','Ltd','nitiv','o','ULA','NA','N/A','x','NOS')
	
update #omis 
set NStageID = ''
where TStageID in ('SCAP', 'BRAIN','ELD','eld b','ELD P','id','IIB','M2','Med','metas','Mid','ox','Plt?','Plt<','su',
	'OUR B','pN0(mol-)','pN0(mol+)','pN1mi','WHOLE','88','-','3 FI','Chronic','e','e3 fi','Plt>','SD',
	'e4 fi','EI','ep','ePOP','ePOST','Int','LAden-','LAden?','LAden+','N,TUM','NB','NEI','31','2-Mar','unk',
	'b2','Blast','BRAI','ELVIS','Ext','hylac','iativ','Int','LCyt-','LCyt?','LCyt+','Ltd','nitiv','o','ULA','NA','N/A','x','NOS')
	
update #omis 
set MStageID = ''
where MStageID in ('SCAP', 'BRAIN','ELD','eld b','ELD P','id','IIB','M2','Med','metas','Mid','ox','Plt?','Plt<','su',
	'OUR B','pN0(mol-)','pN0(mol+)','pN1mi','WHOLE','88','-','3 FI','Chronic','e','e3 fi','Plt>','SD',
	'e4 fi','EI','ep','ePOP','ePOST','Int','LAden-','LAden?','LAden+','N,TUM','NB','NEI','31','2-Mar','unk',
	'b2','Blast','BRAI','ELVIS','Ext','hylac','iativ','Int','LCyt-','LCyt?','LCyt+','Ltd','nitiv','o','ULA','NA','N/A','x','NOS')

update #omis 
set TStageID = substring(TStageID,1,charindex('T',TStageID,1)-1)+substring(TStageID,charindex('T',TStageID,1)+1,10) 
where TStageID like '%T%'
 
update #omis 
set NStageID = substring(NStageID,1,charindex('N',NStageID,1)-1)+substring(NStageID,charindex('N',NStageID,1)+1,10) 
where NStageID like '%N%'
 
update #omis 
set MStageID = substring(MStageID,1,charindex('M',MStageID,1)-1)+substring(MStageID,charindex('M',MStageID,1)+1,10) 
where MStageID like '%M%'



update #omis 
set TStageID = replace(replace(TStageID , 'NOS',''), ' (DCIS)','')
where TStageID  like '%NOS%' or TStageID   like '%dcis%'
 
update #omis 
set NStageID = replace(replace(NStageID , 'NOS',''), ' (DCIS)','')
where NStageID   like '%NOS%' or NStageID   like '%dcis%'
 
update #omis 
set MStageID = replace(replace(MStageID, 'NOS',''), ' (DCIS)','')
where MStageID   like '%NOS%' or MStageID  like '%dcis%'

update #omis 
set MStageID = ''
where MStageID in ('SCAP', 'BRAIN','ELD','eld b','ELD P','id','IIB','M2','Med','metas','Mid','ox','Plt?','Plt<','su',
	'OUR B','pN0(mol-)','pN0(mol+)','pN1mi','WHOLE','88','-','3 FI','Chronic','e','e3 fi','Plt>','SD',
	'e4 fi','EI','ep','ePOP','ePOST','Int','LAden-','LAden?','LAden+','N,TUM','NB','NEI','31','2-Mar','unk',
	'b2','Blast','BRAI','ELVIS','Ext','hylac','iativ','Int','LCyt-','LCyt?','LCyt+','Ltd','nitiv','o','ULA','NA','N/A','x','NOS')


-- select ReferralDate, ConsultationDate, EpisodeStartDate, * from #omis where ReferralDate > ConsultationDate

-- select datediff(d, DateOfDiagnosis, MDTDate), DateOfDiagnosis, MDTDate,   * from #omis order by datediff(d, DateOfDiagnosis, MDTDate) desc
  
	/*
declare @startdate date, @enddate date

set @startdate = '2017-05-01'		-- start of month
set @enddate = '2017-05-31'			-- end of month
 */

 
--if object_id('tempdb..@eviq') is not null 
--  drop table @eviq
--if object_id('tempdb..@eviq2') is not null 
--  drop table @eviq2
  
declare @eviq table (cplanname varchar(300), regimen varchar(300), map_protocol varchar(40)) -- BRAD NOTE - I have doubled the size of the allowed variables fr all table components
declare @eviq2 table (cplanname varchar(300), regimen varchar(300), map_protocol varchar(40)) -- BRAD NOTE - I have doubled the size of the allowed variables fr all table components
 
insert into @eviq2
select distinct cplan_name as cplanname, regimen, cast('0' as  varchar(20)) as map_protocol from cplan
    
insert into @eviq
select cplanname, regimen, cast(regimen as varchar(20)) as regimen from @eviq2 where isnumeric(regimen) = 1 
union all
select cplanname, regimen, substring(regimen,1,charindex('v',regimen)-1) from @eviq2 where cplanname like '%eviq%' and isnumeric(regimen) < 1 and  regimen  LIKE '[<+0-9]%v[0-9]'
union all
select cplanname, regimen
	 , case when charindex(' ',ltrim(replace(replace(replace(replace(substring(cplanname,charindex('evi',cplanname),18),'eviq',''),'.',''),'#',''),'*',''))) > 0
		then cast(substring(ltrim(replace(replace(replace(replace(substring(cplanname,charindex('evi',cplanname),18),'eviq',''),'.',''),'#',''),'*','')),1,charindex(' ',ltrim(replace(replace(replace(replace(substring(cplanname,charindex('evi',cplanname),18),'eviq',''),'.',''),'#',''),'*','')))) as varchar(20))
		else cast(ltrim(replace(replace(replace(replace(substring(cplanname,charindex('evi',cplanname),18),'eviq',''),'.',''),'#',''),'*','')) as varchar(20))
		end  
	 from @eviq2 where cplanname like '%eviq%' and isnumeric(regimen) < 1 and regimen not LIKE '[<+0-9]%v[0-9]' and cplanname not like '%eviq id%'
union all
select cplanname , regimen
	, case when charindex(' ',ltrim(replace(replace(replace(replace(replace(replace(substring(cplanname,charindex('evi',cplanname),18),'eviq id',''),'.',''),'#',''),'*',''),'/',' '),':',' '))) > 0
		then cast(substring(ltrim(replace(replace(replace(replace(replace(replace(substring(cplanname,charindex('evi',cplanname),18),'eviq id',''),'.',''),'#',''),'*',''),'/',' '),':',' ')),1,charindex(' ',ltrim(replace(replace(replace(replace(replace(replace(substring(cplanname,charindex('evi',cplanname),18),'eviq id',''),'.',''),'#',''),'*',''),'/',' '),':',' ')))) as  varchar(20))
		else cast(ltrim(replace(replace(replace(replace(replace(replace(substring(cplanname,charindex('evi',cplanname),18),'eviq id',''),'.',''),'#',''),'*',''),'/',' '),':',' ')) as  varchar(20))
		end  
	  from @eviq2 where cplanname like '%eviq%' and isnumeric(regimen) < 1 and regimen not LIKE '[<+0-9]%v[0-9]' and cplanname like '%eviq id%'
union all
select cplanname, regimen, '1570' from @eviq2 where isnumeric(regimen) < 1 and   cplanname not like '%eviq%'and  cplanname not like '% trial%' 
union all
select cplanname, regimen, '1571' from @eviq2 where isnumeric(regimen) < 1 and   cplanname not like '%eviq%' and  cplanname like '% trial%' 

update @eviq
set map_protocol = replace(replace(map_protocol,'_',''),'ak','')
where isnumeric(map_protocol) < 1

update @eviq
set map_protocol = substring(map_protocol,1,charindex(map_protocol,'v')-1)
where isnumeric(map_protocol) < 1 and charindex(map_protocol,'v') > 1
  
update @eviq
set map_protocol = '1570'
where isnumeric(map_protocol) < 1
   


if object_id('tempdb..#omis_final') is not null
 drop table #omis_final

select distinct	GroupID
	,	MedicareNumber
	,	MRN
	,	[UniqueIdentifier]
	,	GivenName1
	,	GivenName2
	,	Surname
	,	AliasSurname 
	,	Sex
	,	DateOfBirth
	,	Birth_Place_original
	,	COBCodeSACC
	,	WayfareAddress
	,	Locality
	,	Postcode
	,	WayfareStateID_original
	,	WayfareStateID
	,	IndigenousStatusID_original
	,	IndigenousStatusID
	,	AmoRegReferringNumber
	,	DoctorName
	,	TreatingFacilityCode
	,	FacilityCode
	,	DateOfDiagnosis
	,	CancerSiteCodeID
	,	CancerSiteCodeIDVersion
	,   MorphologyCodeIDVersion
	,	BestBasisOfDiagnosisID_original
	,	BestBasisOfDiagnosisID
	,	Laterality_original
	,	Laterality
	,	HistopathologicalGradeID
	,	MorphologyCodeID
	,	DegreeOfSpreadID
	,	TNMStagingDate
	,	TStageID_original
	,	NStageID_original
	,	MStageID_original
	,	TStageID
	,	NStageID
	,	MStageID
	,	TNMStagingGroupID
	,	TNMStagingBasisID
	,	OtherStagingDate
	,	OtherStagingSchemeID
	,	OtherStagingGroupID
	,	OtherStagingBasisID
	,	EpisodeIntentID_original
	,	EpisodeIntentID
	,	InitialTreatmentFlag
	,	EpisodeStartDate
	,	EpisodeEndDate
	,	AntiNeoplasticCycles
	--,	'1570' as ProtocolID
	,	e.map_protocol  as ProtocolID
	,	NotificationEpisodeChemoCycle
	,	OMISDrugName
	,	NotificationEpisodeChemoDose
	,	NotificationEpisodeChemoRouteID_original
	,	NotificationEpisodeChemoRouteID
	,	NotificationEpisodeChemoStartDate
	,	NotificationEpisodeChemoEndDate
	,	NotificationEpisodeChemoFrequency
	,	NotificationEpisodeChemoFrequencyUnit
	,	NotificationEpisodeChemoDay
	,	ReferralDate
	,	ConsultationDate
	,	ClinicalTrialDate
	,	ClinicalTrialName
	,	MDTDate
	,	ReferalToPalliativeCareDate
	,	PerformanceStatusDate
	,	PerformanceStatus
	,	CPL_ID
	,	o.CPlan_Name
	,	o.Regimen
into #omis_final
from #omis o
	join @eviq e on o.CPlan_Name = e.CPlanName and o.Regimen = e.regimen
where e.map_protocol in (1570,1571)
	and rtrim(Surname) not in ('AAA', 'ZZ', 'ZGr','ZCH','ZPB','ZLB','ZTH','Installer','TOBEDELETED')
--where (ProtocolID = '1570' or   isnumeric(ProtocolID) = 0) and   ProtocolID not like 'ID%'   --and ProtocolID <> '1570' 
	--and TreatingFacilityCode = @hosp_code
union all
select distinct	GroupID
	,	MedicareNumber
	,	MRN
	,	[UniqueIdentifier]
	,	GivenName1
	,	GivenName2
	,	Surname
	,	AliasSurname 
	,	Sex
	,	DateOfBirth
	,	Birth_Place_original
	,	COBCodeSACC
	,	WayfareAddress
	,	Locality
	,	Postcode
	,	WayfareStateID_original
	,	WayfareStateID
	,	IndigenousStatusID_original
	,	IndigenousStatusID
	,	AmoRegReferringNumber
	,	DoctorName
	,	TreatingFacilityCode
	,	FacilityCode
	,	DateOfDiagnosis
	,	CancerSiteCodeID
	,	CancerSiteCodeIDVersion
	,   MorphologyCodeIDVersion
	,	BestBasisOfDiagnosisID_original
	,	BestBasisOfDiagnosisID
	,	Laterality_original
	,	Laterality
	,	HistopathologicalGradeID
	,	MorphologyCodeID
	,	DegreeOfSpreadID
	,	TNMStagingDate
	,	TStageID_original
	,	NStageID_original
	,	MStageID_original
	,	TStageID
	,	NStageID
	,	MStageID
	,	TNMStagingGroupID
	,	TNMStagingBasisID
	,	OtherStagingDate
	,	OtherStagingSchemeID
	,	OtherStagingGroupID
	,	OtherStagingBasisID
	,	EpisodeIntentID_original
	,	EpisodeIntentID
	,	InitialTreatmentFlag
	,	EpisodeStartDate
	,	EpisodeEndDate
	,	AntiNeoplasticCycles
	--,	substring(ProtocolID,1,6) as ProtocolID
	,	e.map_protocol  as ProtocolID
	,	null as NotificationEpisodeChemoCycle
	,	null as OMISDrugName
	,	null as NotificationEpisodeChemoDose
	,	null as NotificationEpisodeChemoRouteID_original
	,	null as NotificationEpisodeChemoRouteID
	,	null as NotificationEpisodeChemoStartDate
	,	null as NotificationEpisodeChemoEndDate
	,	null as NotificationEpisodeChemoFrequency
	,	null as NotificationEpisodeChemoFrequencyUnit
	,	null as NotificationEpisodeChemoDay
	,	ReferralDate
	,	ConsultationDate
	,	ClinicalTrialDate
	,	ClinicalTrialName
	,	MDTDate
	,	ReferalToPalliativeCareDate
	,	PerformanceStatusDate
	,	PerformanceStatus
	,	o.CPL_ID
	,	o.CPlan_Name
	,	o.Regimen
from #omis o
	join @eviq e on o.CPlan_Name = e.CPlanName and o.Regimen = e.regimen
where e.map_protocol not in (1570,1571)
	and rtrim(Surname) not in ('AAA', 'ZZ', 'ZGr','ZCH','ZPB','ZLB','ZTH','Installer','TOBEDELETED')
--where  ProtocolID <> '1570' and  ProtocolID like 'ID%'   
	--and TreatingFacilityCode = @hosp_code
 

-- select * from #omis_final


/****************************************************************************************************************************************************************************************/
 
/* 
declare @startdate date, @enddate date, @debug char(1), @hospital varchar(20)
set @startdate = '2017-01-01'		-- start of month
set @enddate = '2017-01-31'			-- end of month
set  @hosp_code = 'H208'
set @debug = 'Y'					-- Y = show real dates, N = DDMMYYYY
*/

if object_id('tempdb..#omis_debug') is not null
 drop table #omis_debug
 
if @debug = 'Y' 
begin

select GroupID
	,	case when len(GroupID) > 11 then d_GroupID+' |value > 11 characters' else d_GroupID end as d_GroupID
	,	MedicareNumber
	,	case when len(MedicareNumber) > 12 then d_MedicareNumber+' |value > 12 characters' else d_MedicareNumber end as d_MedicareNumber
	,	MRN
	,	case when len(MRN) > 20 then d_MRN+' |value > 20 characters' else d_MRN end as d_MRN
	,	UniqueIdentifier
	,	case when len(UniqueIdentifier) > 20 then d_UniqueIdentifier+' |value > 20 characters' else d_UniqueIdentifier end as d_UniqueIdentifier
	,	GivenName1
	,	case when len(GivenName1) > 40 then d_GivenName1+' |value > 40 characters' else d_GivenName1 end as d_GivenName1
	,	GivenName2
	,	case when len(GivenName2) > 40 then d_GivenName2+' |value > 40 characters' else d_GivenName2 end as d_GivenName2
	,	Surname
	,	case when len(Surname) > 40 then d_Surname+' |value > 40 characters' else d_Surname end as d_Surname
	,	AliasSurname
	,	case when len(AliasSurname) > 40 then d_AliasSurname+' |value > 40 characters' else d_AliasSurname end as d_AliasSurname
	,	Sex
	,	case when len(Sex) > 1 then d_Sex+' |value > 1 characters' else d_Sex end as d_Sex
	,	DateOfBirth
	,	case when isdate(DateOfBirth) > 0 and DateOfBirth >= dateadd(dd,-1,getdate()) then d_DateOfBirth+' |value > today' else d_DateOfBirth  end as d_DateOfBirth
	,	Birth_Place_original
	,	d_Birth_Place_original
	,	COBCodeSACC
	,	case when len(COBCodeSACC) > 4 then d_COBCodeSACC+' |value > 4 characters' else d_COBCodeSACC end as d_COBCodeSACC
	,	WayfareAddress
	,	case when len(WayfareAddress) > 180 then d_WayfareAddress+' |value > 180 characters' else d_WayfareAddress end as d_WayfareAddress
	,	Locality
	,	case when len(Locality) > 40 then d_Locality+' |value > 40 characters' else d_Locality end as d_Locality
	,	Postcode
	,	case when len(Postcode) > 4 then d_Postcode+' |value > 4 characters' else d_Postcode end as d_Postcode
	,	WayfareStateID_original
	,	d_WayfareStateID_original
	,	WayfareStateID
	,	case when len(WayfareStateID) > 2 then d_WayfareStateID+' |value > 2 characters' else d_WayfareStateID end as d_WayfareStateID
	,	IndigenousStatusID_original
	,	d_IndigenousStatusID_original
	,	IndigenousStatusID
	,	case when len(IndigenousStatusID) > 1 then d_IndigenousStatusID+' |value > 1 characters' else d_IndigenousStatusID end as d_IndigenousStatusID
	,	AmoRegReferringNumber
	,	case when len(AmoRegReferringNumber) > 20 then d_AmoRegReferringNumber+' |value > 20 characters' else d_AmoRegReferringNumber end as d_AmoRegReferringNumber
	,	DoctorName
	,	case when len(DoctorName) > 120 then d_DoctorName+' |value > 120 characters' else d_DoctorName end as d_DoctorName
	,	TreatingFacilityCode
	,	case when len(TreatingFacilityCode) > 4 then d_TreatingFacilityCode+' |value > 4 characters' else d_TreatingFacilityCode end as d_TreatingFacilityCode
	,	FacilityCode
	,	case when len(FacilityCode) > 4 then d_FacilityCode+' |value > 4 characters' else d_FacilityCode end as d_FacilityCode
	,	DateOfDiagnosis
	,	case when isdate(DateOfDiagnosis) > 0 and DateOfDiagnosis >= dateadd(dd,-1,getdate()) then d_DateOfDiagnosis+' |value > today' else d_DateOfDiagnosis  end as d_DateOfDiagnosis
	,	CancerSiteCodeID
	,	case when len(CancerSiteCodeID) > 7 then d_CancerSiteCodeID+' |value > 7 characters' else d_CancerSiteCodeID end as d_CancerSiteCodeID
	,	CancerSiteCodeIDVersion
	,	case when len(CancerSiteCodeIDVersion) > 10 then d_CancerSiteCodeIDVersion+' |value > 10 characters' else d_CancerSiteCodeIDVersion end as d_CancerSiteCodeIDVersion
	,	MorphologyCodeIDVersion
	,	case when len(MorphologyCodeIDVersion) > 10 then d_MorphologyCodeIDVersion+' |value > 10 characters' else d_MorphologyCodeIDVersion end as d_MorphologyCodeIDVersion
	,	BestBasisOfDiagnosisID_original
	,	d_BestBasisOfDiagnosisID_original
	,	BestBasisOfDiagnosisID
	,	case when len(BestBasisOfDiagnosisID) > 1 then d_BestBasisOfDiagnosisID+' |value > 1 characters' else d_BestBasisOfDiagnosisID end as d_BestBasisOfDiagnosisID
	,	Laterality_original
	,	d_Laterality_original
	,	Laterality
	,	case when len(Laterality) > 1 then d_Laterality+' |value > 1 characters' else d_Laterality end as d_Laterality
	,	HistopathologicalGradeID
	,	case when len(HistopathologicalGradeID) > 1 then d_HistopathologicalGradeID+' |value > 1 characters' else d_HistopathologicalGradeID end as d_HistopathologicalGradeID
	,	MorphologyCodeID
	,	case when len(MorphologyCodeID) > 10 then d_MorphologyCodeID+' |value > 10 characters' else d_MorphologyCodeID end as d_MorphologyCodeID
	,	DegreeOfSpreadID
	,	case when len(DegreeOfSpreadID) > 1 then d_DegreeOfSpreadID+' |value > 1 characters' else d_DegreeOfSpreadID end as d_DegreeOfSpreadID
	,	TNMStagingDate
	,	case when isdate(TNMStagingDate) > 0 and TNMStagingDate >= dateadd(dd,-1,getdate()) then d_TNMStagingDate+' |value > today' else d_TNMStagingDate  end as d_TNMStagingDate
	,	TStageID_original
	,	NStageID_original
	,	MStageID_original
	,	TStageID
	,	case when len(TStageID) > 50 then d_TStageID+' |value > 50 characters' else d_TStageID end as d_TStageID
	,	NStageID
	,	case when len(NStageID) > 50 then d_NStageID+' |value > 50 characters' else d_NStageID end as d_NStageID
	,	MStageID
	,	case when len(MStageID) > 50 then d_MStageID+' |value > 50 characters' else d_MStageID end as d_MStageID
	,	TNMStagingGroupID
	,	case when len(TNMStagingGroupID) > 50 then d_TNMStagingGroupID+' |value > 50 characters' else d_TNMStagingGroupID end as d_TNMStagingGroupID
	,	TNMStagingBasisID
	,	case when len(TNMStagingBasisID) > 1 then d_TNMStagingBasisID+' |value > 1 characters' else d_TNMStagingBasisID end as d_TNMStagingBasisID
	,	OtherStagingDate
	,	case when isdate(OtherStagingDate) > 0 and OtherStagingDate >= dateadd(dd,-1,getdate()) then d_OtherStagingDate+' |value > today' else d_OtherStagingDate  end as d_OtherStagingDate
	,	OtherStagingSchemeID
	,	case when len(OtherStagingSchemeID) > 2 then d_OtherStagingSchemeID+' |value > 2 characters' else d_OtherStagingSchemeID end as d_OtherStagingSchemeID
	,	OtherStagingGroupID
	,	case when len(OtherStagingGroupID) > 14 then d_OtherStagingGroupID+' |value > 14 characters' else d_OtherStagingGroupID end as d_OtherStagingGroupID
	,	OtherStagingBasisID
	,	case when len(OtherStagingBasisID) > 1 then d_OtherStagingBasisID+' |value > 1 characters' else d_OtherStagingBasisID end as d_OtherStagingBasisID
	,	EpisodeIntentID_original
	,	d_EpisodeIntentID_original
	,	EpisodeIntentID
	,	case when len(EpisodeIntentID) > 2 then d_EpisodeIntentID+' |value > 2 characters' else d_EpisodeIntentID end as d_EpisodeIntentID
	,	InitialTreatmentFlag
	,	case when len(InitialTreatmentFlag) > 1 then d_InitialTreatmentFlag+' |value > 1 characters' else d_InitialTreatmentFlag end as d_InitialTreatmentFlag
	,	EpisodeStartDate
	,	case when isdate(EpisodeStartDate) > 0 and EpisodeStartDate >= dateadd(dd,-1,getdate()) then d_EpisodeStartDate+' |value > today' else d_EpisodeStartDate  end as d_EpisodeStartDate
	,	EpisodeEndDate
	,	case when isdate(EpisodeEndDate) > 0 and EpisodeEndDate >= dateadd(dd,365,getdate()) then d_EpisodeEndDate+' |value > 1 year' else d_EpisodeEndDate  end as d_EpisodeEndDate
	,	AntiNeoplasticCycles
	,	case when len(AntiNeoplasticCycles) > 3 then d_AntiNeoplasticCycles+' |value > 3 characters' else d_AntiNeoplasticCycles end as d_AntiNeoplasticCycles
	,	ProtocolID
	,	case when len(ProtocolID) > 15 then d_ProtocolID+' |value > 15 characters' else d_ProtocolID end as d_ProtocolID
	,	NotificationEpisodeChemoCycle
	,	case when len(NotificationEpisodeChemoCycle) > 3 then d_NotificationEpisodeChemoCycle+' |value > 3 characters' else d_NotificationEpisodeChemoCycle end as d_NotificationEpisodeChemoCycle
	,	OMISDrugName
	,	case when len(OMISDrugName) > 512 then d_OMISDrugName+' |value > 512 characters' else d_OMISDrugName end as d_OMISDrugName
	,	NotificationEpisodeChemoDose
	,	case when len(NotificationEpisodeChemoDose) > 20 then d_NotificationEpisodeChemoDose+' |value > 20 characters' else d_NotificationEpisodeChemoDose end as d_NotificationEpisodeChemoDose
	,	NotificationEpisodeChemoRouteID_original
	,	d_NotificationEpisodeChemoRouteID_original
	,	NotificationEpisodeChemoRouteID
	,	case when len(NotificationEpisodeChemoRouteID) > 2 then d_NotificationEpisodeChemoRouteID+' |value > 2 characters' else d_NotificationEpisodeChemoRouteID end as d_NotificationEpisodeChemoRouteID
	,	NotificationEpisodeChemoStartDate
	,	case when isdate(NotificationEpisodeChemoStartDate) > 0 and NotificationEpisodeChemoStartDate >= dateadd(dd,-1,getdate()) then d_NotificationEpisodeChemoStartDate+' |value > today' else d_NotificationEpisodeChemoStartDate  end as d_NotificationEpisodeChemoStartDate
	,	NotificationEpisodeChemoEndDate
	,	case when isdate(NotificationEpisodeChemoEndDate) > 0 and NotificationEpisodeChemoEndDate >= dateadd(dd,-1,getdate()) then d_NotificationEpisodeChemoEndDate+' |value > today' else d_NotificationEpisodeChemoEndDate  end as d_NotificationEpisodeChemoEndDate
	,	NotificationEpisodeChemoFrequency
	,	case when len(NotificationEpisodeChemoFrequency) > 2 then d_NotificationEpisodeChemoFrequency+' |value > 2 characters' else d_NotificationEpisodeChemoFrequency end as d_NotificationEpisodeChemoFrequency
	,	NotificationEpisodeChemoFrequencyUnit
	,	case when len(NotificationEpisodeChemoFrequencyUnit) > 1 then d_NotificationEpisodeChemoFrequencyUnit+' |value > 1 characters' else d_NotificationEpisodeChemoFrequencyUnit end as d_NotificationEpisodeChemoFrequencyUnit
	,	NotificationEpisodeChemoDay
	,	case when len(NotificationEpisodeChemoDay) > 15 then d_NotificationEpisodeChemoDay+' |value > 15 characters' else d_NotificationEpisodeChemoDay end as d_NotificationEpisodeChemoDay
	,	ReferralDate
	,	case when isdate(ReferralDate) > 0 and ReferralDate >= dateadd(dd,-1,getdate()) then d_ReferralDate+' |value > today' else d_ReferralDate  end as d_ReferralDate
	,	ConsultationDate
	,	case when isdate(ConsultationDate) > 0 and ConsultationDate >= dateadd(dd,-1,getdate()) then d_ConsultationDate+' |value > today' else d_ConsultationDate  end as d_ConsultationDate
	,	ClinicalTrialDate
	,	case when isdate(ClinicalTrialDate) > 0 and ClinicalTrialDate >= dateadd(dd,-1,getdate()) then d_ClinicalTrialDate+' |value > today' else d_ClinicalTrialDate  end as d_ClinicalTrialDate
	,	ClinicalTrialName
	,	case when len(ClinicalTrialName) > 100 then d_ClinicalTrialName+' |value > 100 characters' else d_ClinicalTrialName end as d_ClinicalTrialName
	,	MDTDate
	,	case when isdate(MDTDate) > 0 and MDTDate >= dateadd(dd,-1,getdate()) then d_MDTDate+' |value > today' else d_MDTDate  end as d_MDTDate
	,	ReferalToPalliativeCareDate
	,	case when isdate(ReferalToPalliativeCareDate) > 0 and ReferalToPalliativeCareDate >= dateadd(dd,-1,getdate()) then d_ReferalToPalliativeCareDate+' |value > today' else d_ReferalToPalliativeCareDate  end as d_ReferalToPalliativeCareDate
	,	PerformanceStatusDate
	,	case when isdate(PerformanceStatusDate) > 0 and PerformanceStatusDate >= dateadd(dd,-1,getdate()) then d_PerformanceStatusDate+' |value > today' else d_PerformanceStatusDate  end as d_PerformanceStatusDate
	,	PerformanceStatus
	,	case when len(PerformanceStatus) > 1 then d_PerformanceStatus+' |value > 1 characters' else d_PerformanceStatus end as d_PerformanceStatus
	,	CPL_ID
	,	CPlan_Name
	,	Regimen
into #omis_debug
from (select	GroupID
		,	case when len(GroupID) > 0 and isnumeric(GroupID)=0 then d_GroupID +' |value not numeric' else d_GroupID end as d_GroupID
		,	MedicareNumber
		,	case when len(MedicareNumber) > 0 and isnumeric(MedicareNumber)< 1 then d_MedicareNumber +' |value not numeric' else d_MedicareNumber end as d_MedicareNumber
		,	MRN
		,	d_MRN
		,	UniqueIdentifier
		,	d_UniqueIdentifier
		,	GivenName1
		,	d_GivenName1
		,	GivenName2
		,	d_GivenName2
		,	Surname
		,	d_Surname
		,	AliasSurname
		,	d_AliasSurname
		,	Sex
		,	case when len(Sex) > 0 and isnumeric(Sex)=0 then d_Sex+' |value not numeric' else d_Sex end as d_Sex
		,	DateOfBirth
		,	case when len(DateOfBirth) > 0 and isdate(DateOfBirth)=0 then d_DateOfBirth+' |value not numeric' else d_DateOfBirth end as d_DateOfBirth
		,	Birth_Place_original
		,	d_Birth_Place_original
		,	COBCodeSACC
		,	case when len(COBCodeSACC) > 0 and isnumeric(COBCodeSACC)=0 then d_COBCodeSACC+' |value not numeric' else d_COBCodeSACC end as d_COBCodeSACC
		,	WayfareAddress
		,	d_WayfareAddress
		,	Locality
		,	d_Locality
		,	Postcode
		,	case when len(Postcode) > 0 and isnumeric(Postcode)=0 then d_Postcode+' |value not numeric' else d_Postcode end as d_Postcode
		,	WayfareStateID_original
		,	d_WayfareStateID_original
		,	WayfareStateID
		,	case when len(WayfareStateID) > 0 and isnumeric(WayfareStateID)=0 then d_WayfareStateID+' |value not numeric' else d_WayfareStateID end as d_WayfareStateID
		,	IndigenousStatusID_original
		,	d_IndigenousStatusID_original
		,	IndigenousStatusID
		,	case when len(IndigenousStatusID) > 0 and isnumeric(IndigenousStatusID)=0 then d_IndigenousStatusID+' |value not numeric' else d_IndigenousStatusID end as d_IndigenousStatusID
		,	AmoRegReferringNumber
		,	d_AmoRegReferringNumber
		,	DoctorName
		,	d_DoctorName
		,	TreatingFacilityCode
		,	d_TreatingFacilityCode
		,	FacilityCode
		,	d_FacilityCode
		,	DateOfDiagnosis
		,	case when len(DateOfDiagnosis) > 0 and isdate(DateOfDiagnosis)=0 then d_DateOfDiagnosis+' |value not a date' else d_DateOfDiagnosis end as d_DateOfDiagnosis
		,	CancerSiteCodeID
		,	d_CancerSiteCodeID
		,	CancerSiteCodeIDVersion
		,	d_CancerSiteCodeIDVersion
		,	MorphologyCodeIDVersion
		,	d_MorphologyCodeIDVersion
		,	BestBasisOfDiagnosisID_original
		,	d_BestBasisOfDiagnosisID_original
		,	BestBasisOfDiagnosisID
		,	case when len(BestBasisOfDiagnosisID) > 0 and isnumeric(BestBasisOfDiagnosisID)=0 then d_BestBasisOfDiagnosisID+' |value not numeric' else d_BestBasisOfDiagnosisID end as d_BestBasisOfDiagnosisID
		,	Laterality_original
		,	d_Laterality_original
		,	Laterality
		,	case when len(Laterality) > 0 and isnumeric(Laterality)=0 then d_Laterality+' |value not numeric' else d_Laterality end as d_Laterality
		,	HistopathologicalGradeID
		,	case when len(HistopathologicalGradeID) > 0 and isnumeric(HistopathologicalGradeID)=0 then d_HistopathologicalGradeID+' |value not numeric' else d_HistopathologicalGradeID end as d_HistopathologicalGradeID
		,	MorphologyCodeID
		,	d_MorphologyCodeID
		,	DegreeOfSpreadID
		,	case when len(DegreeOfSpreadID) > 0 and isnumeric(DegreeOfSpreadID)=0 then d_DegreeOfSpreadID+' |value not numeric' else d_DegreeOfSpreadID end as d_DegreeOfSpreadID
		,	TNMStagingDate
		,	case when len(TNMStagingDate) > 0 and isdate(TNMStagingDate)=0 then d_TNMStagingDate+' |value not a date' else d_TNMStagingDate end as d_TNMStagingDate
		,	TStageID_original
		,	NStageID_original
		,	MStageID_original
		,	TStageID
		,	d_TStageID
		,	NStageID
		,	d_NStageID
		,	MStageID
		,	d_MStageID
		,	TNMStagingGroupID
		,	d_TNMStagingGroupID
		,	TNMStagingBasisID
		,	d_TNMStagingBasisID
		,	OtherStagingDate
		,	d_OtherStagingDate
		,	OtherStagingSchemeID
		,	case when len(OtherStagingSchemeID) > 0 and isnumeric(OtherStagingSchemeID)=0 then d_OtherStagingSchemeID+' |value not numeric' else d_OtherStagingSchemeID end as d_OtherStagingSchemeID
		,	OtherStagingGroupID
		,	d_OtherStagingGroupID
		,	OtherStagingBasisID
		,	d_OtherStagingBasisID
		,	EpisodeIntentID_original
		,	d_EpisodeIntentID_original
		,	EpisodeIntentID
		,	case when len(EpisodeIntentID) > 0 and isnumeric(EpisodeIntentID)=0 then d_EpisodeIntentID+' |value not numeric' else d_EpisodeIntentID end as d_EpisodeIntentID
		,	InitialTreatmentFlag
		,	case when len(InitialTreatmentFlag) > 0 and isnumeric(InitialTreatmentFlag)=0 then d_InitialTreatmentFlag+' |value not numeric' else d_InitialTreatmentFlag end as d_InitialTreatmentFlag
		,	EpisodeStartDate
		,	case when len(EpisodeStartDate) > 0 and isdate(EpisodeStartDate)=0 then d_EpisodeStartDate+' |value not a date' else d_EpisodeStartDate end as d_EpisodeStartDate
		,	EpisodeEndDate
		,	case when len(EpisodeEndDate) > 0 and isdate(EpisodeEndDate)=0 then d_EpisodeEndDate+' |value not a date' else d_EpisodeEndDate end as d_EpisodeEndDate
		,	AntiNeoplasticCycles
		,	case when len(AntiNeoplasticCycles) > 0 and isnumeric(AntiNeoplasticCycles)=0 then d_AntiNeoplasticCycles+' |value not numeric' else d_AntiNeoplasticCycles end as d_AntiNeoplasticCycles
		,	ProtocolID
		,	d_ProtocolID
		,	NotificationEpisodeChemoCycle
		,	case when len(NotificationEpisodeChemoCycle) > 0 and isnumeric(NotificationEpisodeChemoCycle)=0 then d_NotificationEpisodeChemoCycle+' |value not numeric' else d_NotificationEpisodeChemoCycle end as d_NotificationEpisodeChemoCycle
		,	OMISDrugName
		,	d_OMISDrugName
		,	NotificationEpisodeChemoDose
		,	d_NotificationEpisodeChemoDose
		,	NotificationEpisodeChemoRouteID_original
		,	d_NotificationEpisodeChemoRouteID_original
		,	NotificationEpisodeChemoRouteID
		,	case when len(NotificationEpisodeChemoRouteID) > 0 and isnumeric(NotificationEpisodeChemoRouteID)=0 then d_NotificationEpisodeChemoRouteID+' |value not numeric' else d_NotificationEpisodeChemoRouteID end as d_NotificationEpisodeChemoRouteID
		,	NotificationEpisodeChemoStartDate
		,	case when len(NotificationEpisodeChemoStartDate) > 0 and isdate(NotificationEpisodeChemoStartDate)=0 then d_NotificationEpisodeChemoStartDate+' |value not a date' else d_NotificationEpisodeChemoStartDate end as d_NotificationEpisodeChemoStartDate
		,	NotificationEpisodeChemoEndDate
		,	case when len(NotificationEpisodeChemoEndDate) > 0 and isdate(NotificationEpisodeChemoEndDate)=0 then d_NotificationEpisodeChemoEndDate+' |value not a date' else d_NotificationEpisodeChemoEndDate end as d_NotificationEpisodeChemoEndDate
		,	NotificationEpisodeChemoFrequency
		,	case when len(NotificationEpisodeChemoFrequency) > 0 and isnumeric(NotificationEpisodeChemoFrequency)=0 then d_NotificationEpisodeChemoFrequency+' |value not numeric' else d_NotificationEpisodeChemoFrequency end as d_NotificationEpisodeChemoFrequency
		,	NotificationEpisodeChemoFrequencyUnit
		,	case when len(NotificationEpisodeChemoFrequencyUnit) > 0 and isnumeric(NotificationEpisodeChemoFrequencyUnit)=0 then d_NotificationEpisodeChemoFrequencyUnit+' |value not numeric' else d_NotificationEpisodeChemoFrequencyUnit end as d_NotificationEpisodeChemoFrequencyUnit
		,	NotificationEpisodeChemoDay
		,	d_NotificationEpisodeChemoDay
		,	ReferralDate
		,	case when len(ReferralDate) > 0 and isdate(ReferralDate)=0 then d_ReferralDate+' |value not a date' else d_ReferralDate end as d_ReferralDate
		,	ConsultationDate
		,	case when len(ConsultationDate) > 0 and isdate(ConsultationDate)=0 then d_ConsultationDate+' |value not a date' else d_ConsultationDate end as d_ConsultationDate
		,	ClinicalTrialDate
		,	case when len(ClinicalTrialDate) > 0 and isdate(ClinicalTrialDate)=0 then d_ClinicalTrialDate+' |value not a date' else d_ClinicalTrialDate end as d_ClinicalTrialDate
		,	ClinicalTrialName
		,	d_ClinicalTrialName
		,	MDTDate
		,	case when len(MDTDate) > 0 and isdate(MDTDate)=0 then d_MDTDate+' |value not a date' else d_MDTDate end as d_MDTDate
		,	ReferalToPalliativeCareDate
		,	case when len(ReferalToPalliativeCareDate) > 0 and isdate(ReferalToPalliativeCareDate)=0 then d_ReferalToPalliativeCareDate+' |value not a date' else d_ReferalToPalliativeCareDate end as d_ReferalToPalliativeCareDate
		,	PerformanceStatusDate
		,	case when len(PerformanceStatusDate) > 0 and isdate(PerformanceStatusDate)=0 then d_PerformanceStatusDate+' |value not a date' else d_PerformanceStatusDate end as d_PerformanceStatusDate
		,	PerformanceStatus
		,	case when len(PerformanceStatus) > 0 and isnumeric(PerformanceStatus)=0 then d_PerformanceStatus+' |value not numeric' else d_PerformanceStatus end as d_PerformanceStatus
		,	CPL_ID
		,	CPlan_Name
		,	Regimen
	from ( select  rtrim(isnull(cast(GroupID  as varchar(50)),'')) as GroupID
				, cast((case when len(rtrim(GroupID)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_GroupID
				, rtrim(isnull(cast(MedicareNumber  as varchar(50)),'')) as MedicareNumber
				, cast('O' as varchar(250)) as d_MedicareNumber
				, rtrim(isnull(cast(MRN  as varchar(50)),'')) as MRN 
				, cast('O' as varchar(250)) as d_MRN
				, rtrim(isnull(cast([UniqueIdentifier]  as varchar(50)),'')) as [UniqueIdentifier] 
				, cast('O' as varchar(250)) as d_UniqueIdentifier
				, rtrim(isnull(cast(GivenName1  as varchar(50)),'')) as GivenName1 
				, cast((case when len(rtrim(GivenName1)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_GivenName1
				, rtrim(isnull(cast(GivenName2  as varchar(50)),'')) as GivenName2 
				, cast('O' as varchar(250)) as d_GivenName2
				, rtrim(isnull(cast(Surname  as varchar(50)),'')) as Surname 
				, cast((case when len(rtrim(Surname)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_Surname
				, rtrim(isnull(cast(AliasSurname  as varchar(50)),'')) as AliasSurname 
				, cast('O' as varchar(250)) as d_AliasSurname
				, rtrim(isnull(cast(Sex as varchar(50)),'')) as Sex
				, cast((case when len(rtrim(Sex)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_Sex
				, rtrim(isnull(cast(DateOfBirth as varchar(50)),'')) as DateOfBirth
				, cast((case when len(rtrim(DateOfBirth)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_DateOfBirth
				, rtrim(isnull(cast(Birth_Place_original as varchar(50)),'')) as Birth_Place_original
				, '' as d_Birth_Place_original
				, rtrim(isnull(cast(COBCodeSACC as varchar(50)),'')) as COBCodeSACC
				, cast((case when len(rtrim(COBCodeSACC)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_COBCodeSACC
				, rtrim(isnull(cast(WayfareAddress as varchar(200)),'')) as WayfareAddress
				, cast((case when len(rtrim(WayfareAddress)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_WayfareAddress
				, rtrim(isnull(cast(Locality as varchar(50)),'')) as Locality
				, cast((case when len(rtrim(Locality)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_Locality
				, rtrim(isnull(cast(Postcode as varchar(50)),'')) as Postcode
				, cast((case when len(rtrim(Postcode)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_Postcode
				, rtrim(isnull(cast(WayfareStateID_original as varchar(50)),'')) as WayfareStateID_original
				, '' as d_WayfareStateID_original
				, rtrim(isnull(cast(WayfareStateID as varchar(50)),'')) as WayfareStateID
				, cast((case when len(rtrim(WayfareStateID)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_WayfareStateID
				, rtrim(isnull(cast(IndigenousStatusID_original as varchar(50)),'')) as IndigenousStatusID_original
				, cast('O' as varchar(250)) as d_IndigenousStatusID_original
				, rtrim(isnull(cast(IndigenousStatusID as varchar(50)),'')) as IndigenousStatusID
				, cast('O' as varchar(250)) as d_IndigenousStatusID
				, rtrim(isnull(cast(AmoRegReferringNumber as varchar(50)),'')) as AmoRegReferringNumber
				, cast((case when len(rtrim(AmoRegReferringNumber)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_AmoRegReferringNumber
				, rtrim(isnull(cast(DoctorName as varchar(120)),'')) as DoctorName
				, cast('O' as varchar(250)) as d_DoctorName
				, rtrim(isnull(cast(TreatingFacilityCode as varchar(50)),'')) as TreatingFacilityCode
				, cast('O' as varchar(250)) as d_TreatingFacilityCode
				, rtrim(isnull(cast(FacilityCode as varchar(50)),'')) as FacilityCode
				, cast((case when len(rtrim(FacilityCode)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_FacilityCode
				, rtrim(isnull(cast(DateOfDiagnosis as varchar(50)),'')) as DateOfDiagnosis
				, cast((case when len(rtrim(DateOfDiagnosis)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_DateOfDiagnosis
				, rtrim(isnull(cast(CancerSiteCodeID as varchar(50)),'')) as CancerSiteCodeID
				, cast((case when len(rtrim(CancerSiteCodeID)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_CancerSiteCodeID
				, rtrim(isnull(cast(CancerSiteCodeIDVersion as varchar(50)),'')) as CancerSiteCodeIDVersion
				, cast((case when len(rtrim(CancerSiteCodeIDVersion)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_CancerSiteCodeIDVersion 
				, rtrim(isnull(cast(MorphologyCodeIDVersion as varchar(50)),'')) as MorphologyCodeIDVersion
				, cast((case when len(rtrim(MorphologyCodeIDVersion)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_MorphologyCodeIDVersion		
				, rtrim(isnull(cast(BestBasisOfDiagnosisID_original as varchar(50)),'')) as BestBasisOfDiagnosisID_original
				, cast('O' as varchar(250)) as d_BestBasisOfDiagnosisID_original
				, rtrim(isnull(cast(BestBasisOfDiagnosisID as varchar(50)),'')) as BestBasisOfDiagnosisID
				, cast('O' as varchar(250)) as d_BestBasisOfDiagnosisID
				, rtrim(isnull(cast(Laterality_original as varchar(50)),'')) as Laterality_original
				, cast('O' as varchar(250)) as d_Laterality_original
				, rtrim(isnull(cast(Laterality as varchar(50)),'')) as Laterality
				, cast('O' as varchar(250)) as d_Laterality
				, rtrim(isnull(cast(HistopathologicalGradeID as varchar(50)),'')) as HistopathologicalGradeID
				, cast('O' as varchar(250)) as d_HistopathologicalGradeID
				, rtrim(isnull(cast(cast(MorphologyCodeID as int) as varchar(50)),'')) as MorphologyCodeID
				, cast('O' as varchar(250)) as d_MorphologyCodeID
				, rtrim(isnull(cast(DegreeOfSpreadID as varchar(50)),'')) as DegreeOfSpreadID
				, cast('O' as varchar(250)) as d_DegreeOfSpreadID
				, rtrim(isnull(cast(TNMStagingDate as varchar(50)),'')) as TNMStagingDate
				, cast('O' as varchar(250)) as d_TNMStagingDate
				, rtrim(isnull(cast(TStageID_original as varchar(50)),'')) as TStageID_original
				, rtrim(isnull(cast(NStageID_original as varchar(50)),'')) as NStageID_original
				, rtrim(isnull(cast(MStageID_original as varchar(50)),'')) as MStageID_original
				, rtrim(isnull(cast(TStageID as varchar(50)),'')) as TStageID
				, cast('O' as varchar(250)) as d_TStageID
				, rtrim(isnull(cast(NStageID as varchar(50)),'')) as NStageID
				, cast('O' as varchar(250)) as d_NStageID
				, rtrim(isnull(cast(MStageID as varchar(50)),'')) as MStageID
				, cast('O' as varchar(250)) as d_MStageID
				, rtrim(isnull(cast(TNMStagingGroupID as varchar(50)),'')) as TNMStagingGroupID
				, cast('O' as varchar(250)) as d_TNMStagingGroupID
				, rtrim(isnull(cast(TNMStagingBasisID as varchar(50)),'')) as TNMStagingBasisID
				, cast('O' as varchar(250)) as d_TNMStagingBasisID
				, rtrim(isnull(cast(OtherStagingDate as varchar(50)),'')) as OtherStagingDate
				, cast('O' as varchar(250)) as d_OtherStagingDate
				, rtrim(isnull(cast(OtherStagingSchemeID as varchar(50)),'')) as OtherStagingSchemeID
				, cast('O' as varchar(250)) as d_OtherStagingSchemeID
				, rtrim(isnull(cast(OtherStagingGroupID as varchar(50)),'')) as OtherStagingGroupID
				, cast('O' as varchar(250)) as d_OtherStagingGroupID
				, rtrim(isnull(cast(OtherStagingBasisID as varchar(50)),'')) as OtherStagingBasisID
				, cast('O' as varchar(250)) as d_OtherStagingBasisID
				, rtrim(isnull(cast(EpisodeIntentID_original as varchar(50)),'')) as EpisodeIntentID_original
				, cast('O' as varchar(250)) as d_EpisodeIntentID_original
				, rtrim(isnull(cast(EpisodeIntentID as varchar(50)),'')) as EpisodeIntentID
				, cast('O' as varchar(250)) as d_EpisodeIntentID
				, rtrim(isnull(cast(InitialTreatmentFlag as varchar(50)),'')) as InitialTreatmentFlag
				, cast('O' as varchar(250)) as d_InitialTreatmentFlag
				, rtrim(isnull(cast(EpisodeStartDate as varchar(50)),'')) as EpisodeStartDate
				, cast((case when len(rtrim(EpisodeStartDate)) = 0 then 'M |Empty' else 'M' end) as varchar(250)) as d_EpisodeStartDate
				, rtrim(isnull(cast(EpisodeEndDate as varchar(50)),'')) as EpisodeEndDate
				, cast('O' as varchar(250)) as d_EpisodeEndDate
				, rtrim(isnull(cast(AntiNeoplasticCycles as varchar(50)),'')) as AntiNeoplasticCycles
				, cast('O' as varchar(250)) as d_AntiNeoplasticCycles
				, rtrim(isnull(cast(ProtocolID as varchar(50)),'')) as ProtocolID
				, cast('O' as varchar(250)) as d_ProtocolID
				, rtrim(isnull(cast(NotificationEpisodeChemoCycle as varchar(50)),'')) as NotificationEpisodeChemoCycle
				, cast('O' as varchar(250)) as d_NotificationEpisodeChemoCycle
				, rtrim(isnull(cast(OMISDrugName as varchar(512)),'')) as OMISDrugName
				, cast('O' as varchar(250)) as d_OMISDrugName
				, rtrim(isnull(cast(NotificationEpisodeChemoDose as varchar(50)),'')) as NotificationEpisodeChemoDose
				, cast('O' as varchar(250)) as d_NotificationEpisodeChemoDose
				, rtrim(isnull(cast(NotificationEpisodeChemoRouteID_original as varchar(50)),'')) as NotificationEpisodeChemoRouteID_original
				, cast('O' as varchar(250)) as d_NotificationEpisodeChemoRouteID_original
				, rtrim(isnull(cast(NotificationEpisodeChemoRouteID as varchar(50)),'')) as NotificationEpisodeChemoRouteID
				, cast('O' as varchar(250)) as d_NotificationEpisodeChemoRouteID
				, rtrim(isnull(cast(NotificationEpisodeChemoStartDate as varchar(50)),'')) as NotificationEpisodeChemoStartDate
				, cast('O' as varchar(250)) as d_NotificationEpisodeChemoStartDate
				, rtrim(isnull(cast(NotificationEpisodeChemoEndDate as varchar(50)),'')) as NotificationEpisodeChemoEndDate
				, cast('O' as varchar(250)) as d_NotificationEpisodeChemoEndDate
				, rtrim(isnull(cast(NotificationEpisodeChemoFrequency as varchar(50)),'')) as NotificationEpisodeChemoFrequency
				, cast('O' as varchar(250)) as d_NotificationEpisodeChemoFrequency
				, rtrim(isnull(cast(NotificationEpisodeChemoFrequencyUnit as varchar(50)),'')) as NotificationEpisodeChemoFrequencyUnit
				, cast('O' as varchar(250)) as d_NotificationEpisodeChemoFrequencyUnit
				, rtrim(isnull(cast(NotificationEpisodeChemoDay as varchar(50)),'')) as NotificationEpisodeChemoDay
				, cast('O' as varchar(250)) as d_NotificationEpisodeChemoDay
				, rtrim(isnull(cast(ReferralDate as varchar(50)),'')) as ReferralDate
				, cast('O' as varchar(250)) as d_ReferralDate
				, rtrim(isnull(cast(ConsultationDate as varchar(50)),'')) as ConsultationDate
				, cast('O' as varchar(250)) as d_ConsultationDate
				, rtrim(isnull(cast(ClinicalTrialDate as varchar(50)),'')) as ClinicalTrialDate
				, cast('O' as varchar(250)) as d_ClinicalTrialDate
				, rtrim(isnull(cast(ClinicalTrialName as varchar(50)),'')) as ClinicalTrialName
				, cast('O' as varchar(250)) as d_ClinicalTrialName
				, rtrim(isnull(cast(MDTDate as varchar(50)),'')) as MDTDate
				, cast('O' as varchar(250)) as d_MDTDate
				, rtrim(isnull(cast(ReferalToPalliativeCareDate as varchar(50)),'')) as ReferalToPalliativeCareDate
				, cast('O' as varchar(250)) as d_ReferalToPalliativeCareDate
				, rtrim(isnull(cast(PerformanceStatusDate as varchar(50)),'')) as PerformanceStatusDate
				, cast('O' as varchar(250)) as d_PerformanceStatusDate
				, rtrim(isnull(cast(PerformanceStatus as varchar(50)),'')) as PerformanceStatus
				, cast('O' as varchar(250)) as d_PerformanceStatus
				,	CPL_ID
				,	CPlan_Name
				,	Regimen
			from #omis_final  --#omis
			--where FacilityCode = @facility_code
			) a) a
 
 /*
OtherStagingDate
MDTDate
NotificationEpisodeChemoStartDate
NotificationEpisodeChemoEndDate
ConsultationDate
DateOfDiagnosis
TNMStagingDate
DateOfBirth 
EpisodeStartDate
EpisodeEndDate  
ReferralDate
ConsultationDate
ClinicalTrialDate 
ReferalToPalliativeCareDate
PerformanceStatusDate
*/

	update  #omis_debug
	set d_CancerSiteCodeID = d_CancerSiteCodeID +  ' |value not a cancer code'
	where not(CancerSiteCodeID like 'B%' or CancerSiteCodeID like 'C%' or CancerSiteCodeID like 'D%' or CancerSiteCodeID like 'L%')

	update  #omis_debug
	set d_OtherStagingDate = d_OtherStagingDate +  ' |value < DateOfDiagnosis'
	where isdate(OtherStagingDate ) > 0 and isdate(DateOfDiagnosis) > 0 and OtherStagingDate < DateOfDiagnosis

	update  #omis_debug
	set d_TNMStagingDate = d_TNMStagingDate  +  ' |value < DateOfDiagnosis'
	where isdate(TNMStagingDate ) > 0 and isdate(DateOfDiagnosis) > 0 and TNMStagingDate < DateOfDiagnosis
	
	update  #omis_debug
	set d_ClinicalTrialDate  = d_ClinicalTrialDate  +  ' |value < DateOfDiagnosis'
	where isdate(ClinicalTrialDate ) > 0 and isdate(DateOfDiagnosis) > 0 and ClinicalTrialDate < DateOfDiagnosis
	
	update  #omis_debug
	set d_ReferralDate  = d_ReferralDate +  ' |value < DateOfDiagnosis'
	where isdate(ReferralDate ) > 0 and isdate(DateOfDiagnosis) > 0 and ReferralDate < DateOfDiagnosis
	
	update  #omis_debug
	set d_ReferalToPalliativeCareDate  = d_ReferalToPalliativeCareDate  +  ' |value < DateOfDiagnosis'
	where isdate(ReferalToPalliativeCareDate) > 0 and isdate(DateOfDiagnosis) > 0 and ReferalToPalliativeCareDate < DateOfDiagnosis
	
	update  #omis_debug
	set d_ConsultationDate = d_ConsultationDate +  ' |value < DateOfDiagnosis'
	where isdate(ConsultationDate) > 0 and isdate(DateOfDiagnosis) > 0 and ConsultationDate < DateOfDiagnosis
	
	update  #omis_debug
	set d_PerformanceStatusDate = d_PerformanceStatusDate +  ' |value < DateOfDiagnosis'
	where isdate(PerformanceStatusDate) > 0 and isdate(DateOfDiagnosis) > 0 and PerformanceStatusDate < DateOfDiagnosis
	
	update  #omis_debug
	set d_EpisodeEndDate = d_EpisodeEndDate +  ' |value < DateOfDiagnosis'
	where isdate(EpisodeEndDate) > 0 and isdate(DateOfDiagnosis) > 0 and EpisodeEndDate < DateOfDiagnosis
	
	update  #omis_debug
	set d_EpisodeStartDate = d_EpisodeStartDate +  ' |value < DateOfDiagnosis'
	where isdate(EpisodeStartDate) > 0 and isdate(DateOfDiagnosis) > 0 and EpisodeStartDate < DateOfDiagnosis
	
	update  #omis_debug
	set d_ReferalToPalliativeCareDate  = d_ReferalToPalliativeCareDate +  ' |value < DateOfBirth'
	where isdate(ReferalToPalliativeCareDate ) > 0 and isdate(DateOfBirth ) > 0 and ReferalToPalliativeCareDate <= DateOfBirth 

	update  #omis_debug
	set d_ClinicalTrialDate  = d_ClinicalTrialDate  +  ' |value < DateOfBirth'
	where isdate(ClinicalTrialDate ) > 0 and isdate(DateOfBirth ) > 0 and ClinicalTrialDate <= DateOfBirth 

	update  #omis_debug
	set d_MDTDate  = d_MDTDate  +  ' |value < DateOfBirth'
	where isdate(MDTDate ) > 0 and isdate(DateOfBirth ) > 0 and MDTDate <= DateOfBirth 

	update  #omis_debug
	set d_ReferralDate = d_ReferralDate +  ' |value < DateOfBirth'
	where isdate(ReferralDate ) > 0 and isdate(DateOfBirth ) > 0 and ReferralDate <= DateOfBirth 

	update  #omis_debug
	set d_ConsultationDate = d_ConsultationDate +  ' |value < DateOfBirth'
	where isdate(ConsultationDate) > 0 and isdate(DateOfBirth ) > 0 and ConsultationDate <= DateOfBirth 

	update  #omis_debug
	set d_PerformanceStatusDate = d_PerformanceStatusDate +  ' |value < DateOfBirth'
	where isdate(PerformanceStatusDate) > 0 and isdate(DateOfBirth ) > 0 and PerformanceStatusDate <= DateOfBirth 

	update  #omis_debug
	set d_EpisodeStartDate = d_EpisodeStartDate +  ' |value < DateOfBirth'
	where isdate(EpisodeStartDate) > 0 and isdate(DateOfBirth ) > 0 and EpisodeStartDate <= DateOfBirth 

	update  #omis_debug
	set d_EpisodeEndDate = d_EpisodeEndDate +  ' |value < DateOfBirth'
	where isdate(EpisodeEndDate) > 0 and isdate(DateOfBirth ) > 0 and EpisodeEndDate <= DateOfBirth 

	update  #omis_debug
	set d_EpisodeStartDate = d_EpisodeStartDate +  ' |value > EpisodeEndDate'
	where isdate(EpisodeStartDate) > 0 and isdate(EpisodeEndDate ) > 0 and EpisodeStartDate > EpisodeEndDate 
	  
	--update  #omis_debug
	--set d_ = d_ +  ' |value > '
	--where isdate() > 0 and isdate() > 0 and  >    
	 

	update  #omis_debug
	set d_DateOfBirth = d_DateOfBirth +  ' |value > ConsultationDate'
	where DateOfBirth >  ConsultationDate and ConsultationDate <> ''

	update  #omis_debug
	set d_DateOfBirth = d_DateOfBirth +  ' |value > EpisodeStartDate'
	where DateOfBirth >  EpisodeStartDate and EpisodeStartDate <> ''

	update  #omis_debug
	set d_DateOfBirth = d_DateOfBirth +  ' |value > DateOfDiagnosis'
	where DateOfBirth >  DateOfDiagnosis and DateOfDiagnosis <> ''

	update  #omis_debug
	set d_ConsultationDate = d_ConsultationDate +  ' |value < ReferralDate'
	where ConsultationDate <  ReferralDate and ConsultationDate <> '' and ReferralDate <> ''
 
	update  #omis_debug
	set d_DateOfDiagnosis = d_DateOfDiagnosis +  ' |value > NotificationEpisodeChemoStartDate'
	where DateOfDiagnosis >  NotificationEpisodeChemoStartDate and DateOfDiagnosis <> '' and NotificationEpisodeChemoStartDate <> ''

	update  #omis_debug
	set d_ConsultationDate = d_ConsultationDate +  ' |value > NotificationEpisodeChemoStartDate'
	where ConsultationDate >  NotificationEpisodeChemoStartDate and ConsultationDate <> '' and NotificationEpisodeChemoStartDate <> ''

	update  #omis_debug
	set d_NotificationEpisodeChemoStartDate = d_NotificationEpisodeChemoStartDate +  ' |value < ReferralDate'
	where NotificationEpisodeChemoStartDate <  ReferralDate and ReferralDate <> '' and NotificationEpisodeChemoStartDate <> ''

	update  #omis_debug
	set d_NotificationEpisodeChemoEndDate = d_NotificationEpisodeChemoEndDate +  ' |value < NotificationEpisodeChemoStartDate'
	where NotificationEpisodeChemoEndDate <  NotificationEpisodeChemoStartDate and NotificationEpisodeChemoEndDate <> '' and NotificationEpisodeChemoStartDate <> ''

	update  #omis_debug
	set d_PerformanceStatusDate = d_PerformanceStatusDate +  ' |value < ReferralDate'
	where PerformanceStatusDate <  ReferralDate and PerformanceStatusDate <> '' and ReferralDate <> ''

	update  #omis_debug
	set d_ReferralDate = d_ReferralDate +  ' |ReferralDate-ConsultationDate not between 0 and 120 days'
	where not(datediff(d, ReferralDate, ConsultationDate) between 0 and 120) and ConsultationDate <> '' and ReferralDate <> ''

	update  #omis_debug
	set d_ConsultationDate = d_ConsultationDate +  ' |ConsultationDate-NotificationEpisodeChemoStartDate not between 0 and 90 days'
	where not(datediff(d, ConsultationDate, NotificationEpisodeChemoStartDate) between 0 and 90) and ConsultationDate <> '' and NotificationEpisodeChemoStartDate <> ''


	/******* RANGE / SET validation  **********/ 
	update  #omis_debug
	set d_InitialTreatmentFlag = d_InitialTreatmentFlag + ' |value not in range'
	where InitialTreatmentFlag not in (1,2)

	update  #omis_debug
	set d_sex = d_sex + ' |value not valid'
	where  sex not in (1,2,3,9)

	update  #omis_debug
	set d_COBCodeSACC = d_COBCodeSACC + ' |value not in country set'
	where  COBCodeSACC not in (select code from @countries)
 

	update  #omis_debug
	set d_WayfareStateID = d_WayfareStateID + ' |value not in state set'
	where  WayfareStateID not in (select code from @states)

	update  #omis_debug
	set d_IndigenousStatusID = d_IndigenousStatusID + ' |value not in Indigenious set'
	where  IndigenousStatusID not in (select code from @indigenious)

	update  #omis_debug
	set d_FacilityCode = d_FacilityCode + ' |value not in correct format'
	where len(FacilityCode) > 0 and (len(FacilityCode) < 3 or len(FacilityCode) > 5)

	update  #omis_debug
	set d_TreatingFacilityCode = d_TreatingFacilityCode + ' |value not in correct format'
	where TreatingFacilityCode <> '' and ( len(TreatingFacilityCode) < 3 or len(TreatingFacilityCode) > 5)

	update  #omis_debug
	set d_BestBasisOfDiagnosisID = d_BestBasisOfDiagnosisID + ' |value not in valid set'
	where  BestBasisOfDiagnosisID <> '' and BestBasisOfDiagnosisID not in (1,2,4,5,6,7,8)

	update  #omis_debug
	set d_Laterality = d_Laterality + ' |value not in valid set'
	where  Laterality <> '' and Laterality not in (1,2,3,9)

	update  #omis_debug
	set d_HistopathologicalGradeID = d_HistopathologicalGradeID + ' |value not in valid set'
	where  isnumeric(HistopathologicalGradeID) = 1 and HistopathologicalGradeID not in (1,2,3,4,8,9)

	update  #omis_debug
	set d_DegreeOfSpreadID = d_DegreeOfSpreadID + ' |value not in valid set'
	where  isnumeric(DegreeOfSpreadID) = 1 and DegreeOfSpreadID not in (1,2,3,4,6,7,9)

	update  #omis_debug
	set d_TNMStagingBasisID = d_TNMStagingBasisID + ' |value not in valid set'
	where TNMStagingBasisID <> '' and TNMStagingBasisID not in ('P','C')

	update  #omis_debug
	set d_AntiNeoplasticCycles = d_AntiNeoplasticCycles + ' |value out of range'
	where ISNUMERIC(AntiNeoplasticCycles) = 1 and (AntiNeoplasticCycles <  1 or AntiNeoplasticCycles > 300)


	update  #omis_debug
	set d_NotificationEpisodeChemoEndDate = d_NotificationEpisodeChemoEndDate + ' |value < start date'
	where  isdate(NotificationEpisodeChemoEndDate) = 1 and isdate(NotificationEpisodeChemoStartDate) = 1
		and  NotificationEpisodeChemoEndDate  <  NotificationEpisodeChemoStartDate 
	
	update  #omis_debug
	set d_ProtocolID = d_ProtocolID + ' |value not an eviQ number'
	where  isnumeric(replace(replace(replace(replace(ProtocolID,'-',''),':',''),'eviq',''),'id','')) < 1 and ProtocolID <> ''


	select  @hosp_code  as GroupID  --hospitalid
		, replace(right('0'+convert(varchar(10),@startdate, 103),10),'/','')    as d_GroupID  --reportstartdate
		, replace(right('0'+convert(varchar(10),@enddate, 103),10),'/','')  as MedicareNumber  --reportenddate
		, replace(right('0'+convert(varchar(10),getdate(), 103),10),'/','')    as  d_MedicareNumber --rundate
		, right('0'+cast(datepart(hh, getdate()) as varchar(2)),2)+right('0'+cast(datepart(mi, getdate()) as varchar(2)),2) as MRN --runtime
		, cast(count(*) as varchar(50))  as d_MRN --recordcount
		, 'C'  as [UniqueIdentifier] --notificationtypeid
		, max(left(facilitycode,4))   as d_UniqueIdentifier  --cancerfacilittypeid 
		,'' as 	GivenName1
		,'' as 	d_GivenName1
		,'' as 	GivenName2
		,'' as 	d_GivenName2
		,'' as 	Surname
		,'' as 	d_Surname
		,'' as 	AliasSurname
		,'' as 	d_AliasSurname
		,'' as 	Sex
		,'' as 	d_Sex
		,'' as 	DateOfBirth
		,'' as 	d_DateOfBirth
		,'' as 	Birth_Place_original
		,'' as 	d_Birth_Place_original
		,'' as 	COBCodeSACC
		,'' as 	d_COBCodeSACC
		,'' as 	WayfareAddress
		,'' as 	d_WayfareAddress
		,'' as 	Locality
		,'' as 	d_Locality
		,'' as 	Postcode
		,'' as 	d_Postcode
		,'' as 	WayfareStateID_original
		,'' as 	d_WayfareStateID_original
		,'' as 	WayfareStateID
		,'' as 	d_WayfareStateID
		,'' as 	IndigenousStatusID_original
		,'' as 	d_IndigenousStatusID_original
		,'' as 	IndigenousStatusID
		,'' as 	d_IndigenousStatusID
		,'' as 	AmoRegReferringNumber
		,'' as 	d_AmoRegReferringNumber
		,'' as 	DoctorName
		,'' as 	d_DoctorName
		,'' as 	TreatingFacilityCode
		,'' as 	d_TreatingFacilityCode
		,'' as 	FacilityCode
		,'' as 	d_FacilityCode
		,'' as 	DateOfDiagnosis
		,'' as 	d_DateOfDiagnosis
		,'' as 	CancerSiteCodeID
		,'' as 	d_CancerSiteCodeID
		,'' as 	CancerSiteCodeIDVersion
		,'' as 	d_CancerSiteCodeIDVersion
		,'' as 	MorphologyCodeIDVersion
		,'' as 	d_MorphologyCodeIDVersion
		,'' as 	BestBasisOfDiagnosisID_original
		,'' as 	d_BestBasisOfDiagnosisID_original
		,'' as 	BestBasisOfDiagnosisID
		,'' as 	d_BestBasisOfDiagnosisID
		,'' as 	Laterality_original
		,'' as 	d_Laterality_original
		,'' as 	Laterality
		,'' as 	d_Laterality
		,'' as 	HistopathologicalGradeID
		,'' as 	d_HistopathologicalGradeID
		,'' as 	MorphologyCodeID
		,'' as 	d_MorphologyCodeID
		,'' as 	DegreeOfSpreadID
		,'' as 	d_DegreeOfSpreadID
		,'' as 	TNMStagingDate
		,'' as 	d_TNMStagingDate
		--,'' as 	TStageID_original
		--,'' as 	NStageID_original
		--,'' as 	MStageID_original
		,'' as 	TStageID
		,'' as 	d_TStageID
		,'' as 	NStageID
		,'' as 	d_NStageID
		,'' as 	MStageID
		,'' as 	d_MStageID
		,'' as 	TNMStagingGroupID
		,'' as 	d_TNMStagingGroupID
		,'' as 	TNMStagingBasisID
		,'' as 	d_TNMStagingBasisID
		,'' as 	OtherStagingDate
		,'' as 	d_OtherStagingDate
		,'' as 	OtherStagingSchemeID
		,'' as 	d_OtherStagingSchemeID
		,'' as 	OtherStagingGroupID
		,'' as 	d_OtherStagingGroupID
		,'' as 	OtherStagingBasisID
		,'' as 	d_OtherStagingBasisID
		,'' as 	EpisodeIntentID_original
		,'' as 	d_EpisodeIntentID_original
		,'' as 	EpisodeIntentID
		,'' as 	d_EpisodeIntentID
		,'' as 	InitialTreatmentFlag
		,'' as 	d_InitialTreatmentFlag
		,'' as 	EpisodeStartDate
		,'' as 	d_EpisodeStartDate
		,'' as 	EpisodeEndDate
		,'' as 	d_EpisodeEndDate
		,'' as 	AntiNeoplasticCycles
		,'' as 	d_AntiNeoplasticCycles
		,'' as 	ProtocolID
		,'' as 	d_ProtocolID
		,'' as 	NotificationEpisodeChemoCycle
		,'' as 	d_NotificationEpisodeChemoCycle
		,'' as 	OMISDrugName
		,'' as 	d_OMISDrugName
		,'' as 	NotificationEpisodeChemoDose
		,'' as 	d_NotificationEpisodeChemoDose
		,'' as 	NotificationEpisodeChemoRouteID_original
		,'' as 	d_NotificationEpisodeChemoRouteID_original
		,'' as 	NotificationEpisodeChemoRouteID
		,'' as 	d_NotificationEpisodeChemoRouteID
		,'' as 	NotificationEpisodeChemoStartDate
		,'' as 	d_NotificationEpisodeChemoStartDate
		,'' as 	NotificationEpisodeChemoEndDate
		,'' as 	d_NotificationEpisodeChemoEndDate
		,'' as 	NotificationEpisodeChemoFrequency
		,'' as 	d_NotificationEpisodeChemoFrequency
		,'' as 	NotificationEpisodeChemoFrequencyUnit
		,'' as 	d_NotificationEpisodeChemoFrequencyUnit
		,'' as 	NotificationEpisodeChemoDay
		,'' as 	d_NotificationEpisodeChemoDay
		,'' as 	ReferralDate
		,'' as 	d_ReferralDate
		,'' as 	ConsultationDate
		,'' as 	d_ConsultationDate
		,'' as 	ClinicalTrialDate
		,'' as 	d_ClinicalTrialDate
		,'' as 	ClinicalTrialName
		,'' as 	d_ClinicalTrialName
		,'' as 	MDTDate
		,'' as 	d_MDTDate
		,'' as 	ReferalToPalliativeCareDate
		,'' as 	d_ReferalToPalliativeCareDate
		,'' as 	PerformanceStatusDate
		,'' as 	d_PerformanceStatusDate
		,'' as 	PerformanceStatus
		,'' as 	d_PerformanceStatus
		,'' as 	CPL_ID
		,'' as 	CPlan_Name
		,'' as 	Regimen
	from #omis_debug   
	union all
	select 	GroupID
		,	d_GroupID
		,	MedicareNumber
		,	d_MedicareNumber
		,	MRN
		,	d_MRN
		,	UniqueIdentifier
		,	d_UniqueIdentifier
		,	GivenName1
		,	d_GivenName1
		,	GivenName2
		,	d_GivenName2
		,	Surname
		,	d_Surname
		,	AliasSurname
		,	d_AliasSurname
		,	Sex
		,	d_Sex
		,	DateOfBirth
		,	d_DateOfBirth
		,	Birth_Place_original
		,	d_Birth_Place_original
		,	COBCodeSACC
		,	d_COBCodeSACC
		,	WayfareAddress
		,	d_WayfareAddress
		,	Locality
		,	d_Locality
		,	Postcode
		,	d_Postcode
		,	WayfareStateID_original
		,	d_WayfareStateID_original
		,	WayfareStateID
		,	d_WayfareStateID
		,	IndigenousStatusID_original
		,	d_IndigenousStatusID_original
		,	IndigenousStatusID
		,	d_IndigenousStatusID
		,	AmoRegReferringNumber
		,	d_AmoRegReferringNumber
		,	DoctorName
		,	d_DoctorName
		,	TreatingFacilityCode
		,	d_TreatingFacilityCode
		,	FacilityCode
		,	d_FacilityCode
		,	DateOfDiagnosis
		,	d_DateOfDiagnosis
		,	CancerSiteCodeID
		,	d_CancerSiteCodeID
		,	CancerSiteCodeIDVersion
		,	d_CancerSiteCodeIDVersion
		,	MorphologyCodeIDVersion
		,	d_MorphologyCodeIDVersion
		,	BestBasisOfDiagnosisID_original
		,	d_BestBasisOfDiagnosisID_original
		,	BestBasisOfDiagnosisID
		,	d_BestBasisOfDiagnosisID
		,	Laterality_original
		,	d_Laterality_original
		,	Laterality
		,	d_Laterality
		,	HistopathologicalGradeID
		,	d_HistopathologicalGradeID
		,	MorphologyCodeID
		,	d_MorphologyCodeID
		,	DegreeOfSpreadID
		,	d_DegreeOfSpreadID
		,	TNMStagingDate
		,	d_TNMStagingDate
		--,	TStageID_original
		--,	NStageID_original
		--,	MStageID_original
		,	TStageID
		,	d_TStageID
		,	NStageID
		,	d_NStageID
		,	MStageID
		,	d_MStageID
		,	TNMStagingGroupID
		,	d_TNMStagingGroupID
		,	TNMStagingBasisID
		,	d_TNMStagingBasisID
		,	OtherStagingDate
		,	d_OtherStagingDate
		,	OtherStagingSchemeID
		,	d_OtherStagingSchemeID
		,	OtherStagingGroupID
		,	d_OtherStagingGroupID
		,	OtherStagingBasisID
		,	d_OtherStagingBasisID
		,	EpisodeIntentID_original
		,	d_EpisodeIntentID_original
		,	EpisodeIntentID
		,	d_EpisodeIntentID
		,	InitialTreatmentFlag
		,	d_InitialTreatmentFlag
		,	EpisodeStartDate
		,	d_EpisodeStartDate
		,	EpisodeEndDate
		,	d_EpisodeEndDate
		,	AntiNeoplasticCycles
		,	d_AntiNeoplasticCycles
		,	ProtocolID
		,	d_ProtocolID
		,	NotificationEpisodeChemoCycle
		,	d_NotificationEpisodeChemoCycle
		,	OMISDrugName
		,	d_OMISDrugName
		,	NotificationEpisodeChemoDose
		,	d_NotificationEpisodeChemoDose
		,	NotificationEpisodeChemoRouteID_original
		,	d_NotificationEpisodeChemoRouteID_original
		,	NotificationEpisodeChemoRouteID
		,	d_NotificationEpisodeChemoRouteID
		,	NotificationEpisodeChemoStartDate
		,	d_NotificationEpisodeChemoStartDate
		,	NotificationEpisodeChemoEndDate
		,	d_NotificationEpisodeChemoEndDate
		,	NotificationEpisodeChemoFrequency
		,	d_NotificationEpisodeChemoFrequency
		,	NotificationEpisodeChemoFrequencyUnit
		,	d_NotificationEpisodeChemoFrequencyUnit
		,	NotificationEpisodeChemoDay
		,	d_NotificationEpisodeChemoDay
		,	ReferralDate
		,	d_ReferralDate
		,	ConsultationDate
		,	d_ConsultationDate
		,	ClinicalTrialDate
		,	d_ClinicalTrialDate
		,	ClinicalTrialName
		,	d_ClinicalTrialName
		,	MDTDate
		,	d_MDTDate
		,	ReferalToPalliativeCareDate
		,	d_ReferalToPalliativeCareDate
		,	PerformanceStatusDate
		,	d_PerformanceStatusDate
		,	PerformanceStatus
		,	d_PerformanceStatus
		,	CPL_ID
		,	CPlan_Name
		,	Regimen
	from #omis_debug  /*
	where len(d_AliasSurname) > 1
		or len(d_AmoRegReferringNumber) > 1
		or len(d_AntiNeoplasticCycles) > 1
		or len(d_BestBasisOfDiagnosisID) > 1
		or len(d_BestBasisOfDiagnosisID_original) > 1
		or len(d_Birth_Place_original) > 1
		or len(d_CancerSiteCodeID) > 1
		or len(d_CancerSiteCodeIDVersion) > 1
		or len(d_ClinicalTrialDate) > 1
		or len(d_ClinicalTrialName) > 1
		or len(d_COBCodeSACC) > 1
		or len(d_ConsultationDate) > 1
		or len(d_DateOfBirth) > 1
		or len(d_DateOfDiagnosis) > 1
		or len(d_DegreeOfSpreadID) > 1
		or len(d_DoctorName) > 1
		or len(d_EpisodeEndDate) > 1
		or len(d_EpisodeIntentID) > 1
		or len(d_EpisodeIntentID_original) > 1
		or len(d_EpisodeStartDate) > 1
		or len(d_FacilityCode) > 1
		or len(d_GivenName1) > 1
		or len(d_GivenName2) > 1
		or len(d_GroupID) > 1
		or len(d_HistopathologicalGradeID) > 1
		or len(d_IndigenousStatusID) > 1
		or len(d_IndigenousStatusID_original) > 1
		or len(d_InitialTreatmentFlag) > 1
		or len(d_Laterality) > 1
		or len(d_Laterality_original) > 1
		or len(d_Locality) > 1
		or len(d_MDTDate) > 1
		or len(d_MedicareNumber) > 1
		or len(d_MorphologyCodeID) > 1
		or len(d_MRN) > 1
		or len(d_MStageID) > 1
		or len(d_NotificationEpisodeChemoCycle) > 1
		or len(d_NotificationEpisodeChemoDay) > 1
		or len(d_NotificationEpisodeChemoDose) > 1
		or len(d_NotificationEpisodeChemoEndDate) > 1
		or len(d_NotificationEpisodeChemoFrequency) > 1
		or len(d_NotificationEpisodeChemoFrequencyUnit) > 1
		or len(d_NotificationEpisodeChemoRouteID) > 1
		or len(d_NotificationEpisodeChemoRouteID_original) > 1
		or len(d_NotificationEpisodeChemoStartDate) > 1
		or len(d_NStageID) > 1
		or len(d_OMISDrugName) > 1
		or len(d_OtherStagingBasisID) > 1
		or len(d_OtherStagingDate) > 1
		or len(d_OtherStagingGroupID) > 1
		or len(d_OtherStagingSchemeID) > 1
		or len(d_PerformanceStatus) > 1
		or len(d_PerformanceStatusDate) > 1
		or len(d_Postcode) > 1
		or len(d_ProtocolID) > 1
		or len(d_ReferalToPalliativeCareDate) > 1
		or len(d_ReferralDate) > 1
		or len(d_Sex) > 1
		or len(d_Surname) > 1
		or len(d_TNMStagingBasisID) > 1
		or len(d_TNMStagingDate) > 1
		or len(d_TNMStagingGroupID) > 1
		or len(d_TreatingFacilityCode) > 1
		or len(d_TStageID) > 1
		or len(d_UniqueIdentifier) > 1
		or len(d_WayfareAddress) > 1
		or len(d_WayfareStateID) > 1
		or len(d_WayfareStateID_original) > 1*/
end
else 
( select @hosp_code  as GroupID  --hospitalid
	, replace(right('0'+convert(varchar(10),@startdate, 103),10),'/','')    as MedicareNumber  --reportstartdate
	, replace(right('0'+convert(varchar(10),@enddate, 103),10),'/','')  as MRN  --reportenddate
	, replace(right('0'+convert(varchar(10),getdate(), 103),10),'/','')    as  [UniqueIdentifier] --rundate
	, right('0'+cast(datepart(hh, getdate()) as varchar(2)),2)+right('0'+cast(datepart(mi, getdate()) as varchar(2)),2) as GivenName1 --runtime
	, cast(count(*) as varchar(50))  as GivenName2 --recordcount
	, 'C'  as Surname --notificationtypeid
	, max(left(facilitycode,4))   as AliasSurname  --cancerfacilittypeid
	,'' as	Sex
	,'' as	DateOfBirth
	--,'' as	Birth_Place_original
	,'' as	COBCodeSACC
	,'' as	WayfareAddress
	,'' as	Locality
	,'' as	Postcode
	--,'' as	WayfareStateID_original
	,'' as	WayfareStateID
	--,'' as IndigenousStatusID_original
	,'' as IndigenousStatusID
	,'' as AmoRegReferringNumber
	,'' as DoctorName
	,'' as TreatingFacilityCode
	,'' as FacilityCode
	,'' as DateOfDiagnosis
	,'' as CancerSiteCodeID
	,'' as CancerSiteCodeIDVersion
	--,'' as BestBasisOfDiagnosisID_original
	,'' as BestBasisOfDiagnosisID
	--,'' as Laterality_original
	,'' as Laterality
	,'' as HistopathologicalGradeID
	,'' as MorphologyCodeID
	,'' as MorphologyCodeIDVersion
	,'' as DegreeOfSpreadID
	,'' as TNMStagingDate
	,'' as TStageID
	,'' as NStageID
	,'' as MStageID
	,'' as TNMStagingGroupID
	,'' as TNMStagingBasisID
	,'' as OtherStagingDate
	,'' as OtherStagingSchemeID
	,'' as OtherStagingGroupID
	,'' as OtherStagingBasisID
	--,'' as EpisodeIntentID_original
	,'' as EpisodeIntentID
	,'' as InitialTreatmentFlag
	,'' as EpisodeStartDate
	,'' as EpisodeEndDate
	,'' as AntiNeoplasticCycles
	,'' as ProtocolID
	,'' as NotificationEpisodeChemoCycle
	,'' as OMISDrugName
	,'' as NotificationEpisodeChemoDose
	--,'' as NotificationEpisodeChemoRouteID_original
	,'' as NotificationEpisodeChemoRouteID
	,'' as NotificationEpisodeChemoStartDate
	,'' as NotificationEpisodeChemoEndDate
	,'' as NotificationEpisodeChemoFrequency
	,'' as NotificationEpisodeChemoFrequencyUnit
	,'' as NotificationEpisodeChemoDay
	,'' as ReferralDate
	,'' as ConsultationDate
	,'' as ClinicalTrialDate
	,'' as ClinicalTrialName
	,'' as MDTDate
	,'' as ReferalToPalliativeCareDate
	,'' as PerformanceStatusDate
	,'' as PerformanceStatus 
from #omis_final
union all  
select distinct isnull(cast(GroupID  as varchar(11)),'') as GroupID 
	, isnull(cast(MedicareNumber  as varchar(12)),'') as MedicareNumber 
	, isnull(cast(MRN  as varchar(20)),'') as MRN 
	, isnull(cast([UniqueIdentifier]  as varchar(20)),'') as [UniqueIdentifier] 
	, isnull(cast(GivenName1  as varchar(40)),'') as GivenName1 
	, isnull(cast(GivenName2  as varchar(40)),'') as GivenName2 
	, isnull(cast(Surname  as varchar(40)),'') as Surname 
	, isnull(cast(AliasSurname  as varchar(40)),'') as AliasSurname 
	, isnull(cast(Sex as varchar(1)),'') as Sex
	, isnull(replace(right('0'+convert(varchar(10),DateOfBirth, 103),10),'/',''),'') as DateOfBirth
	--, isnull(cast(Birth_Place_original as varchar(30)),'') as Birth_Place_original
	, isnull(cast(COBCodeSACC as varchar(4)),'') as COBCodeSACC
	, isnull(cast(WayfareAddress as varchar(180)),'') as WayfareAddress
	, isnull(cast(Locality as varchar(40)),'') as Locality
	, isnull(cast(Postcode as varchar(4)),'') as Postcode
	--, isnull(cast(WayfareStateID_original as varchar(30)),'') as WayfareStateID_original
	, isnull(cast(WayfareStateID as varchar(2)),'') as WayfareStateID
	--, isnull(cast(IndigenousStatusID_original as varchar(30)),'') as IndigenousStatusID_original
	, isnull(cast(IndigenousStatusID as varchar(1)),'') as IndigenousStatusID
	, isnull(cast(AmoRegReferringNumber as varchar(20)),'') as AmoRegReferringNumber
	, isnull(cast(DoctorName as varchar(120)),'') as DoctorName
	, isnull(cast(TreatingFacilityCode as varchar(4)),'') as TreatingFacilityCode
	, isnull(left(cast(FacilityCode as varchar(30)),4),'') as FacilityCode
	, isnull(replace(right('0'+convert(varchar(10),DateOfDiagnosis, 103),10),'/',''),'01019999') as DateOfDiagnosis
	, isnull(cast(CancerSiteCodeID as varchar(7)),'') as CancerSiteCodeID
	, isnull(cast(CancerSiteCodeIDVersion as varchar(10)),'') as CancerSiteCodeIDVersion
	--, isnull(cast(BestBasisOfDiagnosisID_original as varchar(30)),'') as BestBasisOfDiagnosisID_original
	, isnull(cast(BestBasisOfDiagnosisID as varchar(1)),'') as BestBasisOfDiagnosisID
	--, isnull(cast(Laterality_original as varchar(30)),'') as Laterality_original
	, isnull(cast(Laterality as varchar(1)),'') as Laterality
	, isnull(cast(HistopathologicalGradeID as varchar(1)),'') as HistopathologicalGradeID
	, isnull(cast(cast(MorphologyCodeID as int) as varchar(10)),'') as MorphologyCodeID
	, isnull(cast(MorphologyCodeIDVersion as varchar(10)),'') as MorphologyCodeIDVersion
	, isnull(cast(DegreeOfSpreadID as varchar(1)),'') as DegreeOfSpreadID
	, isnull(replace(right('0'+convert(varchar(10),TNMStagingDate, 103),10),'/',''),'') as TNMStagingDate
	, isnull(cast(TStageID as varchar(50)),'') as TStageID
	, isnull(cast(NStageID as varchar(50)),'') as NStageID
	, isnull(cast(MStageID as varchar(50)),'') as MStageID
	, isnull(cast(TNMStagingGroupID as varchar(50)),'') as TNMStagingGroupID
	, isnull(cast(TNMStagingBasisID as varchar(1)),'') as TNMStagingBasisID
	, isnull(replace(right('0'+convert(varchar(10),OtherStagingDate, 103),10),'/',''),'') as OtherStagingDate 
	, isnull(cast(OtherStagingSchemeID as varchar(2)),'') as OtherStagingSchemeID
	, isnull(cast(OtherStagingGroupID as varchar(14)),'') as OtherStagingGroupID
	, isnull(cast(OtherStagingBasisID as varchar(1)),'') as OtherStagingBasisID
	--, isnull(cast(EpisodeIntentID_original as varchar(30)),'') as EpisodeIntentID_original
	, isnull(cast(EpisodeIntentID as varchar(2)),'') as EpisodeIntentID
	, isnull(cast(InitialTreatmentFlag as varchar(1)),'') as InitialTreatmentFlag 
	, isnull(replace(right('0'+convert(varchar(10),EpisodeStartDate, 103),10),'/',''),'') as EpisodeStartDate
	, isnull(replace(right('0'+convert(varchar(10),EpisodeEndDate, 103),10),'/',''),'') as EpisodeEndDate
	, isnull(cast(AntiNeoplasticCycles as varchar(3)),'') as AntiNeoplasticCycles
	, isnull(cast(ProtocolID as varchar(15)),'') as ProtocolID
	, isnull(cast(NotificationEpisodeChemoCycle as varchar(3)),'') as NotificationEpisodeChemoCycle
	, isnull(cast(OMISDrugName as varchar(512)),'') as OMISDrugName
	, isnull(cast(NotificationEpisodeChemoDose as varchar(20)),'') as NotificationEpisodeChemoDose
	--, isnull(cast(NotificationEpisodeChemoRouteID_original as varchar(30)),'') as NotificationEpisodeChemoRouteID_original
	, isnull(cast(NotificationEpisodeChemoRouteID as varchar(2)),'') as NotificationEpisodeChemoRouteID
	, isnull(replace(right('0'+convert(varchar(10),NotificationEpisodeChemoStartDate, 103),10),'/',''),'') as NotificationEpisodeChemoStartDate
	, isnull(replace(right('0'+convert(varchar(10),NotificationEpisodeChemoEndDate, 103),10),'/',''),'') as NotificationEpisodeChemoEndDate
	, isnull(cast(NotificationEpisodeChemoFrequency as varchar(3)),'') as NotificationEpisodeChemoFrequency
	, isnull(cast(NotificationEpisodeChemoFrequencyUnit as varchar(1)),'') as NotificationEpisodeChemoFrequencyUnit
	, isnull(cast(NotificationEpisodeChemoDay as varchar(15)),'') as NotificationEpisodeChemoDay
	, isnull(replace(right('0'+convert(varchar(10),ReferralDate, 103),10),'/',''),'') as ReferralDate
	, isnull(replace(right('0'+convert(varchar(10),ConsultationDate , 103),10),'/',''),'') as ConsultationDatea
	, isnull(replace(right('0'+convert(varchar(10),ClinicalTrialDate, 103),10),'/',''),'') as ClinicalTrialDate
	, isnull(cast(ClinicalTrialName as varchar(100)),'') as ClinicalTrialName
	, isnull(replace(right('0'+convert(varchar(10),MDTDate, 103),10),'/',''),'') as MDTDate
	, isnull(replace(right('0'+convert(varchar(10),ReferalToPalliativeCareDate , 103),10),'/',''),'') as ReferalToPalliativeCareDate
	, isnull(replace(right('0'+convert(varchar(10),PerformanceStatusDate, 103),10),'/',''),'') as PerformanceStatusDate
	, isnull(cast(PerformanceStatus as varchar(1)),'') as PerformanceStatus
from #omis_final  )
  

  /********************************************************************************************************************************************************/

   















